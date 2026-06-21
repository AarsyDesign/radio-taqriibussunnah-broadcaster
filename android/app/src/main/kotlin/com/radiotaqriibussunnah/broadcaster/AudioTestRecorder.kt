package com.radiotaqriibussunnah.broadcaster

import android.annotation.SuppressLint
import android.content.Context
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaPlayer
import android.media.MediaRecorder
import android.media.audiofx.NoiseSuppressor
import android.os.Environment
import java.io.File

data class TestRecordingResult(
    val fileName: String,
    val filePath: String,
    val sizeBytes: Long,
    val durationSeconds: Int
) {
    fun toMap() = mapOf(
        "fileName" to fileName,
        "filePath" to filePath,
        "sizeBytes" to sizeBytes,
        "durationSeconds" to durationSeconds
    )
}

object AudioTestPlayback {
    private var mediaPlayer: MediaPlayer? = null

    fun play(filePath: String): Boolean {
        val file = File(filePath)
        if (!file.exists()) return false

        runCatching {
            mediaPlayer?.stop()
            mediaPlayer?.release()
        }
        mediaPlayer = null

        return runCatching {
            MediaPlayer().apply {
                setDataSource(file.absolutePath)
                setOnCompletionListener {
                    it.release()
                    if (mediaPlayer === it) mediaPlayer = null
                }
                prepare()
                start()
                mediaPlayer = this
            }
        }.isSuccess
    }

    fun delete(filePath: String): Boolean {
        runCatching {
            mediaPlayer?.stop()
            mediaPlayer?.release()
        }
        mediaPlayer = null
        val file = File(filePath)
        return !file.exists() || file.delete()
    }
}

class AudioTestRecorder(private val context: Context) {
    @SuppressLint("MissingPermission")
    fun record15Seconds(
        audioInput: String,
        audioProcessingConfig: AudioProcessingConfig
    ): TestRecordingResult {
        val sourceLabel = if (audioInput.contains("USB", ignoreCase = true)) {
            "USB"
        } else if (audioProcessingConfig.audioSource == MediaRecorder.AudioSource.VOICE_COMMUNICATION) {
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

        val minBufferSize = AudioRecord.getMinBufferSize(
            SAMPLE_RATE,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT
        )
        require(minBufferSize > 0) { "AudioRecord buffer tidak valid" }

        val bufferSize = minBufferSize.coerceAtLeast(SAMPLE_RATE / 10)
        val audioRecord = AudioRecord(
            audioProcessingConfig.audioSource,
            SAMPLE_RATE,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT,
            bufferSize
        )
        require(audioRecord.state == AudioRecord.STATE_INITIALIZED) {
            "AudioRecord gagal diinisialisasi"
        }

        val musicDir = context.getExternalFilesDir(Environment.DIRECTORY_MUSIC)
            ?: context.filesDir
        val recorder = AudioRecorder(File(musicDir, "RadioTaqriibussunnah/TestRecordings"), SAMPLE_RATE)
        val audioProcessor = AudioProcessor(SAMPLE_RATE, audioProcessingConfig)
        var noiseSuppressor: NoiseSuppressor? = null
        val startedAt = System.currentTimeMillis()
        var lastDiagnosticLogAt = 0L

        try {
            AudioEffectsSupport.logAvailability()
            noiseSuppressor = AudioEffectsSupport.enableNoiseSuppressorIfNeeded(
                audioRecord.audioSessionId,
                audioProcessingConfig
            )
            recorder.start()
            audioRecord.startRecording()
            val buffer = ShortArray(bufferSize / 2)
            while (System.currentTimeMillis() - startedAt < TEST_DURATION_MS) {
                val read = audioRecord.read(buffer, 0, buffer.size)
                if (read <= 0) continue

                val processed = audioProcessor.process(buffer, read)
                val diagnostic = AudioDiagnostics.analyze(processed, processed.size)
                BroadcastAudioDiagnosticEvents.send(diagnostic)
                BroadcastAudioLevelEvents.send(AudioDiagnostics.levelFrom(diagnostic))
                recorder.writePcm(processed, processed.size)

                val now = System.currentTimeMillis()
                if (now - lastDiagnosticLogAt >= AUDIO_LOG_INTERVAL_MS) {
                    lastDiagnosticLogAt = now
                    BroadcastLogEvents.send(
                        "[AUDIO LEVEL]\n" +
                            "rms=${"%.4f".format(diagnostic.rms)}\n" +
                            "peak=${"%.4f".format(diagnostic.peak)}\n" +
                            "clipping=${diagnostic.clipping}\n" +
                            "volumeStatus=${diagnostic.volumeStatus}"
                    )
                }
            }
        } finally {
            runCatching {
                if (audioRecord.recordingState == AudioRecord.RECORDSTATE_RECORDING) {
                    audioRecord.stop()
                }
            }
            audioRecord.release()
            runCatching { noiseSuppressor?.release() }
            recorder.stop()
            BroadcastAudioLevelEvents.send(0.0)
        }

        val file = recorder.recordingFile ?: error("File rekaman test tidak dibuat")
        val result = TestRecordingResult(
            fileName = file.name,
            filePath = file.absolutePath,
            sizeBytes = file.length(),
            durationSeconds = TEST_DURATION_SECONDS
        )
        BroadcastLogEvents.send(
            "[TEST RECORDING]\n" +
                "file=${result.filePath}\n" +
                "size=${result.sizeBytes}\n" +
                "duration=${result.durationSeconds}"
        )
        return result
    }

    companion object {
        private const val SAMPLE_RATE = 44100
        private const val TEST_DURATION_SECONDS = 15
        private const val TEST_DURATION_MS = TEST_DURATION_SECONDS * 1000L
        private const val AUDIO_LOG_INTERVAL_MS = 1000L
    }
}
