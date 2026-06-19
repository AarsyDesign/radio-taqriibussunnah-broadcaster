package com.radiotaqriibussunnah.broadcaster

import android.annotation.SuppressLint
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.net.TrafficStats
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import kotlin.math.sqrt
import androidx.core.app.NotificationCompat
import io.flutter.plugin.common.EventChannel

object BroadcastStatusEvents : EventChannel.StreamHandler {
    private var eventSink: EventChannel.EventSink? = null
    var currentStatus: String = "offline"
        private set

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
        events?.success(currentStatus)
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    fun send(status: String) {
        currentStatus = status
        Handler(Looper.getMainLooper()).post {
            eventSink?.success(status)
        }
    }
}

object BroadcastAudioLevelEvents : EventChannel.StreamHandler {
    private var eventSink: EventChannel.EventSink? = null
    private var currentLevel: Double = 0.0

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
        events?.success(currentLevel)
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    fun send(level: Double) {
        currentLevel = level.coerceIn(0.0, 1.0)
        Handler(Looper.getMainLooper()).post {
            eventSink?.success(currentLevel)
        }
    }
}

object BroadcastStatsEvents : EventChannel.StreamHandler {
    private var eventSink: EventChannel.EventSink? = null
    private var currentStats: Map<String, Any> = emptyStats()

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
        events?.success(currentStats)
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    fun send(
        totalUploadBytes: Long,
        uploadSpeedKbps: Double,
        averageUploadKbps: Double,
        reconnectCount: Int
    ) {
        currentStats = mapOf(
            "totalUploadBytes" to totalUploadBytes,
            "uploadSpeedKbps" to uploadSpeedKbps,
            "averageUploadKbps" to averageUploadKbps,
            "reconnectCount" to reconnectCount
        )
        Handler(Looper.getMainLooper()).post {
            eventSink?.success(currentStats)
        }
    }

    private fun emptyStats() = mapOf(
        "totalUploadBytes" to 0L,
        "uploadSpeedKbps" to 0.0,
        "averageUploadKbps" to 0.0,
        "reconnectCount" to 0
    )
}

object BroadcastLogEvents : EventChannel.StreamHandler {
    private var eventSink: EventChannel.EventSink? = null
    private var lastMessage: String = ""

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
        if (lastMessage.isNotBlank()) {
            events?.success(lastMessage)
        }
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    fun send(message: String) {
        lastMessage = message
        Handler(Looper.getMainLooper()).post {
            eventSink?.success(message)
        }
    }
}

class BroadcastService : Service() {
    private val mainHandler = Handler(Looper.getMainLooper())
    private val statsLock = Any()
    @Volatile
    private var captureRunning = false
    @Volatile
    private var statsRunning = false
    private var audioRecord: AudioRecord? = null
    private var audioEncoder: AudioEncoder? = null
    private var icecastClient: IcecastClient? = null
    private var captureThread: Thread? = null
    private var preserveTerminalStatus = false
    private var baselineTxBytes = 0L
    private var lastTxBytes = 0L
    private var encodedUploadBytes = 0L
    private var lastEncodedUploadBytes = 0L
    private var lastStatsAtMs = 0L
    private var averageUploadKbps = 0.0
    private var reconnectCount = 0
    private var lastStatus = "offline"
    private val statsRunnable = object : Runnable {
        override fun run() {
            if (!statsRunning) return
            sendStatsSnapshot()
            mainHandler.postDelayed(this, STATS_INTERVAL_MS)
        }
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                stopBroadcast()
                return START_NOT_STICKY
            }
            ACTION_START, null -> {
                val bitrateKbps = intent?.getIntExtra(
                    EXTRA_BITRATE_KBPS,
                    DEFAULT_BITRATE_KBPS
                ) ?: DEFAULT_BITRATE_KBPS
                val config = IcecastConfig(
                    host = sanitizeHost(intent?.getStringExtra(EXTRA_HOST).orEmpty()),
                    port = intent?.getIntExtra(EXTRA_PORT, 8000) ?: 8000,
                    mountPoint = intent?.getStringExtra(EXTRA_MOUNT_POINT) ?: "/live",
                    username = intent?.getStringExtra(EXTRA_USERNAME).orEmpty(),
                    password = intent?.getStringExtra(EXTRA_PASSWORD).orEmpty()
                )
                startBroadcast(config, bitrateKbps.coerceIn(64, 128))
            }
        }

        return START_STICKY
    }

    override fun onDestroy() {
        stopAudioCapture()
        stopIcecastClient()
        stopStatsMonitor(sendFinalSnapshot = true)
        isRunning = false
        if (!preserveTerminalStatus && BroadcastStatusEvents.currentStatus != "stopped") {
            BroadcastStatusEvents.send("stopped")
        }
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun startBroadcast(config: IcecastConfig, bitrateKbps: Int) {
        preserveTerminalStatus = false
        isRunning = true
        resetStats()
        BroadcastLogEvents.send("Memulai koneksi ke ${config.host}:${config.port}${config.mountPoint}")
        BroadcastStatusEvents.send("connecting")
        startForeground(NOTIFICATION_ID, buildNotification())
        startStatsMonitor()
        if (!startIcecastClient(config)) {
            stopAfterTerminalStatus()
            return
        }
        startAudioCapture(bitrateKbps)
    }

    private fun stopBroadcast() {
        stopAudioCapture()
        stopIcecastClient()
        isRunning = false
        preserveTerminalStatus = false
        BroadcastAudioLevelEvents.send(0.0)
        stopStatsMonitor(sendFinalSnapshot = true)
        BroadcastLogEvents.send("Siaran dihentikan operator")
        BroadcastStatusEvents.send("stopped")
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    private fun stopAfterTerminalStatus() {
        preserveTerminalStatus = true
        stopAudioCapture()
        stopIcecastClient()
        isRunning = false
        BroadcastAudioLevelEvents.send(0.0)
        stopStatsMonitor(sendFinalSnapshot = true)
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    @SuppressLint("MissingPermission")
    private fun startAudioCapture(bitrateKbps: Int) {
        if (captureRunning) return

        val minBufferSize = AudioRecord.getMinBufferSize(
            SAMPLE_RATE,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT
        )
        if (minBufferSize == AudioRecord.ERROR || minBufferSize == AudioRecord.ERROR_BAD_VALUE) {
            BroadcastAudioLevelEvents.send(0.0)
            return
        }

        val bufferSize = minBufferSize.coerceAtLeast(SAMPLE_RATE / 10)
        val recorder = AudioRecord(
            MediaRecorder.AudioSource.MIC,
            SAMPLE_RATE,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT,
            bufferSize
        )

        if (recorder.state != AudioRecord.STATE_INITIALIZED) {
            recorder.release()
            BroadcastAudioLevelEvents.send(0.0)
            return
        }

        audioRecord = recorder
        val encoder = AudioEncoder(SAMPLE_RATE, bitrateKbps) { frame ->
            icecastClient?.sendFrame(frame)
        }
        audioEncoder = if (runCatching { encoder.start() }.isSuccess) {
            encoder
        } else {
            runCatching { encoder.stop() }
            null
        }
        captureRunning = true
        recorder.startRecording()

        captureThread = Thread {
            val buffer = ShortArray(bufferSize / 2)
            while (captureRunning) {
                val read = recorder.read(buffer, 0, buffer.size)
                if (read > 0) {
                    BroadcastAudioLevelEvents.send(calculateLevel(buffer, read))
                    audioEncoder?.encodePcm(buffer, read)
                }
            }
        }.apply {
            name = "BroadcastAudioCapture"
            start()
        }
    }

    private fun stopAudioCapture() {
        captureRunning = false
        captureThread?.join(500)
        captureThread = null
        audioRecord?.let { recorder ->
            runCatching {
                if (recorder.recordingState == AudioRecord.RECORDSTATE_RECORDING) {
                    recorder.stop()
                }
            }
            recorder.release()
        }
        audioRecord = null
        audioEncoder?.stop()
        audioEncoder = null
        BroadcastAudioLevelEvents.send(0.0)
    }

    private fun startIcecastClient(config: IcecastConfig): Boolean {
        stopIcecastClient()
        if (config.host.isBlank() || config.username.isBlank() || config.password.isBlank()) {
            BroadcastLogEvents.send("Konfigurasi server belum lengkap")
            BroadcastStatusEvents.send("serverUnreachable")
            return false
        }
        icecastClient = IcecastClient(
            config = config,
            onStatus = { status ->
                handleIcecastStatus(status)
            },
            onBytesSent = { bytes ->
                synchronized(statsLock) {
                    encodedUploadBytes += bytes
                }
            }
        ).also { client ->
            client.start()
        }
        return true
    }

    private fun stopIcecastClient() {
        icecastClient?.stop()
        icecastClient = null
    }

    private fun handleIcecastStatus(status: String) {
        if (status == "reconnecting" && lastStatus != "reconnecting") {
            reconnectCount += 1
        }
        lastStatus = status
        BroadcastStatusEvents.send(status)
        BroadcastLogEvents.send(logMessageForStatus(status))
        sendStatsSnapshot()
        if (status == "authenticationFailed") {
            mainHandler.post { stopAfterTerminalStatus() }
        }
    }

    private fun logMessageForStatus(status: String): String {
        return when (status) {
            "connecting" -> "Menghubungkan ke server siaran"
            "live" -> "Server menerima audio, status live"
            "reconnecting" -> "Mencoba reconnect ke server"
            "authenticationFailed" -> "Autentikasi DJ gagal"
            "serverUnreachable" -> "Server tidak bisa dijangkau"
            "connectionDropped" -> "Koneksi siaran terputus"
            else -> "Status native: $status"
        }
    }

    private fun resetStats() {
        synchronized(statsLock) {
            val currentTxBytes = currentAppTxBytes()
            baselineTxBytes = currentTxBytes
            lastTxBytes = currentTxBytes
            encodedUploadBytes = 0L
            lastEncodedUploadBytes = 0L
            lastStatsAtMs = System.currentTimeMillis()
            averageUploadKbps = 0.0
            reconnectCount = 0
            lastStatus = "connecting"
        }
        BroadcastStatsEvents.send(0L, 0.0, 0.0, 0)
    }

    private fun startStatsMonitor() {
        statsRunning = true
        mainHandler.removeCallbacks(statsRunnable)
        mainHandler.post(statsRunnable)
    }

    private fun stopStatsMonitor(sendFinalSnapshot: Boolean) {
        statsRunning = false
        mainHandler.removeCallbacks(statsRunnable)
        if (sendFinalSnapshot) {
            sendStatsSnapshot()
        }
    }

    private fun sendStatsSnapshot() {
        val now = System.currentTimeMillis()
        val currentTxBytes = currentAppTxBytes()
        val snapshot: StatsSnapshot

        synchronized(statsLock) {
            val elapsedSeconds = ((now - lastStatsAtMs).coerceAtLeast(1)).toDouble() / 1000
            val trafficStatsSupported = currentTxBytes != TrafficStats.UNSUPPORTED.toLong() &&
                baselineTxBytes != TrafficStats.UNSUPPORTED.toLong()

            val totalBytes = if (trafficStatsSupported) {
                (currentTxBytes - baselineTxBytes).coerceAtLeast(encodedUploadBytes)
            } else {
                encodedUploadBytes
            }

            val deltaBytes = if (trafficStatsSupported) {
                (currentTxBytes - lastTxBytes).coerceAtLeast(0L)
            } else {
                (encodedUploadBytes - lastEncodedUploadBytes).coerceAtLeast(0L)
            }
            val speedKbps = deltaBytes * 8 / 1000 / elapsedSeconds
            averageUploadKbps = if (averageUploadKbps == 0.0) {
                speedKbps
            } else {
                (averageUploadKbps * 0.82) + (speedKbps * 0.18)
            }

            lastTxBytes = currentTxBytes
            lastEncodedUploadBytes = encodedUploadBytes
            lastStatsAtMs = now
            snapshot = StatsSnapshot(totalBytes, speedKbps, averageUploadKbps, reconnectCount)
        }

        BroadcastStatsEvents.send(
            totalUploadBytes = snapshot.totalUploadBytes,
            uploadSpeedKbps = snapshot.uploadSpeedKbps,
            averageUploadKbps = snapshot.averageUploadKbps,
            reconnectCount = snapshot.reconnectCount
        )
    }

    private fun currentAppTxBytes(): Long {
        return TrafficStats.getUidTxBytes(applicationInfo.uid)
    }

    private fun sanitizeHost(rawHost: String): String {
        val trimmed = rawHost.trim()
        return trimmed
            .removePrefix("https://")
            .removePrefix("http://")
            .substringBefore("/")
            .substringBefore(":")
    }

    private fun calculateLevel(buffer: ShortArray, read: Int): Double {
        var sum = 0.0
        for (index in 0 until read) {
            val sample = buffer[index].toDouble() / Short.MAX_VALUE
            sum += sample * sample
        }

        val rms = sqrt(sum / read)
        return (rms * 3.2).coerceIn(0.0, 1.0)
    }

    private fun buildNotification() =
        NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_btn_speak_now)
            .setContentTitle("Radio Taqriibussunnah")
            .setContentText("Kajian live sedang berjalan")
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        val channel = NotificationChannel(
            CHANNEL_ID,
            "Broadcast Service",
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = "Notifikasi status siaran Radio Taqriibussunnah"
        }

        val notificationManager = getSystemService(NotificationManager::class.java)
        notificationManager.createNotificationChannel(channel)
    }

    companion object {
        const val ACTION_START = "com.radiotaqriibussunnah.broadcaster.START"
        const val ACTION_STOP = "com.radiotaqriibussunnah.broadcaster.STOP"
        const val EXTRA_HOST = "host"
        const val EXTRA_PORT = "port"
        const val EXTRA_MOUNT_POINT = "mountPoint"
        const val EXTRA_USERNAME = "username"
        const val EXTRA_PASSWORD = "password"
        const val EXTRA_BITRATE_KBPS = "bitrateKbps"
        const val DEFAULT_BITRATE_KBPS = 96
        private const val SAMPLE_RATE = 44100
        private const val STATS_INTERVAL_MS = 1000L
        private const val CHANNEL_ID = "radio_taqriibussunnah_broadcast"
        private const val NOTIFICATION_ID = 2910
        private var isRunning = false
    }
}

private data class StatsSnapshot(
    val totalUploadBytes: Long,
    val uploadSpeedKbps: Double,
    val averageUploadKbps: Double,
    val reconnectCount: Int
)
