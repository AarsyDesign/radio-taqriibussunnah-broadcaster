package com.radiotaqriibussunnah.broadcaster

import android.annotation.SuppressLint
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.audiofx.NoiseSuppressor
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.TrafficStats
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.IBinder
import android.os.Looper
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
        reconnectCount: Int,
        reconnectAttempt: Int,
        nextReconnectDelayMs: Long,
        recordingFilePath: String,
        recordingBytes: Long
    ) {
        currentStats = mapOf(
            "totalUploadBytes" to totalUploadBytes,
            "uploadSpeedKbps" to uploadSpeedKbps,
            "averageUploadKbps" to averageUploadKbps,
            "reconnectCount" to reconnectCount,
            "reconnectAttempt" to reconnectAttempt,
            "nextReconnectDelayMs" to nextReconnectDelayMs,
            "recordingFilePath" to recordingFilePath,
            "recordingBytes" to recordingBytes
        )
        Handler(Looper.getMainLooper()).post {
            eventSink?.success(currentStats)
        }
    }

    private fun emptyStats() = mapOf(
        "totalUploadBytes" to 0L,
        "uploadSpeedKbps" to 0.0,
        "averageUploadKbps" to 0.0,
        "reconnectCount" to 0,
        "reconnectAttempt" to 0,
        "nextReconnectDelayMs" to 0L,
        "recordingFilePath" to "",
        "recordingBytes" to 0L
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
    @Volatile
    private var audioStarted = false

    private var audioRecord: AudioRecord? = null
    private var audioEncoder: AudioEncoder? = null
    private var audioRecorder: AudioRecorder? = null
    private var icecastClient: IcecastClient? = null
    private var captureThread: Thread? = null
    private var preserveTerminalStatus = false
    private var currentBitrateKbps = DEFAULT_BITRATE_KBPS
    private var lastAudioInput = "Mic HP"
    private var audioProcessingConfig = AudioProcessingConfig()
    private var noiseSuppressor: NoiseSuppressor? = null

    private var baselineTxBytes = 0L
    private var lastTxBytes = 0L
    private var encodedUploadBytes = 0L
    private var lastEncodedUploadBytes = 0L
    private var lastStatsAtMs = 0L
    private var averageUploadKbps = 0.0
    private var reconnectCount = 0
    private var reconnectAttempt = 0
    private var nextReconnectDelayMs = 0L
    private var recordingFilePath = ""
    private var recordingBytes = 0L
    private var lastStatus = "offline"
    private var lastAudioDiagnosticLogAtMs = 0L
    private var connectivityManager: ConnectivityManager? = null
    private var networkCallback: ConnectivityManager.NetworkCallback? = null

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
                val bitrateKbps = normalizeBitrate(
                    intent?.getIntExtra(EXTRA_BITRATE_KBPS, DEFAULT_BITRATE_KBPS)
                        ?: DEFAULT_BITRATE_KBPS
                )
                val config = IcecastConfig(
                    host = sanitizeHost(intent?.getStringExtra(EXTRA_HOST).orEmpty()),
                    port = intent?.getIntExtra(EXTRA_PORT, 8000) ?: 8000,
                    mountPoint = intent?.getStringExtra(EXTRA_MOUNT_POINT).orEmpty(),
                    username = intent?.getStringExtra(EXTRA_USERNAME).orEmpty(),
                    password = intent?.getStringExtra(EXTRA_PASSWORD).orEmpty(),
                    serverType = intent?.getStringExtra(EXTRA_SERVER_TYPE) ?: SERVER_TYPE_SHOUTCAST,
                    bitrateKbps = bitrateKbps,
                    ustadzName = cleanMetadataField(
                        intent?.getStringExtra(EXTRA_USTADZ_NAME).orEmpty(),
                        80
                    ),
                    kajianTitle = cleanMetadataField(
                        intent?.getStringExtra(EXTRA_KAJIAN_TITLE).orEmpty(),
                        80
                    ),
                    kajianTheme = cleanMetadataField(
                        intent?.getStringExtra(EXTRA_KAJIAN_THEME).orEmpty(),
                        120
                    ),
                    liveMetadata = cleanLiveMetadata(
                        intent?.getStringExtra(EXTRA_LIVE_METADATA).orEmpty()
                    )
                )
                lastAudioInput = intent?.getStringExtra(EXTRA_AUDIO_INPUT) ?: "Mic HP"
                audioProcessingConfig = AudioProcessingConfig(
                    inputGainDb = intent?.getDoubleExtra(EXTRA_INPUT_GAIN_DB, 0.0) ?: 0.0,
                    noiseSuppressionLevel = intent?.getStringExtra(EXTRA_NOISE_SUPPRESSION_LEVEL) ?: "Low",
                    highPassFilterHz = intent?.getIntExtra(EXTRA_HIGH_PASS_FILTER_HZ, 80) ?: 80,
                    limiterEnabled = intent?.getBooleanExtra(EXTRA_LIMITER_ENABLED, true) ?: true,
                    audioSourceMode = intent?.getStringExtra(EXTRA_AUDIO_SOURCE_MODE) ?: "Natural / MIC"
                )
                startBroadcast(config)
            }
        }

        return START_STICKY
    }

    override fun onDestroy() {
        stopAudioCapture()
        stopNetworkWatchdog()
        stopIcecastClient()
        stopStatsMonitor(sendFinalSnapshot = true)
        isRunning = false
        if (!preserveTerminalStatus && BroadcastStatusEvents.currentStatus != "stopped") {
            BroadcastStatusEvents.send("stopped")
        }
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun startBroadcast(config: IcecastConfig) {
        val isValid = isValidConfig(config)
        logValidation(config, isValid)
        if (!isValid) {
            BroadcastLogEvents.send("[RESULT]\nINVALID CONFIG")
            BroadcastStatusEvents.send("invalidConfig")
            stopSelf()
            return
        }
        logMetadata(config)

        preserveTerminalStatus = false
        isRunning = true
        audioStarted = false
        currentBitrateKbps = config.bitrateKbps
        resetStats()
        BroadcastLogEvents.send("[TEST]\nStarting broadcast runtime")
        BroadcastStatusEvents.send("connecting")
        startForeground(NOTIFICATION_ID, buildNotification())
        startStatsMonitor()
        startNetworkWatchdog()
        startIcecastClient(config)
    }

    private fun stopBroadcast() {
        stopAudioCapture()
        stopNetworkWatchdog()
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
        stopNetworkWatchdog()
        stopIcecastClient()
        isRunning = false
        BroadcastAudioLevelEvents.send(0.0)
        stopStatsMonitor(sendFinalSnapshot = true)
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    private fun startIcecastClient(config: IcecastConfig) {
        stopIcecastClient()
        val client = IcecastClient(
            config = config,
            onStatus = { status -> handleClientStatus(status) },
            onBytesSent = { bytes ->
                synchronized(statsLock) {
                    encodedUploadBytes += bytes
                }
            },
            onReconnectState = { attempt, delayMs ->
                synchronized(statsLock) {
                    reconnectAttempt = attempt
                    nextReconnectDelayMs = delayMs
                }
                sendStatsSnapshot()
            },
            onLog = { message -> BroadcastLogEvents.send(message) }
        )
        icecastClient = client
        client.start()
    }

    private fun handleClientStatus(status: String) {
        if (status == "liveRestored") {
            reconnectCount += 1
        }
        if (status == "live" || status == "liveRestored") {
            synchronized(statsLock) {
                reconnectAttempt = 0
                nextReconnectDelayMs = 0L
            }
        }
        if ((status == "live" || status == "liveRestored") && !audioStarted) {
            audioStarted = true
            mainHandler.post { startAudioCapture(currentBitrateKbps) }
        }
        if (status != lastStatus) {
            lastStatus = status
            BroadcastStatusEvents.send(status)
        }
        sendStatsSnapshot()
        if (isTerminalStatus(status)) {
            mainHandler.post { stopAfterTerminalStatus() }
        }
    }

    private fun stopIcecastClient() {
        runCatching { icecastClient?.stop() }
        icecastClient = null
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
            BroadcastLogEvents.send("AudioRecord buffer tidak valid")
            BroadcastAudioLevelEvents.send(0.0)
            return
        }

        val bufferSize = minBufferSize.coerceAtLeast(SAMPLE_RATE / 10)
        val sourceLabel = if (lastAudioInput.contains("USB", ignoreCase = true)) {
            "USB"
        } else if (audioProcessingConfig.audioSource == android.media.MediaRecorder.AudioSource.VOICE_COMMUNICATION) {
            "VOICE_COMMUNICATION"
        } else {
            "MIC"
        }
        BroadcastLogEvents.send(
            "[AUDIO INPUT]\n" +
                "source=$sourceLabel\n" +
                "sampleRate=$SAMPLE_RATE\n" +
                "channel=mono\n" +
                "pcmFormat=16bit"
        )
        val recorder = AudioRecord(
            audioProcessingConfig.audioSource,
            SAMPLE_RATE,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT,
            bufferSize
        )

        if (recorder.state != AudioRecord.STATE_INITIALIZED) {
            recorder.release()
            BroadcastLogEvents.send("AudioRecord gagal diinisialisasi")
            BroadcastAudioLevelEvents.send(0.0)
            return
        }
        AudioEffectsSupport.logAvailability()
        noiseSuppressor = AudioEffectsSupport.enableNoiseSuppressorIfNeeded(
            recorder.audioSessionId,
            audioProcessingConfig
        )
        val audioProcessor = AudioProcessor(SAMPLE_RATE, audioProcessingConfig)

        val encoder = AudioEncoder(SAMPLE_RATE, bitrateKbps) { frame ->
            icecastClient?.sendFrame(frame)
        }
        audioEncoder = if (runCatching { encoder.start() }.isSuccess) {
            BroadcastLogEvents.send("Encoder AAC-LC started, bitrate=${bitrateKbps * 1000}")
            encoder
        } else {
            BroadcastLogEvents.send("Encoder AAC-LC gagal dimulai")
            runCatching { encoder.stop() }
            null
        }

        audioRecord = recorder
        startAudioRecording()
        captureRunning = true
        recorder.startRecording()

        captureThread = Thread {
            val buffer = ShortArray(bufferSize / 2)
            while (captureRunning) {
                val read = recorder.read(buffer, 0, buffer.size)
                if (read > 0 && captureRunning) {
                    val processed = audioProcessor.process(buffer, read)
                    val diagnostic = AudioDiagnostics.analyze(processed, processed.size)
                    BroadcastAudioLevelEvents.send(AudioDiagnostics.levelFrom(diagnostic))
                    BroadcastAudioDiagnosticEvents.send(diagnostic)
                    logAudioDiagnostic(diagnostic)
                    audioRecorder?.writePcm(processed, processed.size)
                    audioEncoder?.encodePcm(processed, processed.size)
                }
            }
        }.apply {
            name = "BroadcastAudioCapture"
            start()
        }
    }

    private fun stopAudioCapture() {
        captureRunning = false
        runCatching { captureThread?.join(500) }
        captureThread = null

        runCatching {
            if (audioRecord?.recordingState == AudioRecord.RECORDSTATE_RECORDING) {
                audioRecord?.stop()
            }
        }
        runCatching { audioRecord?.release() }
        audioRecord = null

        runCatching { audioEncoder?.stop() }
        audioEncoder = null
        runCatching { noiseSuppressor?.release() }
        noiseSuppressor = null

        audioRecorder?.let { recorder ->
            recordingBytes = recorder.recordedBytes
            runCatching { recorder.stop() }
            if (recordingFilePath.isNotBlank()) {
                BroadcastLogEvents.send("Rekaman lokal disimpan: $recordingFilePath")
            }
        }
        audioRecorder = null
        BroadcastAudioLevelEvents.send(0.0)
    }

    private fun startAudioRecording() {
        val musicDir = getExternalFilesDir(Environment.DIRECTORY_MUSIC) ?: filesDir
        val recordingsDir = java.io.File(musicDir, "recordings")
        val recorder = AudioRecorder(recordingsDir, SAMPLE_RATE)
        audioRecorder = if (runCatching { recorder.start() }.isSuccess) {
            recordingFilePath = recorder.recordingFile?.absolutePath.orEmpty()
            recordingBytes = 0L
            BroadcastLogEvents.send("Rekaman lokal dimulai: $recordingFilePath")
            recorder
        } else {
            recordingFilePath = ""
            recordingBytes = 0L
            BroadcastLogEvents.send("Rekaman lokal gagal, broadcast tetap berjalan.")
            null
        }
    }

    private fun startStatsMonitor() {
        if (statsRunning) return
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
            reconnectAttempt = 0
            nextReconnectDelayMs = 0L
            recordingFilePath = ""
            recordingBytes = 0L
            lastStatus = "connecting"
            lastAudioDiagnosticLogAtMs = 0L
        }
        BroadcastStatsEvents.send(0L, 0.0, 0.0, 0, 0, 0L, "", 0L)
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
            snapshot = StatsSnapshot(
                totalUploadBytes = totalBytes,
                uploadSpeedKbps = speedKbps,
                averageUploadKbps = averageUploadKbps,
                reconnectCount = reconnectCount,
                reconnectAttempt = reconnectAttempt,
                nextReconnectDelayMs = nextReconnectDelayMs,
                recordingFilePath = recordingFilePath,
                recordingBytes = audioRecorder?.recordedBytes ?: recordingBytes
            )
        }

        BroadcastStatsEvents.send(
            totalUploadBytes = snapshot.totalUploadBytes,
            uploadSpeedKbps = snapshot.uploadSpeedKbps,
            averageUploadKbps = snapshot.averageUploadKbps,
            reconnectCount = snapshot.reconnectCount,
            reconnectAttempt = snapshot.reconnectAttempt,
            nextReconnectDelayMs = snapshot.nextReconnectDelayMs,
            recordingFilePath = snapshot.recordingFilePath,
            recordingBytes = snapshot.recordingBytes
        )
    }

    private fun currentAppTxBytes(): Long {
        return TrafficStats.getUidTxBytes(applicationInfo.uid)
    }

    private fun startNetworkWatchdog() {
        val manager = getSystemService(CONNECTIVITY_SERVICE) as? ConnectivityManager ?: return
        connectivityManager = manager
        if (!hasValidatedInternet(manager)) {
            BroadcastLogEvents.send("Jaringan terputus. Menunggu koneksi kembali.")
            BroadcastStatusEvents.send("networkLost")
        }

        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) return
        val callback = object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) {
                if (!isRunning) return
                mainHandler.postDelayed({
                    if (!isRunning) return@postDelayed
                    if (hasValidatedInternet(manager) &&
                        BroadcastStatusEvents.currentStatus == "networkLost"
                    ) {
                        BroadcastLogEvents.send("Jaringan kembali. Mencoba reconnect otomatis.")
                        BroadcastStatusEvents.send("reconnecting")
                        icecastClient?.forceReconnect("network restored")
                    }
                }, 600)
            }

            override fun onLost(network: Network) {
                if (!isRunning || !audioStarted) return
                mainHandler.post {
                    if (!isRunning || hasValidatedInternet(manager)) return@post
                    BroadcastLogEvents.send("Jaringan terputus. Menunggu koneksi kembali.")
                    BroadcastStatusEvents.send("networkLost")
                    icecastClient?.forceReconnect("network lost")
                    sendStatsSnapshot()
                }
            }
        }

        runCatching {
            manager.registerDefaultNetworkCallback(callback)
            networkCallback = callback
        }.onFailure {
            BroadcastLogEvents.send("Network Watchdog fallback ke socket watchdog.")
        }
    }

    private fun stopNetworkWatchdog() {
        val callback = networkCallback ?: return
        runCatching { connectivityManager?.unregisterNetworkCallback(callback) }
        networkCallback = null
        connectivityManager = null
    }

    private fun hasValidatedInternet(manager: ConnectivityManager): Boolean {
        val network = manager.activeNetwork ?: return false
        val capabilities = manager.getNetworkCapabilities(network) ?: return false
        return capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
    }

    private fun sanitizeHost(rawHost: String): String {
        val trimmed = rawHost.trim()
        return trimmed
            .removePrefix("https://")
            .removePrefix("http://")
            .substringBefore("/")
            .substringBefore(":")
    }

    private fun logAudioDiagnostic(diagnostic: AudioDiagnosticSnapshot) {
        val now = System.currentTimeMillis()
        if (now - lastAudioDiagnosticLogAtMs < AUDIO_DIAGNOSTIC_LOG_INTERVAL_MS) return
        lastAudioDiagnosticLogAtMs = now
        BroadcastLogEvents.send(
            "[AUDIO LEVEL]\n" +
                "rms=${"%.4f".format(diagnostic.rms)}\n" +
                "peak=${"%.4f".format(diagnostic.peak)}\n" +
                "clipping=${diagnostic.clipping}\n" +
                "volumeStatus=${diagnostic.volumeStatus}"
        )
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

    private fun isTerminalStatus(status: String): Boolean {
        return status == "authenticationFailed" ||
            status == "serverUnreachable" ||
            status == "reconnectFailed" ||
            status == "timeout" ||
            status == "invalidConfig" ||
            status == "protocolRejected" ||
            status == "unsupportedCodec" ||
            status == "unknownError"
    }

    private fun isValidConfig(config: IcecastConfig): Boolean {
        val validBitrate = config.bitrateKbps in listOf(32, 64, 96, 128)
        val hasCore = config.host.isNotBlank() &&
            config.port in 1..65535 &&
            config.password.isNotBlank() &&
            validBitrate
        val hasProtocolFields = config.serverType == SERVER_TYPE_SHOUTCAST ||
            (config.username.isNotBlank() && config.mountPoint.startsWith("/"))
        return hasCore && hasProtocolFields
    }

    private fun logValidation(config: IcecastConfig, isValid: Boolean) {
        BroadcastLogEvents.send(
            "[VALIDATION]\n" +
                "host=${config.host}\n" +
                "port=${config.port}\n" +
                "mount=${config.mountPoint}\n" +
                "username=${config.username}\n" +
                "result=${if (isValid) "valid" else "invalid"}"
        )
    }

    private fun logMetadata(config: IcecastConfig) {
        BroadcastLogEvents.send(
            "[METADATA]\n" +
                "ustadzName=${config.ustadzName}\n" +
                "kajianTitle=${config.kajianTitle}\n" +
                "kajianTheme=${config.kajianTheme}\n" +
                "liveMetadata=${config.liveMetadata}"
        )
    }

    private fun cleanMetadataField(value: String, maxLength: Int): String {
        val cleaned = value.trim().replace(Regex("\\s+"), " ")
        return if (cleaned.length <= maxLength) cleaned else cleaned.substring(0, maxLength)
    }

    private fun cleanLiveMetadata(value: String): String {
        val cleaned = value.trim().replace(Regex("\\s+"), " ")
        return cleaned.ifBlank { LIVE_METADATA_FALLBACK }
    }

    private fun normalizeBitrate(value: Int): Int {
        return if (value in listOf(32, 64, 96, 128)) value else DEFAULT_BITRATE_KBPS
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
        const val EXTRA_AUDIO_INPUT = "audioInput"
        const val EXTRA_INPUT_GAIN_DB = "inputGainDb"
        const val EXTRA_NOISE_SUPPRESSION_LEVEL = "noiseSuppressionLevel"
        const val EXTRA_HIGH_PASS_FILTER_HZ = "highPassFilterHz"
        const val EXTRA_LIMITER_ENABLED = "limiterEnabled"
        const val EXTRA_AUDIO_SOURCE_MODE = "audioSourceMode"
        const val EXTRA_SERVER_TYPE = "serverType"
        const val EXTRA_USTADZ_NAME = "ustadzName"
        const val EXTRA_KAJIAN_TITLE = "kajianTitle"
        const val EXTRA_KAJIAN_THEME = "kajianTheme"
        const val EXTRA_LIVE_METADATA = "liveMetadata"
        const val SERVER_TYPE_ICECAST = "Icecast/AzuraCast"
        const val SERVER_TYPE_SHOUTCAST = "SHOUTcast"
        const val LIVE_METADATA_FALLBACK = "Kajian Live Radio Taqriibussunnah"
        const val DEFAULT_BITRATE_KBPS = 64
        private const val SAMPLE_RATE = 44100
        private const val STATS_INTERVAL_MS = 1000L
        private const val AUDIO_DIAGNOSTIC_LOG_INTERVAL_MS = 1000L
        private const val CHANNEL_ID = "radio_taqriibussunnah_broadcast"
        private const val NOTIFICATION_ID = 2910
        private var isRunning = false
    }
}

private data class StatsSnapshot(
    val totalUploadBytes: Long,
    val uploadSpeedKbps: Double,
    val averageUploadKbps: Double,
    val reconnectCount: Int,
    val reconnectAttempt: Int,
    val nextReconnectDelayMs: Long,
    val recordingFilePath: String,
    val recordingBytes: Long
)
