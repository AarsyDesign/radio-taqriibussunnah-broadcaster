package com.radiotaqriibussunnah.broadcaster

import android.media.MediaRecorder
import android.media.audiofx.AcousticEchoCanceler
import android.media.audiofx.AutomaticGainControl
import android.media.audiofx.NoiseSuppressor
import kotlin.math.PI
import kotlin.math.exp
import kotlin.math.pow
import kotlin.math.roundToInt

data class AudioProcessingConfig(
    val inputGainDb: Double = 0.0,
    val noiseSuppressionLevel: String = "Low",
    val highPassFilterHz: Int = 80,
    val limiterEnabled: Boolean = true,
    val audioSourceMode: String = "Natural / MIC"
) {
    val audioSource: Int
        get() = if (audioSourceMode.contains("VOICE_COMMUNICATION")) {
            MediaRecorder.AudioSource.VOICE_COMMUNICATION
        } else {
            MediaRecorder.AudioSource.MIC
        }
}

class AudioProcessor(
    private val sampleRate: Int,
    private val config: AudioProcessingConfig
) {
    private val linearGain = 10.0.pow(config.inputGainDb.coerceIn(-12.0, 12.0) / 20.0)
    private val limiterThreshold = Short.MAX_VALUE * 0.707
    private val highPassAlpha = if (config.highPassFilterHz > 0) {
        val rc = 1.0 / (2.0 * PI * config.highPassFilterHz)
        val dt = 1.0 / sampleRate
        rc / (rc + dt)
    } else {
        0.0
    }
    private var previousInput = 0.0
    private var previousOutput = 0.0

    fun process(samples: ShortArray, sampleCount: Int): ShortArray {
        val processed = ShortArray(sampleCount)
        for (index in 0 until sampleCount) {
            val raw = samples[index].toDouble()
            val filtered = if (config.highPassFilterHz > 0) {
                val output = highPassAlpha * (previousOutput + raw - previousInput)
                previousInput = raw
                previousOutput = output
                output
            } else {
                raw
            }
            val gained = filtered * linearGain
            val limited = if (config.limiterEnabled) {
                softLimit(gained)
            } else {
                gained
            }
            processed[index] = limited
                .coerceIn(Short.MIN_VALUE.toDouble(), Short.MAX_VALUE.toDouble())
                .roundToInt()
                .toShort()
        }
        return processed
    }

    private fun softLimit(value: Double): Double {
        val absolute = kotlin.math.abs(value)
        if (absolute <= limiterThreshold) return value
        val sign = if (value < 0) -1.0 else 1.0
        val over = absolute - limiterThreshold
        val limited = limiterThreshold + (1.0 - exp(-over / limiterThreshold)) *
            (Short.MAX_VALUE - limiterThreshold)
        return sign * limited.coerceAtMost(Short.MAX_VALUE.toDouble())
    }
}

object AudioEffectsSupport {
    fun logAvailability() {
        BroadcastLogEvents.send(
            "[AUDIO EFFECTS]\n" +
                "NoiseSuppressor available=${NoiseSuppressor.isAvailable()}\n" +
                "AGC available=${AutomaticGainControl.isAvailable()}\n" +
                "AEC available=${AcousticEchoCanceler.isAvailable()}"
        )
    }

    fun enableNoiseSuppressorIfNeeded(
        audioSessionId: Int,
        config: AudioProcessingConfig
    ): NoiseSuppressor? {
        if (config.noiseSuppressionLevel == "Off") return null
        if (!NoiseSuppressor.isAvailable()) return null
        return runCatching {
            NoiseSuppressor.create(audioSessionId)?.apply { enabled = true }
        }.getOrNull()
    }
}
