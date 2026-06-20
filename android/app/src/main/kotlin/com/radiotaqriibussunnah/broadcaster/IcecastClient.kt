package com.radiotaqriibussunnah.broadcaster

import android.util.Base64
import java.io.BufferedReader
import java.io.BufferedWriter
import java.io.IOException
import java.io.InputStreamReader
import java.io.OutputStream
import java.io.OutputStreamWriter
import java.net.InetSocketAddress
import java.net.InetAddress
import java.net.Socket
import java.net.SocketTimeoutException
import java.util.concurrent.LinkedBlockingDeque
import java.util.concurrent.TimeUnit

data class IcecastConfig(
    val host: String,
    val port: Int,
    val mountPoint: String,
    val username: String,
    val password: String,
    val serverType: String,
    val bitrateKbps: Int,
    val ustadzName: String = "",
    val kajianTitle: String = "",
    val kajianTheme: String = "",
    val liveMetadata: String = "Kajian Live Radio Taqriibussunnah"
)

class IcecastClient(
    private val config: IcecastConfig,
    private val onStatus: (String) -> Unit,
    private val onBytesSent: (Long) -> Unit = {},
    private val onReconnectState: (Int, Long) -> Unit = { _, _ -> },
    private val onLog: (String) -> Unit = {}
) {
    private val frameQueue = LinkedBlockingDeque<ByteArray>(MAX_QUEUE_SIZE)
    @Volatile
    private var running = false
    @Volatile
    private var currentSocket: Socket? = null
    private var workerThread: Thread? = null
    private var firstFrameLogged = false
    private var lastBufferDropLogAtMs = 0L

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
        runCatching { currentSocket?.close() }
        workerThread?.join(800)
        workerThread = null
        frameQueue.clear()
    }

    fun sendFrame(frame: ByteArray) {
        if (!running) return
        if (!frameQueue.offer(frame)) {
            frameQueue.pollFirst()
            frameQueue.offer(frame)
            logBufferDrop()
        }
    }

    fun forceReconnect(reason: String) {
        if (!running) return
        val normalizedReason = reason.ifBlank { "networkLost" }
        onLog("Network Watchdog: $normalizedReason. Socket lama ditutup aman untuk reconnect cepat.")
        if (normalizedReason.contains("network", ignoreCase = true) ||
            normalizedReason.contains("offline", ignoreCase = true)
        ) {
            onStatus("networkLost")
        }
        runCatching { currentSocket?.close() }
    }

    private fun runLoop() {
        var hasConnected = false
        var attempts = 0
        while (running) {
            val socket = Socket()
            currentSocket = socket
            try {
                onStatus(if (hasConnected || attempts > 0) "reconnecting" else "connecting")
                onLog("[TEST]\nRuntime connection start")
                logValidation(config, true, onLog)
                val address = resolveHost(config.host, onLog)
                onLog("[SOCKET]\nConnecting to ${address.hostAddress}:${config.port}\nConnect timeout: $CONNECT_TIMEOUT_MS ms\nRead timeout: $READ_TIMEOUT_MS ms")
                socket.connect(InetSocketAddress(address, config.port), CONNECT_TIMEOUT_MS)
                socket.soTimeout = READ_TIMEOUT_MS
                onLog("[SOCKET]\nSuccess\nSocket connected")
                performHandshake(socket)
                val restored = hasConnected || attempts > 0
                hasConnected = true
                attempts = 0
                onReconnectState(0, 0L)
                firstFrameLogged = false
                onLog("[RESULT]\nSUCCESS")
                if (restored) {
                    onLog("Reconnect success. Metadata terakhir dikirim ulang.")
                    onStatus("liveRestored")
                } else {
                    onStatus("live")
                }
                writeFrames(socket.getOutputStream())
            } catch (auth: AuthenticationFailedException) {
                onLog("Authentication failed")
                onStatus("authenticationFailed")
                running = false
            } catch (codec: UnsupportedCodecException) {
                onLog(codec.message ?: "Unsupported codec")
                onStatus("unsupportedCodec")
                running = false
            } catch (protocol: ProtocolRejectedException) {
                onLog(protocol.message ?: "Protocol rejected")
                onStatus("protocolRejected")
                running = false
            } catch (timeout: SocketTimeoutException) {
                attempts += 1
                logSocketFailure(timeout, "Timeout")
                if (!retryOrFinish(attempts, if (hasConnected) "reconnectFailed" else "timeout")) {
                    running = false
                }
            } catch (error: IOException) {
                attempts += 1
                val status = classifySocketStatus(error, hasConnected)
                logSocketFailure(error, status)
                if (!retryOrFinish(attempts, if (hasConnected) "reconnectFailed" else status)) {
                    running = false
                }
            } catch (error: Exception) {
                onLog("Unknown error: ${error.message.orEmpty()}")
                onStatus("unknownError")
                running = false
            } finally {
                runCatching { socket.close() }
                if (currentSocket === socket) {
                    currentSocket = null
                }
            }
        }
    }


    private fun classifySocketStatus(error: IOException, hasConnected: Boolean): String {
        val message = error.message.orEmpty().lowercase()
        if (message.contains("network is unreachable") ||
            message.contains("no route") ||
            message.contains("host unreachable") ||
            message.contains("software caused connection abort")
        ) {
            return "networkLost"
        }
        return if (hasConnected) "reconnectFailed" else "serverUnreachable"
    }

    private fun logSocketFailure(error: IOException, label: String) {
        onLog("[RESULT]\nSOCKET WATCHDOG: ${describeSocketFailure(error)}\nStatus hint: $label")
    }

    private fun describeSocketFailure(error: IOException): String {
        val message = error.message.orEmpty()
        val lower = message.lowercase()
        val type = when {
            error is SocketTimeoutException -> "Timeout"
            lower.contains("broken pipe") -> "Broken Pipe"
            lower.contains("connection reset") -> "Connection Reset"
            lower.contains("network is unreachable") || lower.contains("no route") -> "Network Lost"
            lower.contains("write") -> "Write Failure"
            else -> "Socket Error"
        }
        return "$type: $message"
    }
    private fun retryOrFinish(attempts: Int, finalStatus: String): Boolean {
        if (!running) return false
        if (attempts > MAX_RECONNECT_ATTEMPTS) {
            onReconnectState(MAX_RECONNECT_ATTEMPTS, 0L)
            onLog("Gagal menyambung ulang setelah $MAX_RECONNECT_ATTEMPTS percobaan.")
            onStatus(finalStatus)
            return false
        }
        onStatus("reconnecting")
        val delayMs = reconnectDelayMs(attempts)
        onReconnectState(attempts, delayMs)
        onLog("Reconnect attempt $attempts/$MAX_RECONNECT_ATTEMPTS in ${formatDelay(delayMs)}")
        Thread.sleep(delayMs)
        return true
    }

    private fun performHandshake(socket: Socket) {
        if (config.serverType == BroadcastService.SERVER_TYPE_SHOUTCAST) {
            writeShoutcastHandshake(socket, socket.getOutputStream())
        } else {
            writeIcecastHeaders(socket.getOutputStream())
            validateIcecastResponse(socket)
        }
    }

    private fun writeIcecastHeaders(output: OutputStream) {
        val writer = BufferedWriter(OutputStreamWriter(output, Charsets.UTF_8))
        val mount = normalizeMountPoint(config.mountPoint)
        val authorization = Base64.encodeToString(
            "${config.username}:${config.password}".toByteArray(Charsets.UTF_8),
            Base64.NO_WRAP
        )

        onLog("[ICECAST]\nmount=$mount\nusername=${config.username}\npassword_length=${config.password.length}")
        onLog("[ICECAST]\nSending SOURCE request")
        writer.write("SOURCE $mount ICE/1.0\r\n")
        writer.write("Host: ${config.host}\r\n")
        writer.write("Authorization: Basic $authorization\r\n")
        writer.write("User-Agent: RadioTaqriibussunnahBroadcaster/1.0\r\n")
        writer.write("Content-Type: audio/aacp\r\n")
        writer.write("Ice-Name: Radio Taqriibussunnah\r\n")
        writer.write("Ice-Description: ${config.liveMetadata}\r\n")
        writer.write("Ice-Genre: Kajian Islam\r\n")
        writer.write("icy-name: Radio Taqriibussunnah\r\n")
        writer.write("icy-description: ${config.liveMetadata}\r\n")
        writer.write("icy-genre: Kajian Islam\r\n")
        writer.write("Ice-Public: 0\r\n")
        writer.write("\r\n")
        writer.flush()
    }

    private fun writeShoutcastHandshake(socket: Socket, output: OutputStream) {
        val writer = BufferedWriter(OutputStreamWriter(output, Charsets.UTF_8))
        val passwordFormat = when {
            config.password.contains(":") -> "colon"
            config.password.contains(",") -> "comma"
            else -> "plain"
        }
        onLog("[SHOUTCAST]\nport=${config.port}\npassword_format=$passwordFormat")
        onLog("[SHOUTCAST]\nSending source handshake")
        writer.write("${config.password}\r\n")
        writer.flush()
        validateShoutcastPasswordResponse(socket)

        writer.write("icy-name:Radio Taqriibussunnah\r\n")
        writer.write("icy-genre:Kajian Islam\r\n")
        writer.write("icy-description:${config.liveMetadata}\r\n")
        writer.write("icy-title:${config.liveMetadata}\r\n")
        writer.write("icy-br:${config.bitrateKbps}\r\n")
        writer.write("icy-pub:0\r\n")
        writer.write("icy-url:\r\n")
        writer.write("content-type:audio/aacp\r\n")
        writer.write("\r\n")
        writer.flush()
        onLog("[SHOUTCAST]\nMetadata sent, icy-br=${config.bitrateKbps}")
    }

    private fun validateIcecastResponse(socket: Socket) {
        val statusLine = readStatusLine(socket)
        val normalized = statusLine.lowercase()
        onLog("[SERVER RESPONSE]\n${statusLine.take(120)}")
        if (normalized.contains("401") || normalized.contains("403")) {
            onLog("[RESULT]\nAUTH FAILED")
            throw AuthenticationFailedException()
        }
        if (!normalized.contains("200") && !normalized.contains("ok")) {
            onLog("[RESULT]\nPROTOCOL REJECTED")
            throw ProtocolRejectedException("Unexpected Icecast response: ${statusLine.take(120)}")
        }
    }

    private fun validateShoutcastPasswordResponse(socket: Socket) {
        val statusLine = readStatusLine(socket)
        val normalized = statusLine.lowercase()
        onLog("[SERVER RESPONSE]\n${statusLine.take(120)}")
        if (normalized.contains("invalid") || normalized.contains("bad") || normalized.contains("denied")) {
            onLog("[RESULT]\nAUTH FAILED")
            throw AuthenticationFailedException()
        }
        if (normalized.contains("mp3") && !normalized.contains("aac")) {
            throw UnsupportedCodecException("Server kemungkinan hanya menerima MP3. Gunakan mode Icecast/AzuraCast atau tambahkan encoder MP3.")
        }
        if (!normalized.contains("ok")) {
            onLog("[RESULT]\nPROTOCOL REJECTED")
            throw ProtocolRejectedException("Unexpected SHOUTcast response: ${statusLine.take(120)}")
        }
    }

    private fun readStatusLine(socket: Socket): String {
        val reader = BufferedReader(InputStreamReader(socket.getInputStream(), Charsets.UTF_8))
        return reader.readLine().orEmpty()
    }

    private fun writeFrames(output: OutputStream) {
        while (running) {
            val frame = frameQueue.poll(500, TimeUnit.MILLISECONDS) ?: continue
            try {
                output.write(frame)
                output.flush()
            } catch (error: IOException) {
                onLog("Socket Watchdog: Write Failure. ${describeSocketFailure(error)}")
                throw error
            }
            onBytesSent(frame.size.toLong())
            if (!firstFrameLogged) {
                firstFrameLogged = true
                onLog("First audio frame sent (${frame.size} bytes)")
            }
        }
    }

    private fun logBufferDrop() {
        val now = System.currentTimeMillis()
        if (now - lastBufferDropLogAtMs < BUFFER_DROP_LOG_INTERVAL_MS) return
        lastBufferDropLogAtMs = now
        onLog("Output buffer penuh, frame lama dibuang.")
    }

    private fun normalizeMountPoint(value: String): String {
        val trimmed = value.trim()
        if (trimmed.isEmpty()) return "/live"
        return if (trimmed.startsWith("/")) trimmed else "/$trimmed"
    }

    private fun reconnectDelayMs(attempt: Int): Long {
        return when (attempt) {
            1 -> 500L
            2 -> 1_000L
            3 -> 2_000L
            4 -> 3_000L
            5 -> 5_000L
            6 -> 10_000L
            7 -> 15_000L
            8 -> 20_000L
            else -> 30_000L
        }
    }

    private fun formatDelay(delayMs: Long): String {
        return if (delayMs < 1000L) {
            "${delayMs}ms"
        } else {
            "${delayMs / 1000}s"
        }
    }

    companion object {
        private const val CONNECT_TIMEOUT_MS = 5000
        private const val READ_TIMEOUT_MS = 5000
        private const val MAX_QUEUE_SIZE = 192
        private const val MAX_RECONNECT_ATTEMPTS = 10
        private const val BUFFER_DROP_LOG_INTERVAL_MS = 3000L

        fun testConnection(config: IcecastConfig, onLog: (String) -> Unit = {}): String {
            onLog("[TEST]\nStarting connection test")
            val isValid = isValidConfig(config)
            logValidation(config, isValid, onLog)
            if (!isValid) {
                onLog("[RESULT]\nINVALID CONFIG")
                return "invalidConfig"
            }
            val socket = Socket()
            return try {
                val address = resolveHost(config.host, onLog)
                onLog("[SOCKET]\nConnecting to ${address.hostAddress}:${config.port}\nConnect timeout: $CONNECT_TIMEOUT_MS ms\nRead timeout: $READ_TIMEOUT_MS ms")
                socket.connect(InetSocketAddress(address, config.port), CONNECT_TIMEOUT_MS)
                socket.soTimeout = READ_TIMEOUT_MS
                onLog("[SOCKET]\nSuccess\nSocket connected")
                val client = IcecastClient(config, onStatus = {}, onLog = onLog)
                client.performHandshake(socket)
                onLog("[RESULT]\nSUCCESS")
                "live"
            } catch (_: AuthenticationFailedException) {
                onLog("[RESULT]\nAUTH FAILED")
                "authenticationFailed"
            } catch (_: UnsupportedCodecException) {
                onLog("[RESULT]\nUNSUPPORTED CODEC")
                "unsupportedCodec"
            } catch (_: ProtocolRejectedException) {
                onLog("[RESULT]\nPROTOCOL REJECTED")
                "protocolRejected"
            } catch (timeout: SocketTimeoutException) {
                onLog("[RESULT]\nTIMEOUT\n${timeout.message.orEmpty()}")
                "timeout"
            } catch (error: IOException) {
                onLog("[RESULT]\nSERVER UNREACHABLE\n${error.message.orEmpty()}")
                "serverUnreachable"
            } catch (error: Exception) {
                onLog("[RESULT]\nUNKNOWN ERROR\n${error.message.orEmpty()}")
                "unknownError"
            } finally {
                runCatching { socket.close() }
            }
        }

        private fun logValidation(config: IcecastConfig, isValid: Boolean, onLog: (String) -> Unit) {
            onLog(
                "[VALIDATION]\n" +
                    "host=${config.host}\n" +
                    "port=${config.port}\n" +
                    "mount=${config.mountPoint}\n" +
                    "username=${config.username}\n" +
                    "result=${if (isValid) "valid" else "invalid"}"
            )
        }

        private fun resolveHost(host: String, onLog: (String) -> Unit): InetAddress {
            onLog("[DNS]\nResolving $host")
            return try {
                val address = InetAddress.getByName(host)
                onLog("[DNS]\nSuccess\n${address.hostAddress}")
                address
            } catch (error: IOException) {
                onLog("[DNS]\nFailed\n${error.message.orEmpty()}")
                throw error
            }
        }

        private fun isValidConfig(config: IcecastConfig): Boolean {
            val validBitrate = config.bitrateKbps in listOf(32, 64, 96, 128)
            val hasCore = config.host.isNotBlank() &&
                config.port in 1..65535 &&
                config.password.isNotBlank() &&
                validBitrate
            val hasIcecastFields = config.serverType == BroadcastService.SERVER_TYPE_SHOUTCAST ||
                (config.username.isNotBlank() && config.mountPoint.startsWith("/"))
            return hasCore && hasIcecastFields
        }
    }
}

class AuthenticationFailedException : IOException()
class ProtocolRejectedException(message: String) : IOException(message)
class UnsupportedCodecException(message: String) : IOException(message)
