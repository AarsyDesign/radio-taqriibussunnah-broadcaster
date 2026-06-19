package com.radiotaqriibussunnah.broadcaster

import android.content.Intent
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val methodChannelName = "com.radiotaqriibussunnah.broadcaster/broadcast"
    private val eventChannelName = "com.radiotaqriibussunnah.broadcaster/broadcast_events"
    private val audioLevelEventChannelName = "com.radiotaqriibussunnah.broadcaster/audio_level_events"
    private val statsEventChannelName = "com.radiotaqriibussunnah.broadcaster/stats_events"
    private val logEventChannelName = "com.radiotaqriibussunnah.broadcaster/log_events"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, eventChannelName)
            .setStreamHandler(BroadcastStatusEvents)

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, audioLevelEventChannelName)
            .setStreamHandler(BroadcastAudioLevelEvents)

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, statsEventChannelName)
            .setStreamHandler(BroadcastStatsEvents)

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, logEventChannelName)
            .setStreamHandler(BroadcastLogEvents)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, methodChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startBroadcastService" -> {
                        val bitrate = normalizeBitrate(call.argument<Int>("bitrate") ?: BroadcastService.DEFAULT_BITRATE_KBPS)
                        val intent = Intent(this, BroadcastService::class.java).apply {
                            action = BroadcastService.ACTION_START
                            putExtra(BroadcastService.EXTRA_HOST, call.argument<String>("host") ?: "")
                            putExtra(BroadcastService.EXTRA_PORT, call.argument<Int>("port") ?: 8000)
                            putExtra(BroadcastService.EXTRA_MOUNT_POINT, call.argument<String>("mountPoint") ?: "")
                            putExtra(BroadcastService.EXTRA_USERNAME, call.argument<String>("username") ?: "")
                            putExtra(BroadcastService.EXTRA_PASSWORD, call.argument<String>("password") ?: "")
                            putExtra(BroadcastService.EXTRA_BITRATE_KBPS, bitrate)
                            putExtra(BroadcastService.EXTRA_SERVER_TYPE, call.argument<String>("serverType") ?: BroadcastService.SERVER_TYPE_SHOUTCAST)
                            putExtra(BroadcastService.EXTRA_USTADZ_NAME, call.argument<String>("ustadzName") ?: "")
                            putExtra(BroadcastService.EXTRA_KAJIAN_TITLE, call.argument<String>("kajianTitle") ?: "")
                            putExtra(BroadcastService.EXTRA_KAJIAN_THEME, call.argument<String>("kajianTheme") ?: "")
                            putExtra(BroadcastService.EXTRA_LIVE_METADATA, call.argument<String>("liveMetadata") ?: BroadcastService.LIVE_METADATA_FALLBACK)
                        }
                        ContextCompat.startForegroundService(this, intent)
                        result.success(true)
                    }

                    "stopBroadcastService" -> {
                        val intent = Intent(this, BroadcastService::class.java).apply {
                            action = BroadcastService.ACTION_STOP
                        }
                        startService(intent)
                        result.success(true)
                    }

                    "getServiceStatus" -> result.success(BroadcastStatusEvents.currentStatus)

                    "testBroadcastConnection" -> {
                        Thread {
                            val config = IcecastConfig(
                                host = sanitizeHost(call.argument<String>("host") ?: ""),
                                port = call.argument<Int>("port") ?: 8000,
                                mountPoint = call.argument<String>("mountPoint") ?: "",
                                username = call.argument<String>("username") ?: "",
                                password = call.argument<String>("password") ?: "",
                                serverType = call.argument<String>("serverType") ?: BroadcastService.SERVER_TYPE_SHOUTCAST,
                                bitrateKbps = normalizeBitrate(call.argument<Int>("bitrate") ?: BroadcastService.DEFAULT_BITRATE_KBPS)
                            )
                            val status = IcecastClient.testConnection(config) { message ->
                                BroadcastLogEvents.send(message)
                            }
                            runOnUiThread { result.success(status) }
                        }.apply {
                            name = "BroadcastConnectionTest"
                            start()
                        }
                    }

                    else -> result.notImplemented()
                }
            }
    }

    private fun sanitizeHost(rawHost: String): String {
        val trimmed = rawHost.trim()
        return trimmed
            .removePrefix("https://")
            .removePrefix("http://")
            .substringBefore("/")
            .substringBefore(":")
    }

    private fun normalizeBitrate(value: Int): Int {
        return if (value in listOf(32, 64, 96, 128)) value else BroadcastService.DEFAULT_BITRATE_KBPS
    }
}
