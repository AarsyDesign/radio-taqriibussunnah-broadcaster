package com.radiotaqriibussunnah.broadcaster

import java.io.File
import java.io.RandomAccessFile
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class AudioRecorder(
    private val recordingsDir: File,
    private val sampleRate: Int,
    private val channelCount: Int = 1,
    private val bitsPerSample: Int = 16
) {
    private var output: RandomAccessFile? = null
    private var dataBytes = 0L
    var recordingFile: File? = null
        private set

    val recordedBytes: Long
        get() = dataBytes

    fun start() {
        recordingsDir.mkdirs()
        val timestamp = SimpleDateFormat("yyyyMMdd-HHmmss", Locale.US).format(Date())
        val file = File(recordingsDir, "radio-taqriibussunnah-$timestamp.wav")
        recordingFile = file
        dataBytes = 0L
        output = RandomAccessFile(file, "rw").apply {
            setLength(0)
            writeWavHeader(this, 0)
        }
    }

    @Synchronized
    fun writePcm(samples: ShortArray, sampleCount: Int) {
        val activeOutput = output ?: return
        for (index in 0 until sampleCount) {
            val value = samples[index].toInt()
            activeOutput.write(value and 0xFF)
            activeOutput.write((value shr 8) and 0xFF)
        }
        dataBytes += sampleCount * BYTES_PER_SAMPLE
    }

    @Synchronized
    fun stop() {
        output?.let { activeOutput ->
            runCatching {
                activeOutput.seek(0)
                writeWavHeader(activeOutput, dataBytes)
            }
            runCatching { activeOutput.close() }
        }
        output = null
    }

    private fun writeWavHeader(file: RandomAccessFile, pcmDataBytes: Long) {
        val byteRate = sampleRate * channelCount * bitsPerSample / 8
        val blockAlign = channelCount * bitsPerSample / 8
        val totalDataLen = pcmDataBytes + 36

        file.writeBytes("RIFF")
        writeLittleEndianInt(file, totalDataLen)
        file.writeBytes("WAVE")
        file.writeBytes("fmt ")
        writeLittleEndianInt(file, 16)
        writeLittleEndianShort(file, 1)
        writeLittleEndianShort(file, channelCount)
        writeLittleEndianInt(file, sampleRate.toLong())
        writeLittleEndianInt(file, byteRate.toLong())
        writeLittleEndianShort(file, blockAlign)
        writeLittleEndianShort(file, bitsPerSample)
        file.writeBytes("data")
        writeLittleEndianInt(file, pcmDataBytes)
    }

    private fun writeLittleEndianInt(file: RandomAccessFile, value: Long) {
        file.write((value and 0xFF).toInt())
        file.write(((value shr 8) and 0xFF).toInt())
        file.write(((value shr 16) and 0xFF).toInt())
        file.write(((value shr 24) and 0xFF).toInt())
    }

    private fun writeLittleEndianShort(file: RandomAccessFile, value: Int) {
        file.write(value and 0xFF)
        file.write((value shr 8) and 0xFF)
    }

    companion object {
        private const val BYTES_PER_SAMPLE = 2
    }
}
