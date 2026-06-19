package com.radiotaqriibussunnah.broadcaster

import android.util.Base64
import java.io.BufferedReader
import java.io.BufferedWriter
import java.io.IOException
import java.io.InputStreamReader
import java.io.OutputStream
import java.io.OutputStreamWriter
import java.net.InetSocketAddress
import java.net.Socket
import java.util.concurrent.LinkedBlockingDeque
import java.util.concurrent.TimeUnit

data class IcecastConfig(
    val host: String,
    val port: Int,
    val mountPoint: String,
    val username: String,
    val password: String
)

class IcecastClient(
    private val config: IcecastConfig,
    private val onStatus: (String) -> Unit,
    private val onBytesSent: (Long) -> Unit = {}
) {
    private val frameQueue = LinkedBlockingDeque<ByteArray>(MAX_QUEUE_SIZE)
    @Volatile
    private var running = false
    private var workerThread: Thread? = null

    fun start() {
        if (running) return
        running = true
        workerThread = Thread(::runLoop).apply {
            name = "IcecastClient"
            start()
        }
    }

    fun stop() {
        running = false
        workerThread?.join(800)
        workerThread = null
        frameQueue.clear()
    }

    fun sendFrame(frame: ByteArray) {
        if (!running) return
        if (!frameQueue.offer(frame)) {
            frameQueue.pollFirst()
            frameQueue.offer(frame)
        }
    }

    private fun runLoop() {
        var hasConnected = false
        while (running) {
            val socket = Socket()
            try {
                onStatus(if (hasConnected) "reconnecting" else "connecting")
                socket.connect(InetSocketAddress(config.host, config.port), CONNECT_TIMEOUT_MS)
                socket.soTimeout = READ_TIMEOUT_MS
                val output = socket.getOutputStream()
                writeHeaders(output)
                validateResponse(socket)

                hasConnected = true
                onStatus("live")
                writeFrames(output)
            } catch (auth: AuthenticationFailedException) {
                onStatus("authenticationFailed")
                running = false
            } catch (error: IOException) {
                onStatus(if (hasConnected) "connectionDropped" else "serverUnreachable")
                sleepBeforeReconnect()
            } finally {
                runCatching { socket.close() }
            }
        }
    }

    private fun writeHeaders(output: OutputStream) {
        val writer = BufferedWriter(OutputStreamWriter(output, Charsets.UTF_8))
        val mount = normalizeMountPoint(config.mountPoint)
        val credentials = "${config.username}:${config.password}"
        val authorization = Base64.encodeToString(
            credentials.toByteArray(Charsets.UTF_8),
            Base64.NO_WRAP
        )

        writer.write("SOURCE $mount ICE/1.0\r\n")
        writer.write("Host: ${config.host}\r\n")
        writer.write("Authorization: Basic $authorization\r\n")
        writer.write("User-Agent: RadioTaqriibussunnahBroadcaster/1.0\r\n")
        writer.write("Content-Type: audio/aac\r\n")
        writer.write("Ice-Name: Radio Taqriibussunnah\r\n")
        writer.write("Ice-Public: 0\r\n")
        writer.write("\r\n")
        writer.flush()
    }

    private fun validateResponse(socket: Socket) {
        val reader = BufferedReader(InputStreamReader(socket.getInputStream(), Charsets.UTF_8))
        val statusLine = reader.readLine().orEmpty()
        val normalized = statusLine.lowercase()
        if (normalized.contains("401") || normalized.contains("403")) {
            throw AuthenticationFailedException()
        }
        if (!normalized.contains("200") && !normalized.contains("ok")) {
            throw IOException("Unexpected Icecast response: $statusLine")
        }
    }

    private fun writeFrames(output: OutputStream) {
        while (running) {
            val frame = frameQueue.poll(500, TimeUnit.MILLISECONDS) ?: continue
            output.write(frame)
            output.flush()
            onBytesSent(frame.size.toLong())
        }
    }

    private fun sleepBeforeReconnect() {
        if (!running) return
        onStatus("reconnecting")
        Thread.sleep(RECONNECT_DELAY_MS)
    }

    private fun normalizeMountPoint(value: String): String {
        val trimmed = value.trim()
        if (trimmed.isEmpty()) return "/live"
        return if (trimmed.startsWith("/")) trimmed else "/$trimmed"
    }

    companion object {
        private const val CONNECT_TIMEOUT_MS = 5000
        private const val READ_TIMEOUT_MS = 5000
        private const val RECONNECT_DELAY_MS = 3000L
        private const val MAX_QUEUE_SIZE = 256
    }
}

class AuthenticationFailedException : IOException()
