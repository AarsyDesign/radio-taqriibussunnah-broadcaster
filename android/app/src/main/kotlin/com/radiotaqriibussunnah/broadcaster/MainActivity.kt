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
                        val bitrate = call.argument<Int>("bitrate") ?: BroadcastService.DEFAULT_BITRATE_KBPS
                        val intent = Intent(this, BroadcastService::class.java).apply {
                            action = BroadcastService.ACTION_START
                            putExtra(BroadcastService.EXTRA_HOST, call.argument<String>("host") ?: "")
                            putExtra(BroadcastService.EXTRA_PORT, call.argument<Int>("port") ?: 8000)
                            putExtra(BroadcastService.EXTRA_MOUNT_POINT, call.argument<String>("mountPoint") ?: "/live")
                            putExtra(BroadcastService.EXTRA_USERNAME, call.argument<String>("username") ?: "")
                            putExtra(BroadcastService.EXTRA_PASSWORD, call.argument<String>("password") ?: "")
                            putExtra(BroadcastService.EXTRA_BITRATE_KBPS, bitrate)
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

                    else -> result.notImplemented()
                }
            }
    }
}
