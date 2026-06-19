package com.radiotaqriibussunnah.broadcaster

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel
import kotlin.math.abs
import kotlin.math.sqrt

data class AudioDiagnosticSnapshot(
    val rms: Double,
    val peak: Double,
    val clipping: Boolean,
    val volumeStatus: String
)

object BroadcastAudioDiagnosticEvents : EventChannel.StreamHandler {
    private var eventSink: EventChannel.EventSink? = null
    private var currentDiagnostic: Map<String, Any> = emptyDiagnostic()

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
        events?.success(currentDiagnostic)
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    fun send(snapshot: AudioDiagnosticSnapshot) {
        currentDiagnostic = mapOf(
            "rms" to snapshot.rms,
            "peak" to snapshot.peak,
            "clipping" to snapshot.clipping,
            "volumeStatus" to snapshot.volumeStatus
        )
        Handler(Looper.getMainLooper()).post {
            eventSink?.success(currentDiagnostic)
        }
    }

    private fun emptyDiagnostic() = mapOf(
        "rms" to 0.0,
        "peak" to 0.0,
        "clipping" to false,
        "volumeStatus" to "small"
    )
}

object AudioDiagnostics {
    fun analyze(buffer: ShortArray, read: Int): AudioDiagnosticSnapshot {
        if (read <= 0) {
            return AudioDiagnosticSnapshot(0.0, 0.0, false, "small")
        }

        var sum = 0.0
        var peak = 0.0
        var nearLimitSamples = 0
        for (index in 0 until read) {
            val normalized = buffer[index].toDouble() / Short.MAX_VALUE
            val absolute = abs(normalized)
            sum += normalized * normalized
            if (absolute > peak) peak = absolute
            if (absolute >= CLIPPING_SAMPLE_THRESHOLD) {
                nearLimitSamples += 1
            }
        }

        val rms = sqrt(sum / read).coerceIn(0.0, 1.0)
        val clippingSampleLimit = (read * CLIPPING_SAMPLE_RATIO)
            .toInt()
            .coerceAtLeast(3)
        val clipping = peak >= CLIPPING_PEAK_THRESHOLD ||
            nearLimitSamples >= clippingSampleLimit
        val volumeStatus = when {
            clipping -> "clipping"
            rms < SMALL_RMS_THRESHOLD -> "small"
            else -> "safe"
        }

        return AudioDiagnosticSnapshot(
            rms = rms,
            peak = peak.coerceIn(0.0, 1.0),
            clipping = clipping,
            volumeStatus = volumeStatus
        )
    }

    fun levelFrom(snapshot: AudioDiagnosticSnapshot): Double {
        return (snapshot.rms * 3.2).coerceIn(0.0, 1.0)
    }

    private const val SMALL_RMS_THRESHOLD = 0.035
    private const val CLIPPING_PEAK_THRESHOLD = 0.96
    private const val CLIPPING_SAMPLE_THRESHOLD = 0.985
    private const val CLIPPING_SAMPLE_RATIO = 0.01
}
