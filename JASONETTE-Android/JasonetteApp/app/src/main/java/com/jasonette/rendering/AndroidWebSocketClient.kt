package com.jasonette.rendering

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Response
import okhttp3.WebSocket
import okhttp3.WebSocketListener
import okio.ByteString
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicLong
import java.util.concurrent.atomic.AtomicReference

class AndroidWebSocketClient private constructor(
    private val scope: CoroutineScope,
    private val client: OkHttpClient,
    private val ownsClient: Boolean
) : ActionDispatcher.WebSocketClient {
    constructor(scope: CoroutineScope) : this(scope, OkHttpClient(), ownsClient = true)
    constructor(scope: CoroutineScope, client: OkHttpClient) : this(scope, client, ownsClient = false)

    private val socket = AtomicReference<WebSocket?>(null)
    private val generation = AtomicLong(0)
    private val lifecycleLock = Any()

    override suspend fun open(url: String, events: ActionDispatcher.WebSocketEvents) {
        val listenerGeneration = synchronized(lifecycleLock) {
            generation.incrementAndGet().also { socket.getAndSet(null)?.cancel() }
        }
        val closeNotified = AtomicBoolean(false)
        val request = Request.Builder().url(url).build()
        val newSocket = client.newWebSocket(request, object : WebSocketListener() {
            override fun onOpen(webSocket: WebSocket, response: Response) {
                if (!isCurrent(listenerGeneration, webSocket)) return
                launchEvent { events.onOpen() }
            }

            override fun onMessage(webSocket: WebSocket, text: String) {
                if (!isCurrent(listenerGeneration, webSocket)) return
                launchEvent { events.onMessage(text, "string") }
            }

            override fun onMessage(webSocket: WebSocket, bytes: ByteString) {
                if (!isCurrent(listenerGeneration, webSocket)) return
                launchEvent { events.onMessage(bytes.hex(), "bytes") }
            }

            override fun onClosing(webSocket: WebSocket, code: Int, reason: String) {
                if (!isCurrent(listenerGeneration, webSocket)) return
                webSocket.close(NORMAL_CLOSURE_STATUS, reason)
                notifyClose(events, listenerGeneration, webSocket, closeNotified)
            }

            override fun onClosed(webSocket: WebSocket, code: Int, reason: String) {
                notifyClose(events, listenerGeneration, webSocket, closeNotified)
            }

            override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
                if (!isCurrent(listenerGeneration, webSocket)) return
                launchEvent { events.onError(t.message ?: "WebSocket failed") }
            }
        })
        val shouldKeep = synchronized(lifecycleLock) {
            if (generation.get() == listenerGeneration) {
                socket.set(newSocket)
                true
            } else {
                false
            }
        }
        if (!shouldKeep) newSocket.cancel()
    }

    override suspend fun send(message: String) {
        socket.get()?.send(message)
    }

    override suspend fun close() {
        socket.get()?.close(NORMAL_CLOSURE_STATUS, "Goodbye!")
    }

    fun release() {
        synchronized(lifecycleLock) {
            generation.incrementAndGet()
            socket.getAndSet(null)?.cancel()
        }
        if (ownsClient) {
            client.dispatcher.executorService.shutdown()
            client.connectionPool.evictAll()
        }
    }

    private fun notifyClose(
        events: ActionDispatcher.WebSocketEvents,
        listenerGeneration: Long,
        webSocket: WebSocket,
        closeNotified: AtomicBoolean
    ) {
        if (isCurrent(listenerGeneration, webSocket) && closeNotified.compareAndSet(false, true)) {
            launchEvent { events.onClose() }
        }
    }

    private fun isCurrent(listenerGeneration: Long, webSocket: WebSocket): Boolean =
        generation.get() == listenerGeneration && socket.get() === webSocket

    private fun launchEvent(block: suspend () -> Unit) {
        scope.launch { runCatching { block() } }
    }

    private companion object {
        const val NORMAL_CLOSURE_STATUS = 1000
    }
}
