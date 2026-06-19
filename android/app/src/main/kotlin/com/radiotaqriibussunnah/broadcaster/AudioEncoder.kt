package com.radiotaqriibussunnah.broadcaster

import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaFormat
import java.nio.ByteOrder
import kotlin.math.min

class AudioEncoder(
    private val sampleRate: Int,
    private val bitrateKbps: Int,
    private val channelCount: Int = 1,
    private val onEncodedFrame: (ByteArray) -> Unit = {}
) {
    private val bufferInfo = MediaCodec.BufferInfo()
    private var codec: MediaCodec? = null
    private var totalInputSamples = 0L
    var encodedBytes: Long = 0
        private set

    fun start() {
        val format = MediaFormat.createAudioFormat(
            MediaFormat.MIMETYPE_AUDIO_AAC,
            sampleRate,
            channelCount
        ).apply {
            setInteger(
                MediaFormat.KEY_AAC_PROFILE,
                MediaCodecInfo.CodecProfileLevel.AACObjectLC
            )
            setInteger(MediaFormat.KEY_BIT_RATE, bitrateKbps * 1000)
            setInteger(MediaFormat.KEY_MAX_INPUT_SIZE, MAX_INPUT_SIZE)
        }

        codec = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_AUDIO_AAC).apply {
            configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
            start()
        }
    }

    fun encodePcm(samples: ShortArray, sampleCount: Int) {
        val activeCodec = codec ?: return
        val inputIndex = activeCodec.dequeueInputBuffer(0)
        if (inputIndex >= 0) {
            val inputBuffer = activeCodec.getInputBuffer(inputIndex) ?: return
            inputBuffer.clear()
            inputBuffer.order(ByteOrder.LITTLE_ENDIAN)

            val samplesToWrite = min(sampleCount, inputBuffer.remaining() / BYTES_PER_SAMPLE)
            for (index in 0 until samplesToWrite) {
                inputBuffer.putShort(samples[index])
            }

            val presentationTimeUs = totalInputSamples * MICROS_PER_SECOND / sampleRate
            totalInputSamples += samplesToWrite

            activeCodec.queueInputBuffer(
                inputIndex,
                0,
                samplesToWrite * BYTES_PER_SAMPLE,
                presentationTimeUs,
                0
            )
        }

        drainOutput(activeCodec)
    }

    fun stop() {
        codec?.let { activeCodec ->
            runCatching { drainOutput(activeCodec) }
            runCatching { activeCodec.stop() }
            activeCodec.release()
        }
        codec = null
        totalInputSamples = 0
    }

    private fun drainOutput(activeCodec: MediaCodec) {
        while (true) {
            val outputIndex = activeCodec.dequeueOutputBuffer(bufferInfo, 0)
            when {
                outputIndex == MediaCodec.INFO_TRY_AGAIN_LATER -> return
                outputIndex == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> Unit
                outputIndex >= 0 -> {
                    if (bufferInfo.size > 0 && bufferInfo.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG == 0) {
                        val outputBuffer = activeCodec.getOutputBuffer(outputIndex)
                        if (outputBuffer != null) {
                            outputBuffer.position(bufferInfo.offset)
                            outputBuffer.limit(bufferInfo.offset + bufferInfo.size)
                            val payload = ByteArray(bufferInfo.size)
                            outputBuffer.get(payload)
                            onEncodedFrame(addAdtsHeader(payload))
                        }
                        encodedBytes += bufferInfo.size.toLong()
                    }
                    activeCodec.releaseOutputBuffer(outputIndex, false)
                }
            }
        }
    }

    private fun addAdtsHeader(payload: ByteArray): ByteArray {
        val packetLength = payload.size + ADTS_HEADER_SIZE
        val packet = ByteArray(packetLength)
        val profile = 2
        val frequencyIndex = 4
        val channelConfig = channelCount

        packet[0] = 0xFF.toByte()
        packet[1] = 0xF1.toByte()
        packet[2] = (((profile - 1) shl 6) + (frequencyIndex shl 2) + (channelConfig shr 2)).toByte()
        packet[3] = (((channelConfig and 3) shl 6) + (packetLength shr 11)).toByte()
        packet[4] = ((packetLength and 0x7FF) shr 3).toByte()
        packet[5] = (((packetLength and 7) shl 5) + 0x1F).toByte()
        packet[6] = 0xFC.toByte()
        payload.copyInto(packet, ADTS_HEADER_SIZE)
        return packet
    }

    companion object {
        private const val BYTES_PER_SAMPLE = 2
        private const val ADTS_HEADER_SIZE = 7
        private const val MAX_INPUT_SIZE = 4096
        private const val MICROS_PER_SECOND = 1_000_000L
    }
}
