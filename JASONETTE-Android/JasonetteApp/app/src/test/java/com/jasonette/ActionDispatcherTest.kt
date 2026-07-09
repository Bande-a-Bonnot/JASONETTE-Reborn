package com.jasonette

import com.jasonette.core.JasonAction
import com.jasonette.core.JasonHref
import com.jasonette.core.StateManager
import com.jasonette.rendering.ActionDispatcher
import com.jasonette.rendering.JasonTimerScheduler
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.runTest
import kotlinx.serialization.decodeFromString
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import org.junit.Assert.*
import org.junit.Test

class ActionDispatcherTest {
    private class FakeTimerScheduler : JasonTimerScheduler {
        data class Scheduled(
            val name: String,
            val intervalMillis: Long,
            val repeats: Boolean,
            val action: suspend () -> Unit
        )

        val scheduled = mutableMapOf<String, Scheduled>()
        val stopped = mutableListOf<String?>()

        override fun start(name: String, intervalMillis: Long, repeats: Boolean, action: suspend () -> Unit) {
            scheduled[name] = Scheduled(name, intervalMillis, repeats, action)
        }

        override fun stop(name: String?) {
            stopped.add(name)
            if (name == null) scheduled.clear() else scheduled.remove(name)
        }

        suspend fun fire(name: String) {
            scheduled[name]?.action?.invoke()
        }
    }

    private class FakeWebSocketClient : ActionDispatcher.WebSocketClient {
        var openedUrl: String? = null
        var events: ActionDispatcher.WebSocketEvents? = null
        val sent = mutableListOf<String>()
        var closeCount = 0

        override suspend fun open(url: String, events: ActionDispatcher.WebSocketEvents) {
            openedUrl = url
            this.events = events
        }

        override suspend fun send(message: String) {
            sent.add(message)
        }

        override suspend fun close() {
            closeCount++
        }
    }

    private fun createDispatcher(): Pair<StateManager, ActionDispatcher> {
        val sm = StateManager(context = null)
        return sm to ActionDispatcher(sm)
    }

    private fun makeAction(
        type: String,
        options: Map<String, String>? = null,
        success: JasonAction? = null,
        error: JasonAction? = null
    ): JasonAction {
        val optionsJson = options?.let {
            JsonObject(it.mapValues { (_, v) -> JsonPrimitive(v) })
        }
        return JasonAction(type = type, options = optionsJson, success = success, error = error)
    }

    @Test
    fun testSetUpdatesState() = runTest {
        val (sm, dispatcher) = createDispatcher()
        val action = makeAction("\$set", mapOf("name" to "Alice", "city" to "Paris"))

        dispatcher.execute(action)

        assertEquals("Alice", sm.local["name"])
        assertEquals("Paris", sm.local["city"])
    }

    @Test
    fun testFlushResetsCacheWithoutClearingLocalStateAndContinuesSuccessChain() = runTest {
        val (sm, dispatcher) = createDispatcher()
        sm.set(mapOf("name" to "Ada", "count" to 1))

        dispatcher.execute(
            JasonAction(
                type = "\$flush",
                success = JasonAction(
                    type = "\$set",
                    options = JsonObject(mapOf("flushed" to JsonPrimitive("{{\$get.name}}")))
                )
            )
        )

        assertEquals("Ada", sm.local["name"])
        assertEquals(1, sm.local["count"])
        assertEquals("Ada", sm.local["flushed"])
    }

    @Test
    fun testCacheSetWithNullContextIsNoOp() = runTest {
        val (sm, dispatcher) = createDispatcher()
        val action = makeAction("\$cache.set", mapOf("key" to "value"))

        dispatcher.execute(action)

        // cache is no-op with null context
        assertTrue(sm.cacheGet().isEmpty())
    }

    @Test
    fun testCacheResetWithNullContextIsNoOp() = runTest {
        val (_, dispatcher) = createDispatcher()
        val action = makeAction("\$cache.reset")

        // Should not throw
        dispatcher.execute(action)
    }

    @Test
    fun testRenderCallsRegisteredHandler() = runTest {
        val (_, dispatcher) = createDispatcher()
        var renderCount = 0
        dispatcher.setRenderHandler { _, _, _ -> renderCount++ }
        val action = makeAction("\$render")

        dispatcher.execute(action)

        assertEquals(1, renderCount)
    }

    @Test
    fun testRenderPassesTemplatedTemplateNameAndDataToHandler() = runTest {
        val (sm, dispatcher) = createDispatcher()
        sm.set(mapOf("name" to "Ada"))
        var templateName: String? = null
        var renderData: Any? = null
        dispatcher.setRenderHandler { template, data, hasData ->
            templateName = template
            renderData = data
            assertTrue(hasData)
        }

        dispatcher.execute(
            JasonAction(
                type = "\$render",
                options = JsonObject(
                    mapOf(
                        "template" to JsonPrimitive("detail"),
                        "data" to JsonObject(mapOf("message" to JsonPrimitive("Hello {{\$get.name}}")))
                    )
                )
            )
        )

        assertEquals("detail", templateName)
        assertEquals(mapOf("message" to "Hello Ada"), renderData)
    }

    @Test
    fun testReloadCallsRegisteredHandler() = runTest {
        val (_, dispatcher) = createDispatcher()
        var reloadCount = 0
        dispatcher.setReloadHandler { reloadCount++ }
        val action = makeAction("\$reload")

        dispatcher.execute(action)

        assertEquals(1, reloadCount)
    }

    @Test
    fun testTimerStartSchedulesTemplatedActionAndContinuesSuccessChain() = runTest {
        val sm = StateManager(context = null)
        val scheduler = FakeTimerScheduler()
        val dispatcher = ActionDispatcher(sm, timerScheduler = scheduler)
        sm.set(mapOf("timerName" to "stopwatch"))
        dispatcher.setActionResolver { name ->
            if (name == "tick") makeAction("\$set", mapOf("ticked" to "true")) else null
        }

        dispatcher.execute(
            JasonAction(
                type = "\$timer.start",
                options = JsonObject(
                    mapOf(
                        "name" to JsonPrimitive("{{\$get.timerName}}"),
                        "interval" to JsonPrimitive("1"),
                        "repeats" to JsonPrimitive("true"),
                        "action" to JsonObject(mapOf("trigger" to JsonPrimitive("tick")))
                    )
                ),
                success = makeAction("\$set", mapOf("started" to "true"))
            )
        )

        val scheduled = scheduler.scheduled["stopwatch"]
        assertEquals(1000L, scheduled?.intervalMillis)
        assertEquals(true, scheduled?.repeats)
        assertEquals("true", sm.local["started"])

        scheduler.fire("stopwatch")

        assertEquals("true", sm.local["ticked"])
    }

    @Test
    fun testTimerStartDefaultsToRepeatingTimerWhenRepeatsIsOmitted() = runTest {
        val sm = StateManager(context = null)
        val scheduler = FakeTimerScheduler()
        val dispatcher = ActionDispatcher(sm, timerScheduler = scheduler)

        dispatcher.execute(
            JasonAction(
                type = "\$timer.start",
                options = JsonObject(
                    mapOf(
                        "name" to JsonPrimitive("once"),
                        "interval" to JsonPrimitive("0.5"),
                        "action" to JsonObject(mapOf("type" to JsonPrimitive("\$set"), "options" to JsonObject(mapOf("done" to JsonPrimitive("true")))))
                    )
                )
            )
        )

        val scheduled = scheduler.scheduled["once"]
        assertEquals(500L, scheduled?.intervalMillis)
        assertEquals(true, scheduled?.repeats)
    }

    @Test
    fun testTimerStartWithRepeatsFalseSchedulesOneShotDelay() = runTest {
        val sm = StateManager(context = null)
        val scheduler = FakeTimerScheduler()
        val dispatcher = ActionDispatcher(sm, timerScheduler = scheduler)

        dispatcher.execute(
            JasonAction(
                type = "\$timer.start",
                options = JsonObject(
                    mapOf(
                        "name" to JsonPrimitive("once"),
                        "interval" to JsonPrimitive("0.5"),
                        "repeats" to JsonPrimitive(false),
                        "action" to JsonObject(mapOf("type" to JsonPrimitive("\$set"), "options" to JsonObject(mapOf("done" to JsonPrimitive("true")))))
                    )
                )
            )
        )

        val scheduled = scheduler.scheduled["once"]
        assertEquals(500L, scheduled?.intervalMillis)
        assertEquals(false, scheduled?.repeats)
    }

    @Test
    fun testTimerInvalidIntervalTriggersErrorChain() = runTest {
        val (sm, dispatcher) = createDispatcher()

        dispatcher.execute(
            JasonAction(
                type = "\$timer.start",
                options = JsonObject(
                    mapOf(
                        "name" to JsonPrimitive("bad"),
                        "interval" to JsonPrimitive("0"),
                        "action" to JsonObject(mapOf("type" to JsonPrimitive("\$set"), "options" to JsonObject(mapOf("done" to JsonPrimitive("true")))))
                    )
                ),
                error = makeAction("\$set", mapOf("timer_error" to "true"))
            )
        )

        assertEquals("true", sm.local["timer_error"])
    }

    @Test
    fun testTimerStopCancelsNamedOrAllTimersAndContinuesSuccessChain() = runTest {
        val sm = StateManager(context = null)
        val scheduler = FakeTimerScheduler()
        val dispatcher = ActionDispatcher(sm, timerScheduler = scheduler)

        dispatcher.execute(
            JasonAction(
                type = "\$timer.stop",
                options = JsonObject(mapOf("name" to JsonPrimitive("stopwatch"))),
                success = makeAction("\$set", mapOf("stopped" to "one"))
            )
        )
        dispatcher.execute(JasonAction(type = "\$timer.stop"))

        assertEquals(listOf("stopwatch", null), scheduler.stopped)
        assertEquals("one", sm.local["stopped"])
    }

    @Test
    fun testNetworkRequestBadUrlTriggersErrorChain() = runTest {
        val (sm, dispatcher) = createDispatcher()

        // The error action sets a flag in state so we can verify the error path ran
        val errorAction = makeAction("\$set", mapOf("error_caught" to "true"))
        val action = JasonAction(
            type = "\$network.request",
            options = JsonObject(mapOf("url" to JsonPrimitive("not-a-valid-url://bad"))),
            error = errorAction
        )

        dispatcher.execute(action)

        // The error chain should have fired, setting error_caught
        assertEquals("true", sm.local["error_caught"])
    }

    @Test
    fun testSetTemplatesOptionsFromLocalAndResponseContext() = runTest {
        val (sm, dispatcher) = createDispatcher()
        sm.set(
            mapOf(
                "name" to "Ada",
                "\$response" to mapOf("items" to listOf(mapOf("title" to "First")))
            )
        )

        dispatcher.execute(
            JasonAction(
                type = "\$set",
                options = JsonObject(
                    mapOf(
                        "message" to JsonPrimitive("Hello {{\$get.name}}"),
                        "title" to JsonPrimitive("{{\$response.items[0].title}}")
                    )
                )
            )
        )

        assertEquals("Hello Ada", sm.local["message"])
        assertEquals("First", sm.local["title"])
    }

    @Test
    fun testSetStoresTemplatedAndUntemplatedStructuredOptionValues() = runTest {
        val (sm, dispatcher) = createDispatcher()
        sm.set(
            mapOf(
                "\$response" to mapOf(
                    "items" to listOf(mapOf("name" to "Ada")),
                    "meta" to mapOf("ok" to true)
                )
            )
        )

        dispatcher.execute(
            JasonAction(
                type = "\$set",
                options = JsonObject(
                    mapOf(
                        "items" to JsonPrimitive("{{\$response.items}}"),
                        "meta" to JsonPrimitive("{{\$response.meta}}"),
                        "plainString" to JsonPrimitive("hello"),
                        "number" to JsonPrimitive(42),
                        "enabled" to JsonPrimitive(true),
                        "missing" to JsonNull
                    )
                )
            )
        )

        @Suppress("UNCHECKED_CAST")
        val items = sm.local["items"] as List<Map<String, Any?>>
        assertEquals("Ada", items.first()["name"])
        assertEquals(mapOf("ok" to true), sm.local["meta"])
        assertEquals("hello", sm.local["plainString"])
        assertEquals(42, sm.local["number"])
        assertEquals(true, sm.local["enabled"])
        assertNull(sm.local["missing"])
    }

    @Test
    fun testCacheSetTemplatesOptionsWithoutCrashingWhenCacheUnavailable() = runTest {
        val (sm, dispatcher) = createDispatcher()
        sm.set(mapOf("cacheKey" to "greeting", "cacheValue" to "hello"))

        dispatcher.execute(
            JasonAction(
                type = "\$cache.set",
                options = JsonObject(mapOf("{{\$get.cacheKey}}" to JsonPrimitive("{{\$get.cacheValue}}")))
            )
        )

        assertTrue(sm.cacheGet().isEmpty())
    }

    @Test
    fun testGlobalSetStoresPayloadAndExposesGlobalContext() = runTest {
        val sm = StateManager(context = null)
        val dispatcher = ActionDispatcher(sm)

        dispatcher.execute(
            JasonAction(
                type = "\$global.set",
                options = JsonObject(
                    mapOf(
                        "token" to JsonPrimitive("abc"),
                        "profile" to JsonObject(mapOf("name" to JsonPrimitive("Ada")))
                    )
                ),
                success = makeAction("\$set", mapOf("saved" to "{{\$global.profile.name}}"))
            )
        )

        assertEquals("Ada", sm.local["saved"])
        assertEquals("abc", sm.globalGet()["token"])
        assertEquals(mapOf("token" to "abc", "profile" to mapOf("name" to "Ada")), sm.local["\$jason"])
    }

    @Test
    fun testGlobalResetRemovesOnlyListedItemsAndReturnsUpdatedPayload() = runTest {
        val sm = StateManager(context = null)
        sm.globalSet(mapOf("token" to "abc", "theme" to "dark"))
        val dispatcher = ActionDispatcher(sm)

        dispatcher.execute(
            JasonAction(
                type = "\$global.reset",
                options = JsonObject(mapOf("items" to JsonArray(listOf(JsonPrimitive("token"))))),
                success = makeAction("\$set", mapOf("remaining_theme" to "{{\$jason.theme}}"))
            )
        )

        assertFalse(sm.globalGet().containsKey("token"))
        assertEquals("dark", sm.globalGet()["theme"])
        assertEquals("dark", sm.local["remaining_theme"])
        assertEquals(mapOf("theme" to "dark"), sm.local["\$jason"])
    }

    @Test
    fun testGlobalMissingOrMalformedOptionsDoNotRunContinuations() = runTest {
        val sm = StateManager(context = null)
        val dispatcher = ActionDispatcher(sm)

        dispatcher.execute(
            JasonAction(
                type = "\$global.set",
                success = makeAction("\$set", mapOf("global_set_success" to "true")),
                error = makeAction("\$set", mapOf("global_set_error" to "true"))
            )
        )
        dispatcher.execute(
            JasonAction(
                type = "\$global.reset",
                options = JsonObject(mapOf("items" to JsonPrimitive("token"))),
                success = makeAction("\$set", mapOf("global_reset_success" to "true")),
                error = makeAction("\$set", mapOf("global_reset_error" to "true"))
            )
        )

        assertNull(sm.local["global_set_success"])
        assertNull(sm.local["global_set_error"])
        assertNull(sm.local["global_reset_success"])
        assertNull(sm.local["global_reset_error"])
    }

    @Test
    fun testSessionSetDecoratesNetworkRequestAndResetRemovesSession() = runTest {
        val sm = StateManager(context = null)
        val observedUrls = mutableListOf<String>()
        val observedOptions = mutableListOf<JsonObject?>()
        val dispatcher = ActionDispatcher(sm) { url, options ->
            observedUrls.add(url)
            observedOptions.add(options)
            "{}"
        }

        dispatcher.execute(
            JasonAction(
                type = "\$session.set",
                options = JsonObject(
                    mapOf(
                        "domain" to JsonPrimitive("api.example.com"),
                        "header" to JsonObject(mapOf("Authorization" to JsonPrimitive("Bearer abc"))),
                        "body" to JsonObject(mapOf("api_key" to JsonPrimitive("secret")))
                    )
                )
            )
        )
        dispatcher.execute(
            JasonAction(
                type = "\$network.request",
                options = JsonObject(mapOf("url" to JsonPrimitive("https://api.example.com/items?existing=1")))
            )
        )
        dispatcher.execute(
            JasonAction(
                type = "\$session.reset",
                options = JsonObject(mapOf("url" to JsonPrimitive("https://api.example.com/logout")))
            )
        )
        dispatcher.execute(
            JasonAction(
                type = "\$network.request",
                options = JsonObject(mapOf("url" to JsonPrimitive("https://api.example.com/items")))
            )
        )

        assertEquals("https://api.example.com/items?existing=1&api_key=secret", observedUrls[0])
        val header = observedOptions[0]?.get("header") as JsonObject
        assertEquals("Bearer abc", (header["Authorization"] as JsonPrimitive).content)
        assertEquals("https://api.example.com/items", observedUrls[1])
        assertNull(observedOptions[1]?.get("header"))
    }

    @Test
    fun testSessionSetMergesNonGetBodyDataAndAuthoredHeadersWin() = runTest {
        val sm = StateManager(context = null)
        var observedOptions: JsonObject? = null
        val dispatcher = ActionDispatcher(sm) { _, options ->
            observedOptions = options
            "{}"
        }

        dispatcher.execute(
            JasonAction(
                type = "\$session.set",
                options = JsonObject(
                    mapOf(
                        "url" to JsonPrimitive("https://api.example.com/login"),
                        "header" to JsonObject(
                            mapOf(
                                "Authorization" to JsonPrimitive("Bearer session"),
                                "X-Session" to JsonPrimitive("yes")
                            )
                        ),
                        "body" to JsonObject(
                            mapOf(
                                "api_key" to JsonPrimitive("secret"),
                                "locale" to JsonPrimitive("en")
                            )
                        )
                    )
                )
            )
        )
        dispatcher.execute(
            JasonAction(
                type = "\$network.request",
                options = JsonObject(
                    mapOf(
                        "url" to JsonPrimitive("https://api.example.com/items"),
                        "method" to JsonPrimitive("POST"),
                        "header" to JsonObject(mapOf("Authorization" to JsonPrimitive("Bearer authored"))),
                        "data" to JsonObject(mapOf("locale" to JsonPrimitive("fr"), "page" to JsonPrimitive("1")))
                    )
                )
            )
        )

        val header = observedOptions?.get("header") as JsonObject
        val data = observedOptions?.get("data") as JsonObject
        assertEquals("Bearer authored", (header["Authorization"] as JsonPrimitive).content)
        assertEquals("yes", (header["X-Session"] as JsonPrimitive).content)
        assertEquals("secret", (data["api_key"] as JsonPrimitive).content)
        assertEquals("fr", (data["locale"] as JsonPrimitive).content)
        assertEquals("1", (data["page"] as JsonPrimitive).content)
    }

    @Test
    fun testSessionSetWithoutDomainDoesNotRunContinuations() = runTest {
        val sm = StateManager(context = null)
        val dispatcher = ActionDispatcher(sm)

        dispatcher.execute(
            JasonAction(
                type = "\$session.set",
                options = JsonObject(mapOf("header" to JsonObject(mapOf("Authorization" to JsonPrimitive("Bearer abc"))))),
                success = makeAction("\$set", mapOf("session_success" to "true")),
                error = makeAction("\$set", mapOf("session_error" to "true"))
            )
        )

        assertNull(sm.local["session_success"])
        assertNull(sm.local["session_error"])
    }

    @Test
    fun testNetworkRequestTemplatesUrlBeforeExecution() = runTest {
        val sm = StateManager(context = null)
        sm.set(mapOf("postId" to "1"))
        var requestedUrl: String? = null
        val dispatcher = ActionDispatcher(sm) { url, _ ->
            requestedUrl = url
            "[]"
        }

        dispatcher.execute(
            JasonAction(
                type = "\$network.request",
                options = JsonObject(mapOf("url" to JsonPrimitive("https://example.com/comments?postId={{\$get.postId}}")))
            )
        )

        assertEquals("https://example.com/comments?postId=1", requestedUrl)
    }

    @Test
    fun testNestedActionOptionsAreTemplatedBeforeHandlerExecution() = runTest {
        val sm = StateManager(context = null)
        sm.set(mapOf("name" to "Ada", "tag" to "math"))
        var observedOptions: JsonObject? = null
        val dispatcher = ActionDispatcher(sm) { _, options ->
            observedOptions = options
            "{}"
        }

        dispatcher.execute(
            JasonAction(
                type = "\$network.request",
                options = JsonObject(
                    mapOf(
                        "url" to JsonPrimitive("https://example.com/api"),
                        "body" to JsonObject(
                            mapOf(
                                "user" to JsonPrimitive("{{\$get.name}}"),
                                "{{\$get.tag}}_user" to JsonPrimitive("{{\$get.name}}"),
                                "tags" to JsonArray(listOf(JsonPrimitive("{{\$get.tag}}")))
                            )
                        )
                    )
                )
            )
        )

        val body = observedOptions?.get("body") as JsonObject
        assertEquals("Ada", (body["user"] as JsonPrimitive).content)
        assertEquals("Ada", (body["math_user"] as JsonPrimitive).content)
        val tags = body["tags"] as JsonArray
        assertEquals("math", (tags.first() as JsonPrimitive).content)
    }

    @Test
    fun testWholeExpressionObjectAndArrayOptionsSurviveWithoutStringification() = runTest {
        val sm = StateManager(context = null)
        sm.set(
            mapOf(
                "\$response" to mapOf(
                    "items" to listOf(mapOf("name" to "Ada")),
                    "meta" to mapOf("ok" to true)
                )
            )
        )
        var observedOptions: JsonObject? = null
        val dispatcher = ActionDispatcher(sm) { _, options ->
            observedOptions = options
            "{}"
        }

        dispatcher.execute(
            JasonAction(
                type = "\$network.request",
                options = JsonObject(
                    mapOf(
                        "url" to JsonPrimitive("https://example.com/api"),
                        "body" to JsonObject(
                            mapOf(
                                "items" to JsonPrimitive("{{\$response.items}}"),
                                "meta" to JsonPrimitive("{{\$response.meta}}")
                            )
                        )
                    )
                )
            )
        )

        val body = observedOptions?.get("body") as JsonObject
        val items = body["items"] as JsonArray
        assertEquals("Ada", ((items.first() as JsonObject)["name"] as JsonPrimitive).content)
        val meta = body["meta"] as JsonObject
        assertEquals(JsonPrimitive(true), meta["ok"])
    }

    @Test
    fun testTemplatingPreservesUntemplatedNestedPrimitiveOptions() = runTest {
        val sm = StateManager(context = null)
        var observedOptions: JsonObject? = null
        val dispatcher = ActionDispatcher(sm) { _, options ->
            observedOptions = options
            "{}"
        }

        dispatcher.execute(
            JasonAction(
                type = "\$network.request",
                options = JsonObject(
                    mapOf(
                        "url" to JsonPrimitive("https://example.com/api"),
                        "body" to JsonObject(
                            mapOf(
                                "count" to JsonPrimitive(42),
                                "enabled" to JsonPrimitive(true),
                                "missing" to JsonNull
                            )
                        )
                    )
                )
            )
        )

        val body = observedOptions?.get("body") as JsonObject
        assertEquals(JsonPrimitive(42), body["count"])
        assertEquals(JsonPrimitive(true), body["enabled"])
        assertSame(JsonNull, body["missing"])
    }

    @Test
    fun testTemplatedUnsafeHrefStillBlockedAfterInterpolation() = runTest {
        val (sm, dispatcher) = createDispatcher()
        sm.set(mapOf("scheme" to "javascript"))
        var navigated = false
        dispatcher.setNavigationHandler { navigated = true }

        dispatcher.execute(
            JasonAction(
                type = "\$href",
                options = JsonObject(mapOf("url" to JsonPrimitive("{{\$get.scheme}}:alert(1)")))
            )
        )

        assertFalse(navigated)
    }

    @Test
    fun testNetworkRequestStoresStructuredResponsePayload() = runTest {
        val sm = StateManager(context = null)
        val dispatcher = ActionDispatcher(sm) { _, _ -> "{\"items\":[{\"name\":\"Ada\"}],\"ok\":true}" }
        val action = JasonAction(
            type = "\$network.request",
            options = JsonObject(mapOf("url" to JsonPrimitive("https://example.com/api.json")))
        )

        dispatcher.execute(action)

        @Suppress("UNCHECKED_CAST")
        val response = sm.local["\$response"] as Map<String, Any?>
        assertEquals(true, response["ok"])
        @Suppress("UNCHECKED_CAST")
        val items = response["items"] as List<Map<String, Any?>>
        assertEquals("Ada", items.first()["name"])
    }

    @Test
    fun testNetworkUploadSignsPutsDataAndStoresFilenamePayload() = runTest {
        val sm = StateManager(context = null)
        var signerUrl: String? = null
        var uploadedUrl: String? = null
        var uploadedBytes: ByteArray? = null
        var uploadedContentType: String? = null
        val dispatcher = ActionDispatcher(
            sm,
            uploadClient = { url, bytes, contentType ->
                uploadedUrl = url
                uploadedBytes = bytes
                uploadedContentType = contentType
                ""
            },
            networkClient = { url, _ ->
                signerUrl = url
                "{\"${'$'}jason\":\"https://s3.example.com/signed-upload\"}"
            }
        )

        dispatcher.execute(
            JasonAction(
                type = "${'$'}network.upload",
                options = JsonObject(
                    mapOf(
                        "type" to JsonPrimitive("s3"),
                        "bucket" to JsonPrimitive("photos"),
                        "path" to JsonPrimitive("avatars"),
                        "data" to JsonPrimitive("data:image/png;base64,aGVs\nbG8="),
                        "content_type" to JsonPrimitive("image/png"),
                        "sign_url" to JsonPrimitive("https://sign.example.com/sign")
                    )
                ),
                success = makeAction("${'$'}set", mapOf("uploaded" to "{{${'$'}jason.filename}}"))
            )
        )

        val filename = (sm.local["${'$'}jason"] as Map<*, *>)["filename"] as String
        assertTrue(filename.matches(Regex("avatars/[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}")))
        assertEquals(mapOf("filename" to filename, "file_name" to filename), sm.local["${'$'}jason"])
        assertEquals(filename, sm.local["uploaded"])
        assertTrue(signerUrl?.startsWith("https://sign.example.com/sign?") == true)
        assertTrue(signerUrl?.contains("bucket=photos") == true)
        assertTrue(signerUrl?.contains("path=${filename.replace("/", "%2F")}") == true)
        assertTrue(signerUrl?.contains("content-type=image%2Fpng") == true)
        assertEquals("https://s3.example.com/signed-upload", uploadedUrl)
        assertEquals("hello", uploadedBytes?.decodeToString())
        assertEquals("image/png", uploadedContentType)
    }

    @Test
    fun testNetworkUploadTemplatesOptionsAndFallsBackToJasonContentType() = runTest {
        val sm = StateManager(context = null)
        sm.set(mapOf("folder" to "captures", "${'$'}jason" to mapOf("data" to "aGk=", "content_type" to "image/jpeg")))
        var uploadedContentType: String? = null
        var signerUrl: String? = null
        val dispatcher = ActionDispatcher(
            sm,
            uploadClient = { _, _, contentType -> uploadedContentType = contentType; "" },
            networkClient = { url, _ ->
                signerUrl = url
                "{\"${'$'}jason\":\"https://s3.example.com/upload\"}"
            }
        )

        dispatcher.execute(
            JasonAction(
                type = "${'$'}network.upload",
                options = JsonObject(
                    mapOf(
                        "bucket" to JsonPrimitive("photos"),
                        "path" to JsonPrimitive("{{${'$'}get.folder}}"),
                        "data" to JsonPrimitive("{{${'$'}jason.data}}"),
                        "sign_url" to JsonPrimitive("https://sign.example.com/sign")
                    )
                )
            )
        )

        assertEquals("image/jpeg", uploadedContentType)
        assertTrue(signerUrl?.contains("path=captures%2F") == true)
        assertTrue(signerUrl?.contains("content-type=image%2Fjpeg") == true)
    }

    @Test
    fun testNetworkUploadInvalidBase64RoutesErrorBranch() = runTest {
        val sm = StateManager(context = null)
        val dispatcher = ActionDispatcher(sm)

        dispatcher.execute(
            JasonAction(
                type = "${'$'}network.upload",
                options = JsonObject(
                    mapOf(
                        "bucket" to JsonPrimitive("photos"),
                        "data" to JsonPrimitive("not base64!"),
                        "sign_url" to JsonPrimitive("https://sign.example.com/sign")
                    )
                ),
                error = makeAction("${'$'}set", mapOf("upload_failed" to "true"))
            )
        )

        assertEquals("true", sm.local["upload_failed"])
    }

    @Test
    fun testNetworkUploadSignerMissingJasonRoutesErrorBranch() = runTest {
        val sm = StateManager(context = null)
        val dispatcher = ActionDispatcher(
            sm,
            uploadClient = { _, _, _ -> fail("Upload should not run without signed URL"); "" },
            networkClient = { _, _ -> "{\"url\":\"https://example.com/upload\"}" }
        )

        dispatcher.execute(
            JasonAction(
                type = "${'$'}network.upload",
                options = JsonObject(
                    mapOf(
                        "bucket" to JsonPrimitive("photos"),
                        "data" to JsonPrimitive("aGk="),
                        "content_type" to JsonPrimitive("image/png"),
                        "sign_url" to JsonPrimitive("https://sign.example.com/sign")
                    )
                ),
                error = makeAction("${'$'}set", mapOf("sign_failed" to "true"))
            )
        )

        assertEquals("true", sm.local["sign_failed"])
    }

    @Test
    fun testNetworkUploadPutFailureRoutesErrorBranch() = runTest {
        val sm = StateManager(context = null)
        val dispatcher = ActionDispatcher(
            sm,
            uploadClient = { _, _, _ -> throw ActionDispatcher.ActionException("Upload failed") },
            networkClient = { _, _ -> "{\"${'$'}jason\":\"https://s3.example.com/upload\"}" }
        )

        dispatcher.execute(
            JasonAction(
                type = "${'$'}network.upload",
                options = JsonObject(
                    mapOf(
                        "bucket" to JsonPrimitive("photos"),
                        "data" to JsonPrimitive("aGk="),
                        "content_type" to JsonPrimitive("image/png"),
                        "sign_url" to JsonPrimitive("https://sign.example.com/sign")
                    )
                ),
                error = makeAction("${'$'}set", mapOf("put_failed" to "true"))
            )
        )

        assertEquals("true", sm.local["put_failed"])
    }

    @Test
    fun testHrefTemplatesUrlBeforeResolvingNavigation() = runTest {
        val (sm, dispatcher) = createDispatcher()
        sm.set(mapOf("next" to "detail"))
        var navigated: JasonHref? = null
        dispatcher.setBaseUrl("https://example.com/path/index.json")
        dispatcher.setNavigationHandler { navigated = it }

        dispatcher.execute(
            JasonAction(
                type = "\$href",
                options = JsonObject(mapOf("url" to JsonPrimitive("{{\$get.next}}.json"), "transition" to JsonPrimitive("push")))
            )
        )

        assertEquals("https://example.com/path/detail.json", navigated?.url)
        assertEquals("push", navigated?.transition)
    }

    @Test
    fun testHrefResolvesRelativeUrlAndDispatchesNavigation() = runTest {
        val (_, dispatcher) = createDispatcher()
        var navigated: JasonHref? = null
        dispatcher.setBaseUrl("https://example.com/path/index.json")
        dispatcher.setNavigationHandler { navigated = it }

        dispatcher.execute(
            JasonAction(
                type = "\$href",
                options = JsonObject(mapOf("url" to JsonPrimitive("next.json"), "transition" to JsonPrimitive("push")))
            )
        )

        assertEquals("https://example.com/path/next.json", navigated?.url)
        assertEquals("push", navigated?.transition)
    }

    @Test
    fun testHrefBlocksUnsafeSchemes() = runTest {
        val (_, dispatcher) = createDispatcher()
        var navigated = false
        dispatcher.setNavigationHandler { navigated = true }

        dispatcher.execute(
            JasonAction(
                type = "\$href",
                options = JsonObject(mapOf("url" to JsonPrimitive("javascript:alert(1)")))
            )
        )

        assertFalse(navigated)
    }

    @Test
    fun testBackAndCloseActionsCallNavigationHandlersAndContinueSuccessChain() = runTest {
        val (sm, dispatcher) = createDispatcher()
        var backCount = 0
        var closeCount = 0
        dispatcher.setBackHandler { backCount++ }
        dispatcher.setCloseHandler { closeCount++ }

        dispatcher.execute(
            JasonAction(
                type = "\$back",
                success = makeAction("\$set", mapOf("backed" to "true"))
            )
        )
        dispatcher.execute(
            JasonAction(
                type = "\$close",
                success = makeAction("\$set", mapOf("closed" to "true"))
            )
        )

        assertEquals(1, backCount)
        assertEquals(1, closeCount)
        assertEquals("true", sm.local["backed"])
        assertEquals("true", sm.local["closed"])
    }

    @Test
    fun testCloseFallsBackToBackHandlerWhenNoCloseHandlerIsRegistered() = runTest {
        val (_, dispatcher) = createDispatcher()
        var backCount = 0
        dispatcher.setBackHandler { backCount++ }

        dispatcher.execute(JasonAction(type = "\$close"))

        assertEquals(1, backCount)
    }

    @Test
    fun testNamedTriggerResolvesHeadAction() = runTest {
        val (sm, dispatcher) = createDispatcher()
        dispatcher.setActionResolver { name ->
            if (name == "send") makeAction("\$set", mapOf("sent" to "true")) else null
        }

        dispatcher.execute(JasonAction(trigger = "send"))

        assertEquals("true", sm.local["sent"])
    }

    @Test
    fun testWebSocketOpenForwardsUrlAndContinuesSuccessBeforeEvents() = runTest {
        val sm = StateManager(context = null)
        val webSocket = FakeWebSocketClient()
        val dispatcher = ActionDispatcher(sm, webSocketClient = webSocket)
        dispatcher.setActionResolver { name ->
            if (name == "\$websocket.onopen") makeAction("\$set", mapOf("opened_event" to "true")) else null
        }

        dispatcher.execute(
            JasonAction(
                type = "\$websocket.open",
                options = JsonObject(mapOf("url" to JsonPrimitive("wss://example.com/socket"))),
                success = makeAction("\$set", mapOf("open_success" to "true"))
            )
        )

        assertEquals("wss://example.com/socket", webSocket.openedUrl)
        assertEquals("true", sm.local["open_success"])
        assertNull(sm.local["opened_event"])

        webSocket.events?.onOpen()

        assertEquals("true", sm.local["opened_event"])
    }

    @Test
    fun testWebSocketMessageAndErrorEventsExposeLegacyJasonPayloads() = runTest {
        val sm = StateManager(context = null)
        val webSocket = FakeWebSocketClient()
        val dispatcher = ActionDispatcher(sm, webSocketClient = webSocket)
        dispatcher.setActionResolver { name ->
            when (name) {
                "\$websocket.onmessage" -> makeAction(
                    "\$set",
                    mapOf(
                        "message" to "{{\$jason.message}}",
                        "message_type" to "{{\$jason.type}}"
                    )
                )
                "\$websocket.onerror" -> makeAction("\$set", mapOf("socket_error" to "{{\$jason.error}}"))
                else -> null
            }
        }

        dispatcher.execute(
            JasonAction(
                type = "\$websocket.open",
                options = JsonObject(mapOf("url" to JsonPrimitive("wss://example.com/socket")))
            )
        )

        webSocket.events?.onMessage("hello", "string")
        webSocket.events?.onError("boom")

        assertEquals("hello", sm.local["message"])
        assertEquals("string", sm.local["message_type"])
        assertEquals("boom", sm.local["socket_error"])
        assertFalse(sm.local.containsKey("\$jason"))
    }

    @Test
    fun testWebSocketSendAndCloseForwardAndContinueSuccessChains() = runTest {
        val sm = StateManager(context = null)
        val webSocket = FakeWebSocketClient()
        val dispatcher = ActionDispatcher(sm, webSocketClient = webSocket)
        dispatcher.setActionResolver { name ->
            if (name == "\$websocket.onclose") makeAction("\$set", mapOf("closed_event" to "true")) else null
        }

        dispatcher.execute(
            JasonAction(
                type = "\$websocket.open",
                options = JsonObject(mapOf("url" to JsonPrimitive("wss://example.com/socket")))
            )
        )
        dispatcher.execute(
            JasonAction(
                type = "\$websocket.send",
                options = JsonObject(mapOf("message" to JsonPrimitive("ping"))),
                success = makeAction("\$set", mapOf("send_success" to "true"))
            )
        )
        dispatcher.execute(
            JasonAction(
                type = "\$websocket.close",
                success = makeAction("\$set", mapOf("close_success" to "true"))
            )
        )

        assertEquals(listOf("ping"), webSocket.sent)
        assertEquals(1, webSocket.closeCount)
        assertEquals("true", sm.local["send_success"])
        assertEquals("true", sm.local["close_success"])

        webSocket.events?.onClose()

        assertEquals("true", sm.local["closed_event"])
    }

    @Test
    fun testWebSocketInvalidUrlTriggersErrorEventButStillContinuesSuccess() = runTest {
        val sm = StateManager(context = null)
        val webSocket = FakeWebSocketClient()
        val dispatcher = ActionDispatcher(sm, webSocketClient = webSocket)
        dispatcher.setActionResolver { name ->
            if (name == "\$websocket.onerror") makeAction("\$set", mapOf("error" to "{{\$jason.error}}")) else null
        }

        dispatcher.execute(
            JasonAction(
                type = "\$websocket.open",
                options = JsonObject(mapOf("url" to JsonPrimitive("https://example.com/not-websocket"))),
                success = makeAction("\$set", mapOf("success" to "true"))
            )
        )

        assertNull(webSocket.openedUrl)
        assertEquals("true", sm.local["success"])
        assertEquals("WebSocket URL scheme not allowed", sm.local["error"])
    }

    @Test
    fun testNestedWebSocketEventsAreQueuedUntilCurrentEventCompletes() = runTest {
        val sm = StateManager(context = null)
        val webSocket = FakeWebSocketClient()
        val dispatcher = ActionDispatcher(sm, webSocketClient = webSocket)
        dispatcher.setActionResolver { name ->
            when (name) {
                "\$websocket.onopen" -> JasonAction(
                    type = "\$websocket.open",
                    options = JsonObject(mapOf("url" to JsonPrimitive("https://example.com/not-websocket"))),
                    success = makeAction("\$set", mapOf("after_open" to "done"))
                )
                "\$websocket.onerror" -> makeAction(
                    "\$set",
                    mapOf(
                        "error" to "{{\$jason.error}}",
                        "error_after_open" to "{{\$get.after_open}}"
                    )
                )
                else -> null
            }
        }

        dispatcher.execute(
            JasonAction(
                type = "\$websocket.open",
                options = JsonObject(mapOf("url" to JsonPrimitive("wss://example.com/socket")))
            )
        )
        webSocket.events?.onOpen()

        assertEquals("done", sm.local["after_open"])
        assertEquals("WebSocket URL scheme not allowed", sm.local["error"])
        assertEquals("done", sm.local["error_after_open"])
    }

    @Test
    fun testFailingWebSocketEventDoesNotPoisonLaterEvents() = runTest {
        val sm = StateManager(context = null)
        val webSocket = FakeWebSocketClient()
        val dispatcher = ActionDispatcher(sm, webSocketClient = webSocket)
        dispatcher.setActionResolver { name ->
            when (name) {
                "\$websocket.onmessage" -> JasonAction(
                    type = "\$return.error",
                    options = JsonObject(mapOf("message" to JsonPrimitive("stop")))
                )
                "\$websocket.onclose" -> makeAction("\$set", mapOf("closed_after_failure" to "true"))
                else -> null
            }
        }

        dispatcher.execute(
            JasonAction(
                type = "\$websocket.open",
                options = JsonObject(mapOf("url" to JsonPrimitive("wss://example.com/socket")))
            )
        )

        webSocket.events?.onMessage("ignored", "string")
        webSocket.events?.onClose()

        assertEquals("true", sm.local["closed_after_failure"])
    }

    @Test
    fun testLambdaPassesOptionsAsJasonAndRestoresPreviousPayload() = runTest {
        val sm = StateManager(context = null)
        val dispatcher = ActionDispatcher(sm)
        sm.set(mapOf("\$jason" to mapOf("title" to "Original")))
        dispatcher.setActionResolver { name ->
            if (name == "banner") {
                makeAction("\$set", mapOf("seen" to "{{\$jason.title}}"))
            } else null
        }

        dispatcher.execute(
            JasonAction(
                type = "\$lambda",
                options = JsonObject(
                    mapOf(
                        "name" to JsonPrimitive("banner"),
                        "options" to JsonObject(mapOf("title" to JsonPrimitive("Trigger")))
                    )
                ),
                success = makeAction("\$set", mapOf("after" to "{{\$jason.title}}"))
            )
        )

        assertEquals("Trigger", sm.local["seen"])
        assertEquals("Original", sm.local["after"])
    }

    @Test
    fun testLambdaReturnSuccessFeedsCallerSuccessChain() = runTest {
        val sm = StateManager(context = null)
        val dispatcher = ActionDispatcher(sm)
        dispatcher.setActionResolver { name ->
            if (name == "lookup") {
                Json.decodeFromString<JasonAction>(
                    """
                    {
                      "type": "${'$'}return.success",
                      "options": {"title": "Returned"}
                    }
                    """.trimIndent()
                )
            } else null
        }

        dispatcher.execute(
            JasonAction(
                type = "\$lambda",
                options = JsonObject(mapOf("name" to JsonPrimitive("lookup"))),
                success = makeAction("\$set", mapOf("after" to "{{\$jason.title}}"))
            )
        )

        assertEquals("Returned", sm.local["after"])
    }

    @Test
    fun testLambdaReturnErrorFeedsCallerErrorChain() = runTest {
        val sm = StateManager(context = null)
        val dispatcher = ActionDispatcher(sm)
        dispatcher.setActionResolver { name ->
            if (name == "lookup") {
                Json.decodeFromString<JasonAction>(
                    """
                    {
                      "type": "${'$'}return.error",
                      "options": {"message": "Nope"}
                    }
                    """.trimIndent()
                )
            } else null
        }

        dispatcher.execute(
            JasonAction(
                type = "\$lambda",
                options = JsonObject(mapOf("name" to JsonPrimitive("lookup"))),
                error = makeAction("\$set", mapOf("error" to "{{\$jason.message}}"))
            )
        )

        assertEquals("Nope", sm.local["error"])
    }

    @Test
    fun testTriggerOptionsPassTemporarilyAsJason() = runTest {
        val sm = StateManager(context = null)
        val dispatcher = ActionDispatcher(sm)
        sm.set(mapOf("\$jason" to mapOf("title" to "Original")))
        dispatcher.setActionResolver { name ->
            if (name == "banner") makeAction("\$set", mapOf("seen" to "{{\$jason.title}}")) else null
        }

        dispatcher.execute(
            JasonAction(
                trigger = "banner",
                options = JsonObject(mapOf("title" to JsonPrimitive("Trigger"))),
                success = makeAction("\$set", mapOf("after" to "{{\$jason.title}}"))
            )
        )

        assertEquals("Trigger", sm.local["seen"])
        assertEquals("Original", sm.local["after"])
    }

    @Test
    fun testActionArraySuccessTemplatesEachActionAfterPreviousSideEffects() = runTest {
        val sm = StateManager(context = null)
        val dispatcher = ActionDispatcher(sm)
        val action = Json.decodeFromString<JasonAction>(
            """
            {
              "type": "${'$'}set",
              "options": {"first": "one"},
              "success": [
                {
                  "type": "${'$'}set",
                  "options": {"second": "{{${'$'}get.first}} two"}
                },
                {
                  "type": "${'$'}set",
                  "options": {"third": "{{${'$'}get.second}} three"}
                }
              ]
            }
            """.trimIndent()
        )

        dispatcher.execute(action)

        assertEquals("one", sm.local["first"])
        assertEquals("one two", sm.local["second"])
        assertEquals("one two three", sm.local["third"])
    }

    @Test
    fun testActionArraySuccessTemplatesConditionalBranchesBeforeDispatch() = runTest {
        val sm = StateManager(context = null)
        val dispatcher = ActionDispatcher(sm) { _, _ -> "{\"ok\":true,\"message\":\"Ready\"}" }
        val json = Json { ignoreUnknownKeys = true; isLenient = true }
        val action = json.decodeFromString<JasonAction>(
            """
            {
              "type": "${'$'}network.request",
              "options": {"url": "https://example.com/data.json"},
              "success": [
                {
                  "{{#if ${'$'}jason.ok}}": {
                    "type": "${'$'}set",
                    "options": {"message": "{{${'$'}jason.message}}"}
                  }
                },
                {
                  "{{#else}}": {
                    "type": "${'$'}set",
                    "options": {"fallback": "true"}
                  }
                }
              ]
            }
            """.trimIndent()
        )

        dispatcher.execute(action)

        assertEquals("Ready", sm.local["message"])
        assertNull(sm.local["fallback"])
    }

    @Test
    fun testActionArraySuccessRunsSplitElseBranchWhenConditionIsFalse() = runTest {
        val sm = StateManager(context = null)
        val dispatcher = ActionDispatcher(sm) { _, _ -> "{\"ok\":false}" }
        val json = Json { ignoreUnknownKeys = true; isLenient = true }
        val action = json.decodeFromString<JasonAction>(
            """
            {
              "type": "${'$'}network.request",
              "options": {"url": "https://example.com/data.json"},
              "success": [
                {
                  "{{#if ${'$'}jason.ok}}": {
                    "type": "${'$'}set",
                    "options": {"message": "Ready"}
                  }
                },
                {
                  "{{#else}}": {
                    "type": "${'$'}set",
                    "options": {"fallback": "true"}
                  }
                }
              ]
            }
            """.trimIndent()
        )

        dispatcher.execute(action)

        assertNull(sm.local["message"])
        assertEquals("true", sm.local["fallback"])
    }

    @Test
    fun testLambdaConditionalOptionsCanRenderFallbackAction() = runTest {
        val sm = StateManager(context = null)
        val dispatcher = ActionDispatcher(sm)
        sm.set(mapOf("\$jason" to mapOf("ok" to false)))
        val json = Json { ignoreUnknownKeys = true; isLenient = true }
        val action = json.decodeFromString<JasonAction>(
            """
            {
              "type": "${'$'}lambda",
              "options": [
                {
                  "{{#if ${'$'}jason.ok}}": {
                    "name": "missing"
                  }
                },
                {
                  "{{#else}}": {
                    "type": "${'$'}set",
                    "options": {"fallback": "true"}
                  }
                }
              ]
            }
            """.trimIndent()
        )

        dispatcher.execute(action)

        assertEquals("true", sm.local["fallback"])
    }

    @Test
    fun testJasonActionSerializesProgrammaticSuccessActionsAsArray() {
        val json = Json { ignoreUnknownKeys = true; isLenient = true }
        val encoded = json.encodeToString(
            JasonAction.serializer(),
            JasonAction(
                type = "\$set",
                successActions = listOf(
                    makeAction("\$set", mapOf("one" to "1")),
                    makeAction("\$set", mapOf("two" to "2"))
                )
            )
        )
        val success = (json.parseToJsonElement(encoded) as JsonObject)["success"]

        assertTrue(success is JsonArray)
        assertEquals(2, (success as JsonArray).size)
    }

    @Test
    fun testGeoGetStoresCoordValueAndJasonPayload() = runTest {
        val sm = StateManager(context = null)
        var requestCount = 0
        val dispatcher = ActionDispatcher(sm, geolocationProvider = {
            requestCount++
            "12.34,56.78"
        })

        dispatcher.execute(JasonAction(type = "\$geo.get"))

        assertEquals(1, requestCount)
        assertEquals("12.34,56.78", sm.local["coord"])
        assertEquals("12.34,56.78", sm.local["value"])
        assertEquals(mapOf("coord" to "12.34,56.78", "value" to "12.34,56.78"), sm.local["\$jason"])
    }

    @Test
    fun testGeoGetPayloadFlowsIntoRenderSuccessAsJason() = runTest {
        val sm = StateManager(context = null)
        val dispatcher = ActionDispatcher(sm, geolocationProvider = { "12.34,56.78" })
        var renderCount = 0
        dispatcher.setRenderHandler { template, _, _ ->
            assertEquals("coord", template)
            renderCount++
        }

        dispatcher.execute(
            JasonAction(
                type = "\$geo.get",
                success = JasonAction(
                    type = "\$render",
                    options = JsonObject(mapOf("template" to JsonPrimitive("coord")))
                )
            )
        )

        assertEquals(1, renderCount)
        val jason = sm.local["\$jason"] as Map<String, String>
        assertEquals("12.34,56.78", jason["coord"])
    }

    @Test
    fun testGeoGetFailureRunsErrorBranch() = runTest {
        val sm = StateManager(context = null)
        val geoDispatcher = ActionDispatcher(sm, geolocationProvider = {
            throw ActionDispatcher.ActionException("Location permission denied")
        })

        geoDispatcher.execute(
            JasonAction(
                type = "\$geo.get",
                error = makeAction("\$set", mapOf("geo_denied" to "true"))
            )
        )

        assertEquals("true", sm.local["geo_denied"])
    }

    @Test
    fun testAudioPlayResolvesUrlAndRunsSuccessChain() = runTest {
        val sm = StateManager(context = null)
        val played = mutableListOf<String>()
        val dispatcher = ActionDispatcher(
            sm,
            baseUrl = "https://example.com/sounds/index.json",
            audioPlayer = { played.add(it) }
        )

        dispatcher.execute(
            JasonAction(
                type = "\$audio.play",
                options = JsonObject(mapOf("url" to JsonPrimitive("1up.mp3"))),
                success = makeAction("\$set", mapOf("played" to "true"))
            )
        )

        assertEquals(listOf("https://example.com/sounds/1up.mp3"), played)
        assertEquals("true", sm.local["played"])
    }

    @Test
    fun testAudioPlayRejectsDisallowedSchemeAndRunsErrorBranch() = runTest {
        val sm = StateManager(context = null)
        val played = mutableListOf<String>()
        val dispatcher = ActionDispatcher(sm, audioPlayer = { played.add(it) })

        dispatcher.execute(
            JasonAction(
                type = "\$audio.play",
                options = JsonObject(mapOf("url" to JsonPrimitive("file:///tmp/1up.mp3"))),
                error = makeAction("\$set", mapOf("blocked_audio" to "true"))
            )
        )

        assertTrue(played.isEmpty())
        assertEquals("true", sm.local["blocked_audio"])
    }

    @Test
    fun testAudioPlayMissingUrlRunsErrorBranch() = runTest {
        val sm = StateManager(context = null)
        val dispatcher = ActionDispatcher(sm, audioPlayer = {})

        dispatcher.execute(
            JasonAction(
                type = "\$audio.play",
                error = makeAction("\$set", mapOf("missing_audio" to "true"))
            )
        )

        assertEquals("true", sm.local["missing_audio"])
    }

    @Test
    fun testAudioPlayProviderFailureRunsErrorBranch() = runTest {
        val sm = StateManager(context = null)
        val dispatcher = ActionDispatcher(
            sm,
            audioPlayer = { throw ActionDispatcher.ActionException("Audio playback failed") }
        )

        dispatcher.execute(
            JasonAction(
                type = "\$audio.play",
                options = JsonObject(mapOf("url" to JsonPrimitive("https://example.com/missing.mp3"))),
                error = makeAction("\$set", mapOf("audio_failed" to "true"))
            )
        )

        assertEquals("true", sm.local["audio_failed"])
    }

    @Test
    fun testAudioPauseAndStopInvokeHandlersAndRunSuccessChains() = runTest {
        val sm = StateManager(context = null)
        val calls = mutableListOf<String>()
        val dispatcher = ActionDispatcher(
            sm,
            audioPauser = { calls.add("pause") },
            audioStopper = { calls.add("stop") }
        )

        dispatcher.execute(
            JasonAction(
                type = "\$audio.pause",
                success = makeAction("\$set", mapOf("paused" to "true"))
            )
        )
        dispatcher.execute(
            JasonAction(
                type = "\$audio.stop",
                success = makeAction("\$set", mapOf("stopped" to "true"))
            )
        )

        assertEquals(listOf("pause", "stop"), calls)
        assertEquals("true", sm.local["paused"])
        assertEquals("true", sm.local["stopped"])
    }

    @Test
    fun testAudioPauseUnavailableRunsErrorBranch() = runTest {
        val sm = StateManager(context = null)
        val dispatcher = ActionDispatcher(sm)

        dispatcher.execute(
            JasonAction(
                type = "\$audio.pause",
                error = makeAction("\$set", mapOf("pause_failed" to "true"))
            )
        )

        assertEquals("true", sm.local["pause_failed"])
    }

    @Test
    fun testAudioStopUnavailableRunsErrorBranch() = runTest {
        val sm = StateManager(context = null)
        val dispatcher = ActionDispatcher(sm)

        dispatcher.execute(
            JasonAction(
                type = "\$audio.stop",
                error = makeAction("\$set", mapOf("stop_failed" to "true"))
            )
        )

        assertEquals("true", sm.local["stop_failed"])
    }

    @Test
    fun testAudioDurationAndPositionStoreValuePayloadsAndRunSuccessChains() = runTest {
        val sm = StateManager(context = null)
        val dispatcher = ActionDispatcher(
            sm,
            audioDurationProvider = { "42" },
            audioPositionProvider = { "0.25" }
        )

        dispatcher.execute(
            JasonAction(
                type = "\$audio.duration",
                success = makeAction("\$set", mapOf("duration_read" to "true"))
            )
        )

        assertEquals("42", sm.local["value"])
        assertEquals(mapOf("value" to "42"), sm.local["\$jason"])
        assertEquals("true", sm.local["duration_read"])

        dispatcher.execute(
            JasonAction(
                type = "\$audio.position",
                success = makeAction("\$set", mapOf("position_read" to "true"))
            )
        )

        assertEquals("0.25", sm.local["value"])
        assertEquals(mapOf("value" to "0.25"), sm.local["\$jason"])
        assertEquals("true", sm.local["position_read"])
    }

    @Test
    fun testAudioDurationAndPositionUnavailableRunErrorBranches() = runTest {
        val sm = StateManager(context = null)
        val dispatcher = ActionDispatcher(
            sm,
            audioDurationProvider = { null },
            audioPositionProvider = { null }
        )

        dispatcher.execute(
            JasonAction(
                type = "\$audio.duration",
                error = makeAction("\$set", mapOf("duration_failed" to "true"))
            )
        )
        dispatcher.execute(
            JasonAction(
                type = "\$audio.position",
                error = makeAction("\$set", mapOf("position_failed" to "true"))
            )
        )

        assertEquals("player doesn't exist", sm.local["message"])
        assertEquals(mapOf("message" to "player doesn't exist"), sm.local["\$jason"])
        assertEquals("true", sm.local["duration_failed"])
        assertEquals("true", sm.local["position_failed"])
    }

    @Test
    fun testAudioDurationAndPositionDefaultUnavailablePayloads() = runTest {
        val sm = StateManager(context = null)
        val dispatcher = ActionDispatcher(sm)

        dispatcher.execute(
            JasonAction(
                type = "\$audio.duration",
                error = makeAction("\$set", mapOf("default_duration_failed" to "true"))
            )
        )
        assertEquals("player doesn't exist", sm.local["message"])
        assertEquals(mapOf("message" to "player doesn't exist"), sm.local["\$jason"])
        assertEquals("true", sm.local["default_duration_failed"])

        dispatcher.execute(
            JasonAction(
                type = "\$audio.position",
                error = makeAction("\$set", mapOf("default_position_failed" to "true"))
            )
        )
        assertEquals("player doesn't exist", sm.local["message"])
        assertEquals(mapOf("message" to "player doesn't exist"), sm.local["\$jason"])
        assertEquals("true", sm.local["default_position_failed"])
    }

    @Test
    fun testAudioSeekParsesRatioPositionAndRunsSuccessChain() = runTest {
        val sm = StateManager(context = null)
        val sought = mutableListOf<Double>()
        val dispatcher = ActionDispatcher(sm, audioSeeker = { sought.add(it) })

        dispatcher.execute(
            JasonAction(
                type = "\$audio.seek",
                options = JsonObject(mapOf("position" to JsonPrimitive("0.25"))),
                success = makeAction("\$set", mapOf("seeked" to "true"))
            )
        )

        assertEquals(listOf(0.25), sought)
        assertEquals("true", sm.local["seeked"])
    }

    @Test
    fun testAudioSeekMissingInvalidUnavailableOrThrowingPositionIsNoOpSuccess() = runTest {
        val sm = StateManager(context = null)
        val sought = mutableListOf<Double>()
        val dispatcher = ActionDispatcher(sm, audioSeeker = { sought.add(it) })

        dispatcher.execute(
            JasonAction(
                type = "\$audio.seek",
                success = makeAction("\$set", mapOf("missing_seek_success" to "true")),
                error = makeAction("\$set", mapOf("missing_seek_error" to "true"))
            )
        )
        dispatcher.execute(
            JasonAction(
                type = "\$audio.seek",
                options = JsonObject(mapOf("position" to JsonPrimitive("not-a-number"))),
                success = makeAction("\$set", mapOf("invalid_seek_success" to "true")),
                error = makeAction("\$set", mapOf("invalid_seek_error" to "true"))
            )
        )
        ActionDispatcher(sm).execute(
            JasonAction(
                type = "\$audio.seek",
                options = JsonObject(mapOf("position" to JsonPrimitive("0.5"))),
                success = makeAction("\$set", mapOf("unavailable_seek_success" to "true")),
                error = makeAction("\$set", mapOf("unavailable_seek_error" to "true"))
            )
        )
        ActionDispatcher(
            sm,
            audioSeeker = { throw ActionDispatcher.ActionException("Seek failed") }
        ).execute(
            JasonAction(
                type = "\$audio.seek",
                options = JsonObject(mapOf("position" to JsonPrimitive("0.75"))),
                success = makeAction("\$set", mapOf("throwing_seek_success" to "true")),
                error = makeAction("\$set", mapOf("throwing_seek_error" to "true"))
            )
        )

        assertTrue(sought.isEmpty())
        assertEquals("true", sm.local["missing_seek_success"])
        assertEquals("true", sm.local["invalid_seek_success"])
        assertEquals("true", sm.local["unavailable_seek_success"])
        assertEquals("true", sm.local["throwing_seek_success"])
        assertNull(sm.local["missing_seek_error"])
        assertNull(sm.local["invalid_seek_error"])
        assertNull(sm.local["unavailable_seek_error"])
        assertNull(sm.local["throwing_seek_error"])
    }

    @Test
    fun testAudioRecordStoresLegacyPayloadAndRunsSuccessChain() = runTest {
        val sm = StateManager(context = null)
        sm.set(mapOf("color" to "rgba(255,0,0,0.5)"))
        val requests = mutableListOf<ActionDispatcher.AudioRecordRequest>()
        val payload = mapOf(
            "file_url" to "file:///tmp/recorded_audio.m4a",
            "url" to "file:///tmp/recorded_audio.m4a",
            "content_type" to "audio/m4a",
            "data_uri" to "data:audio/m4a;base64,YXVkaW8="
        )
        val dispatcher = ActionDispatcher(
            sm,
            audioRecorder = { request ->
                requests.add(request)
                payload
            }
        )

        dispatcher.execute(
            JasonAction(
                type = "\$audio.record",
                options = JsonObject(mapOf("color" to JsonPrimitive("{{\$get.color}}"))),
                success = makeAction("\$set", mapOf("recorded" to "{{\$jason.file_url}}"))
            )
        )

        assertEquals(listOf(ActionDispatcher.AudioRecordRequest(color = "rgba(255,0,0,0.5)")), requests)
        assertEquals("file:///tmp/recorded_audio.m4a", sm.local["file_url"])
        assertEquals("file:///tmp/recorded_audio.m4a", sm.local["url"])
        assertEquals("audio/m4a", sm.local["content_type"])
        assertEquals("data:audio/m4a;base64,YXVkaW8=", sm.local["data_uri"])
        assertEquals("file:///tmp/recorded_audio.m4a", sm.local["recorded"])
        assertEquals(payload, sm.local["\$jason"])
    }

    @Test
    fun testAudioRecordDefaultColorAndAsyncCompletion() = runTest {
        val sm = StateManager(context = null)
        val deferred = CompletableDeferred<Map<String, Any>?>()
        val recorderStarted = CompletableDeferred<Unit>()
        var requestedColor: String? = null
        val dispatcher = ActionDispatcher(
            sm,
            audioRecorder = { request ->
                requestedColor = request.color
                recorderStarted.complete(Unit)
                deferred.await()
            }
        )

        val job = launch {
            dispatcher.execute(
                JasonAction(
                    type = "\$audio.record",
                    success = makeAction("\$set", mapOf("done" to "{{\$jason.content_type}}"))
                )
            )
        }
        recorderStarted.await()

        assertEquals("rgba(0,0,0,0.8)", requestedColor)
        assertNull(sm.local["done"])
        deferred.complete(
            mapOf(
                "file_url" to "file:///tmp/later.m4a",
                "url" to "file:///tmp/later.m4a",
                "content_type" to "audio/m4a",
                "data_uri" to "data:audio/m4a;base64,bGF0ZXI="
            )
        )
        job.join()

        assertEquals("audio/m4a", sm.local["done"])
    }

    @Test
    fun testAudioRecordUnavailableCancelledAndThrownRouteErrorBranches() = runTest {
        val sm = StateManager(context = null)
        sm.set(
            mapOf(
                "file_url" to "stale-file",
                "url" to "stale-url",
                "content_type" to "stale-type",
                "data_uri" to "stale-data",
                "\$jason" to mapOf("file_url" to "stale")
            )
        )
        val unavailable = ActionDispatcher(sm)
        val cancelled = ActionDispatcher(sm, audioRecorder = { null })
        val throwing = ActionDispatcher(sm, audioRecorder = { throw ActionDispatcher.ActionException("Mic denied") })

        unavailable.execute(
            JasonAction(
                type = "\$audio.record",
                error = makeAction("\$set", mapOf("record_unavailable" to "{{\$jason.file_url}}"))
            )
        )
        cancelled.execute(
            JasonAction(
                type = "\$audio.record",
                error = makeAction("\$set", mapOf("record_cancelled" to "{{\$jason.file_url}}"))
            )
        )
        throwing.execute(
            JasonAction(
                type = "\$audio.record",
                error = makeAction("\$set", mapOf("record_error" to "{{\$jason.message}}"))
            )
        )

        assertEquals("", sm.local["record_unavailable"])
        assertEquals("", sm.local["record_cancelled"])
        assertEquals("Mic denied", sm.local["record_error"])
        assertEquals("", sm.local["file_url"])
        assertEquals("", sm.local["url"])
        assertEquals("", sm.local["content_type"])
        assertEquals("", sm.local["data_uri"])
        assertEquals(mapOf("message" to "Mic denied"), sm.local["\$jason"])
    }

    @Test
    fun testMediaPlayResolvesUrlAndRunsSuccessChain() = runTest {
        val sm = StateManager(context = null)
        val played = mutableListOf<String>()
        val dispatcher = ActionDispatcher(
            sm,
            baseUrl = "https://example.com/video/index.json",
            mediaPlayback = { played.add(it) }
        )

        dispatcher.execute(
            JasonAction(
                type = "\$media.play",
                options = JsonObject(mapOf("url" to JsonPrimitive("clips/demo.mp4"))),
                success = makeAction("\$set", mapOf("video_played" to "true"))
            )
        )

        assertEquals(listOf("https://example.com/video/clips/demo.mp4"), played)
        assertEquals("true", sm.local["video_played"])
    }

    @Test
    fun testMediaPlayRejectsDisallowedSchemeAndRunsErrorBranch() = runTest {
        val sm = StateManager(context = null)
        val played = mutableListOf<String>()
        val dispatcher = ActionDispatcher(sm, mediaPlayback = { played.add(it) })

        dispatcher.execute(
            JasonAction(
                type = "\$media.play",
                options = JsonObject(mapOf("url" to JsonPrimitive("file:///tmp/demo.mp4"))),
                error = makeAction("\$set", mapOf("blocked_video" to "true"))
            )
        )

        assertTrue(played.isEmpty())
        assertEquals("true", sm.local["blocked_video"])
    }

    @Test
    fun testMediaPlayProviderFailureRunsErrorBranch() = runTest {
        val sm = StateManager(context = null)
        val dispatcher = ActionDispatcher(
            sm,
            mediaPlayback = { throw ActionDispatcher.ActionException("Video unavailable") }
        )

        dispatcher.execute(
            JasonAction(
                type = "\$media.play",
                options = JsonObject(mapOf("url" to JsonPrimitive("https://example.com/demo.mp4"))),
                error = makeAction("\$set", mapOf("video_failed" to "true"))
            )
        )

        assertEquals("true", sm.local["video_failed"])
    }

    @Test
    fun testMediaPlayMissingUrlRunsErrorBranch() = runTest {
        val sm = StateManager(context = null)
        val dispatcher = ActionDispatcher(sm, mediaPlayback = {})

        dispatcher.execute(
            JasonAction(
                type = "\$media.play",
                error = makeAction("\$set", mapOf("missing_video" to "true"))
            )
        )

        assertEquals("true", sm.local["missing_video"])
    }

    @Test
    fun testMediaCameraPhotoStoresLegacyImagePayloadAndRunsSuccessChain() = runTest {
        val sm = StateManager(context = null)
        val requests = mutableListOf<ActionDispatcher.MediaCaptureRequest>()
        val payload = mapOf(
            "data" to "aW1hZ2U=",
            "data_uri" to "data:image/jpeg;base64,aW1hZ2U=",
            "content_type" to "image/jpeg"
        )
        val dispatcher = ActionDispatcher(
            sm,
            mediaCapture = { request ->
                requests.add(request)
                payload
            }
        )

        dispatcher.execute(
            JasonAction(
                type = "\$media.camera",
                options = JsonObject(
                    mapOf(
                        "edit" to JsonPrimitive("true"),
                        "quality" to JsonPrimitive("low")
                    )
                ),
                success = makeAction("\$set", mapOf("captured" to "{{\$jason.data}}"))
            )
        )

        assertEquals(
            listOf(ActionDispatcher.MediaCaptureRequest(source = "camera", mediaType = "image", allowsEditing = true, quality = "low")),
            requests
        )
        assertEquals("aW1hZ2U=", sm.local["data"])
        assertEquals("data:image/jpeg;base64,aW1hZ2U=", sm.local["data_uri"])
        assertEquals("image/jpeg", sm.local["content_type"])
        assertEquals(payload, sm.local["\$jason"])
        assertEquals("aW1hZ2U=", sm.local["captured"])
    }

    @Test
    fun testMediaCameraVideoStoresLegacyFilePayload() = runTest {
        val sm = StateManager(context = null)
        var request: ActionDispatcher.MediaCaptureRequest? = null
        val payload = mapOf("file_url" to "content://media/video.mp4", "content_type" to "video/mp4")
        val dispatcher = ActionDispatcher(
            sm,
            mediaCapture = {
                request = it
                payload
            }
        )

        dispatcher.execute(
            JasonAction(
                type = "\$media.camera",
                options = JsonObject(mapOf("type" to JsonPrimitive("video"))),
                success = makeAction("\$set", mapOf("video_url" to "{{\$jason.file_url}}"))
            )
        )

        assertEquals(ActionDispatcher.MediaCaptureRequest(source = "camera", mediaType = "video"), request)
        assertEquals("content://media/video.mp4", sm.local["file_url"])
        assertEquals("video/mp4", sm.local["content_type"])
        assertEquals("content://media/video.mp4", sm.local["video_url"])
        assertEquals(payload, sm.local["\$jason"])
    }

    @Test
    fun testMediaPickerDefaultsToImageAndTemplatedVideoType() = runTest {
        val sm = StateManager(context = null)
        val requests = mutableListOf<ActionDispatcher.MediaCaptureRequest>()
        val dispatcher = ActionDispatcher(
            sm,
            mediaCapture = { request ->
                requests.add(request)
                if (request.mediaType == "video") {
                    mapOf("file_url" to "content://picked/video.mp4", "content_type" to "video/mp4")
                } else {
                    mapOf("data" to "cGljaw==", "data_uri" to "data:image/jpeg;base64,cGljaw==", "content_type" to "image/jpeg")
                }
            }
        )
        sm.set(mapOf("wanted" to "video"))

        dispatcher.execute(JasonAction(type = "\$media.picker"))
        dispatcher.execute(
            JasonAction(
                type = "\$media.picker",
                options = JsonObject(mapOf("type" to JsonPrimitive("{{\$get.wanted}}")))
            )
        )

        assertEquals(
            listOf(
                ActionDispatcher.MediaCaptureRequest(source = "picker", mediaType = "image"),
                ActionDispatcher.MediaCaptureRequest(source = "picker", mediaType = "video")
            ),
            requests
        )
        assertEquals("content://picked/video.mp4", sm.local["file_url"])
    }

    @Test
    fun testMediaCaptureUnavailableCancelledAndThrownRouteErrorBranches() = runTest {
        val sm = StateManager(context = null)
        sm.set(mapOf("\$jason" to mapOf("data" to "stale")))
        val unavailable = ActionDispatcher(sm)
        val cancelled = ActionDispatcher(sm, mediaCapture = { null })
        val throwing = ActionDispatcher(sm, mediaCapture = { throw ActionDispatcher.ActionException("Capture failed") })

        unavailable.execute(
            JasonAction(
                type = "\$media.camera",
                error = makeAction("\$set", mapOf("camera_unavailable" to "{{\$jason.data}}"))
            )
        )
        cancelled.execute(
            JasonAction(
                type = "\$media.picker",
                error = makeAction("\$set", mapOf("picker_cancelled_media" to "{{\$jason.data}}"))
            )
        )
        throwing.execute(
            JasonAction(
                type = "\$media.camera",
                error = makeAction("\$set", mapOf("camera_failed" to "{{\$jason.data}}"))
            )
        )

        assertEquals("", sm.local["camera_unavailable"])
        assertEquals("", sm.local["picker_cancelled_media"])
        assertEquals("", sm.local["camera_failed"])
        assertEquals(emptyMap<String, Any>(), sm.local["\$jason"])
    }

    @Test
    fun testConvertCsvStoresRowsInJasonAndRunsSuccessChain() = runTest {
        val (sm, dispatcher) = createDispatcher()
        var renderCount = 0
        dispatcher.setRenderHandler { _, _, _ -> renderCount++ }

        dispatcher.execute(
            JasonAction(
                type = "\$convert.csv",
                options = JsonObject(
                    mapOf(
                        "data" to JsonPrimitive(
                            "name,descrption,url\nFKA Twigs,Artist,https://example.com/twigs"
                        )
                    )
                ),
                success = JasonAction(type = "\$render")
            )
        )

        val payload = sm.local["\$jason"] as List<Map<String, String>>
        assertEquals(1, payload.size)
        assertEquals("FKA Twigs", payload.first()["name"])
        assertEquals("Artist", payload.first()["descrption"])
        assertEquals("https://example.com/twigs", payload.first()["url"])
        assertEquals(1, renderCount)
    }

    @Test
    fun testConvertCsvHandlesQuotedCommasAndEscapedQuotes() = runTest {
        val (sm, dispatcher) = createDispatcher()

        dispatcher.execute(
            JasonAction(
                type = "\$convert.csv",
                options = JsonObject(
                    mapOf(
                        "data" to JsonPrimitive("name,description\n\"FKA, Twigs\",\"said \"\"hello\"\"\"")
                    )
                )
            )
        )

        val payload = sm.local["\$jason"] as List<Map<String, String>>
        assertEquals("FKA, Twigs", payload.first()["name"])
        assertEquals("said \"hello\"", payload.first()["description"])
    }

    @Test
    fun testConvertRssStoresItemsInJasonAndRunsSuccessChain() = runTest {
        val (sm, dispatcher) = createDispatcher()
        var renderCount = 0
        dispatcher.setRenderHandler { _, _, _ -> renderCount++ }
        val rss = """
            <rss><channel><item>
              <title><![CDATA[Album &amp; Review]]></title>
              <dc:creator>Pitchfork</dc:creator>
              <description>Reviewer&#39;s pick</description>
              <link>https://example.com/review</link>
              <media:content url="https://example.com/image.jpg" />
            </item></channel></rss>
        """.trimIndent()

        dispatcher.execute(
            JasonAction(
                type = "\$convert.rss",
                options = JsonObject(mapOf("data" to JsonPrimitive(rss))),
                success = JasonAction(type = "\$render")
            )
        )

        val payload = sm.local["\$jason"] as List<Map<String, Any>>
        assertEquals(1, payload.size)
        assertEquals("Album & Review", payload.first()["title"])
        assertEquals("Pitchfork", payload.first()["author"])
        assertEquals("Reviewer's pick", payload.first()["description"])
        assertEquals("https://example.com/review", payload.first()["url"])
        assertEquals(mapOf("url" to "https://example.com/image.jpg"), payload.first()["image"])
        assertEquals(1, renderCount)
    }

    @Test
    fun testConvertActionsCanUseCurrentJasonTextPayload() = runTest {
        val (sm, dispatcher) = createDispatcher()
        sm.set(mapOf("\$jason" to "name\nAda"))

        dispatcher.execute(JasonAction(type = "\$convert.csv"))

        val payload = sm.local["\$jason"] as List<Map<String, String>>
        assertEquals("Ada", payload.first()["name"])
    }

    @Test
    fun testUtilityStringOptionsCanTemplateWholeJasonPayload() = runTest {
        val sm = StateManager(context = null)
        val dispatcher = ActionDispatcher(sm)
        sm.set(mapOf("\$jason" to mapOf("title" to "Notice", "description" to "Synced")))
        var message: ActionDispatcher.UtilityMessage? = null
        dispatcher.setUtilityHandler { message = it }
        val json = Json { ignoreUnknownKeys = true; isLenient = true }
        val action = json.decodeFromString<JasonAction>(
            """
            {
              "type": "${'$'}util.banner",
              "options": "{{${'$'}jason}}"
            }
            """.trimIndent()
        )

        dispatcher.execute(action)

        assertEquals("banner", message?.kind)
        assertEquals("Notice", message?.title)
        assertEquals("Synced", message?.description)
    }

    @Test
    fun testUtilAlertEmitsTemplatedUtilityMessageAndRunsSuccessChain() = runTest {
        val (sm, dispatcher) = createDispatcher()
        sm.set(mapOf("name" to "Ada"))
        var message: ActionDispatcher.UtilityMessage? = null
        dispatcher.setUtilityHandler { message = it }

        dispatcher.execute(
            JasonAction(
                type = "\$util.alert",
                options = JsonObject(
                    mapOf(
                        "title" to JsonPrimitive("Hello {{\$get.name}}"),
                        "description" to JsonPrimitive("Ready")
                    )
                ),
                success = makeAction("\$set", mapOf("alerted" to "true"))
            )
        )

        assertEquals("alert", message?.kind)
        assertEquals("Hello Ada", message?.title)
        assertEquals("Ready", message?.description)
        assertEquals("true", sm.local["alerted"])
    }

    @Test
    fun testUtilToastAndBannerEmitUtilityMessages() = runTest {
        val (_, dispatcher) = createDispatcher()
        val messages = mutableListOf<ActionDispatcher.UtilityMessage>()
        dispatcher.setUtilityHandler { messages.add(it) }

        dispatcher.execute(
            JasonAction(
                type = "\$util.toast",
                options = JsonObject(mapOf("text" to JsonPrimitive("Saved")))
            )
        )
        dispatcher.execute(
            JasonAction(
                type = "\$util.banner",
                options = JsonObject(
                    mapOf(
                        "title" to JsonPrimitive("Notice"),
                        "description" to JsonPrimitive("Synced")
                    )
                )
            )
        )

        assertEquals("toast", messages.getOrNull(0)?.kind)
        assertEquals("Saved", messages.getOrNull(0)?.text)
        assertEquals("banner", messages.getOrNull(1)?.kind)
        assertEquals("Notice", messages.getOrNull(1)?.title)
        assertEquals("Synced", messages.getOrNull(1)?.description)
    }

    @Test
    fun testUtilPickerStoresSelectionPayloadAndRunsSuccessChain() = runTest {
        val sm = StateManager(context = null)
        val dispatcher = ActionDispatcher(
            sm,
            utilityPicker = { request ->
                assertEquals("Choose", request.title)
                assertEquals(listOf("First", "Second"), request.items.map { it.text })
                assertEquals(listOf("A", "B"), request.items.map { it.value })
                ActionDispatcher.PickerSelection(1)
            }
        )
        val action = Json { ignoreUnknownKeys = true; isLenient = true }.decodeFromString<JasonAction>(
            """
            {
              "type": "${'$'}util.picker",
              "options": {
                "title": "Choose",
                "items": [
                  { "text": "First", "value": "A" },
                  { "text": "Second", "value": "B" }
                ]
              },
              "success": {
                "type": "${'$'}set",
                "options": {
                  "picked_text": "{{${'$'}jason.text}}",
                  "picked_value": "{{${'$'}jason.value}}"
                }
              }
            }
            """.trimIndent()
        )

        dispatcher.execute(action)

        assertEquals(mapOf("index" to 1, "text" to "Second", "value" to "B"), sm.local["${'$'}jason"])
        assertEquals("Second", sm.local["picked_text"])
        assertEquals("B", sm.local["picked_value"])
    }

    @Test
    fun testUtilPickerAcceptsPrimitiveAndTitleOnlyItems() = runTest {
        val sm = StateManager(context = null)
        val dispatcher = ActionDispatcher(
            sm,
            utilityPicker = { request ->
                assertEquals(listOf("Primitive", "Title only"), request.items.map { it.text })
                assertEquals("Primitive", request.items[0].value)
                assertEquals(1, request.items[1].value)
                ActionDispatcher.PickerSelection(0)
            }
        )
        val action = Json { ignoreUnknownKeys = true; isLenient = true }.decodeFromString<JasonAction>(
            """
            {
              "type": "${'$'}util.picker",
              "options": {
                "items": [
                  "Primitive",
                  { "title": "Title only" }
                ]
              }
            }
            """.trimIndent()
        )

        dispatcher.execute(action)

        assertEquals(mapOf("index" to 0, "text" to "Primitive", "value" to "Primitive"), sm.local["${'$'}jason"])
    }

    @Test
    fun testUtilPickerSelectionUsesOriginalItemIndexAfterSkippedEntries() = runTest {
        val sm = StateManager(context = null)
        val dispatcher = ActionDispatcher(
            sm,
            utilityPicker = { request ->
                assertEquals(listOf(1), request.items.map { it.index })
                assertEquals(listOf("Only valid"), request.items.map { it.text })
                ActionDispatcher.PickerSelection(1)
            }
        )
        val action = Json { ignoreUnknownKeys = true; isLenient = true }.decodeFromString<JasonAction>(
            """
            {
              "type": "${'$'}util.picker",
              "options": {
                "items": [
                  [],
                  { "text": "Only valid", "value": "kept" }
                ]
              }
            }
            """.trimIndent()
        )

        dispatcher.execute(action)

        assertEquals(mapOf("index" to 1, "text" to "Only valid", "value" to "kept"), sm.local["${'$'}jason"])
    }

    @Test
    fun testUtilPickerExecutesSelectedItemAction() = runTest {
        val sm = StateManager(context = null)
        val dispatcher = ActionDispatcher(sm, utilityPicker = { ActionDispatcher.PickerSelection(0) })
        val action = Json { ignoreUnknownKeys = true; isLenient = true }.decodeFromString<JasonAction>(
            """
            {
              "type": "${'$'}util.picker",
              "options": {
                "items": [
                  {
                    "text": "Set state",
                    "action": {
                      "type": "${'$'}set",
                      "options": { "picked_action": "true" }
                    }
                  }
                ]
              }
            }
            """.trimIndent()
        )

        dispatcher.execute(action)

        assertEquals("true", sm.local["picked_action"])
    }

    @Test
    fun testUtilPickerDispatchesSelectedItemHref() = runTest {
        val sm = StateManager(context = null)
        val dispatcher = ActionDispatcher(sm, utilityPicker = { ActionDispatcher.PickerSelection(0) })
        var navigated: JasonHref? = null
        dispatcher.setNavigationHandler { navigated = it }
        val action = Json { ignoreUnknownKeys = true; isLenient = true }.decodeFromString<JasonAction>(
            """
            {
              "type": "${'$'}util.picker",
              "options": {
                "items": [
                  {
                    "text": "Open",
                    "href": { "url": "https://example.com/detail.json" }
                  }
                ]
              }
            }
            """.trimIndent()
        )

        dispatcher.execute(action)

        assertEquals("https://example.com/detail.json", navigated?.url)
    }

    @Test
    fun testUtilPickerCancellationRoutesErrorBranch() = runTest {
        val sm = StateManager(context = null)
        val dispatcher = ActionDispatcher(sm, utilityPicker = { null })

        dispatcher.execute(
            JasonAction(
                type = "${'$'}util.picker",
                options = JsonObject(
                    mapOf("items" to JsonArray(listOf(JsonObject(mapOf("text" to JsonPrimitive("Cancel"))))))
                ),
                error = makeAction("${'$'}set", mapOf("picker_cancelled" to "true"))
            )
        )

        assertEquals("true", sm.local["picker_cancelled"])
    }

    @Test
    fun testUtilDatePickerStoresTimestampPayloadAndRunsSuccessChain() = runTest {
        val sm = StateManager(context = null)
        val dispatcher = ActionDispatcher(
            sm,
            datePicker = { request ->
                assertEquals(1600000000L, request.initialValue)
                1700000000L
            }
        )

        dispatcher.execute(
            JasonAction(
                type = "${'$'}util.datepicker",
                options = JsonObject(mapOf("value" to JsonPrimitive("1600000000"))),
                success = makeAction("${'$'}set", mapOf("selected_time" to "{{${'$'}jason.value}}"))
            )
        )

        assertEquals(mapOf("value" to 1700000000L), sm.local["${'$'}jason"])
        assertTrue(sm.local["selected_time"] is Number)
        assertEquals(1700000000L, (sm.local["selected_time"] as Number).toLong())
    }

    @Test
    fun testUtilDatePickerUnavailableRoutesErrorBranch() = runTest {
        val sm = StateManager(context = null)
        val dispatcher = ActionDispatcher(sm)

        dispatcher.execute(
            JasonAction(
                type = "${'$'}util.datepicker",
                error = makeAction("${'$'}set", mapOf("datepicker_failed" to "true"))
            )
        )

        assertEquals("true", sm.local["datepicker_failed"])
    }

    @Test
    fun testUtilAddressBookStoresContactsInJasonAndRunsSuccessChain() = runTest {
        val sm = StateManager(context = null)
        val contacts = listOf(
            mapOf("name" to "Ada Lovelace", "phone" to "+15551212", "email" to "ada@example.com"),
            mapOf("name" to "Grace Hopper", "phone" to "", "email" to "grace@example.com")
        )
        val dispatcher = ActionDispatcher(sm, addressBookProvider = { contacts })

        dispatcher.execute(
            JasonAction(
                type = "\$util.addressbook",
                success = makeAction("\$set", mapOf("contacts_loaded" to "true"))
            )
        )

        assertEquals(contacts, sm.local["\$jason"])
        assertEquals("true", sm.local["contacts_loaded"])
    }

    @Test
    fun testUtilAddressBookUnavailableRunsErrorBranch() = runTest {
        val sm = StateManager(context = null)
        val dispatcher = ActionDispatcher(sm)

        dispatcher.execute(
            JasonAction(
                type = "\$util.addressbook",
                error = makeAction("\$set", mapOf("contacts_failed" to "true"))
            )
        )

        assertEquals("true", sm.local["contacts_failed"])
    }

    @Test
    fun testUtilAddressBookProviderFailureRoutesErrorBranch() = runTest {
        val sm = StateManager(context = null)
        val dispatcher = ActionDispatcher(
            sm,
            addressBookProvider = { throw ActionDispatcher.ActionException("Contacts permission denied") }
        )

        dispatcher.execute(
            JasonAction(
                type = "\$util.addressbook",
                error = makeAction("\$set", mapOf("contacts_denied" to "true"))
            )
        )

        assertEquals("true", sm.local["contacts_denied"])
    }

    @Test
    fun testUtilShareTemplatesItemsInvokesHandlerAndRunsSuccessChain() = runTest {
        val sm = StateManager(context = null)
        sm.set(mapOf("message" to "Hello", "link" to "https://example.com/story"))
        val shared = mutableListOf<List<ActionDispatcher.ShareItem>>()
        val dispatcher = ActionDispatcher(sm, shareHandler = { shared.add(it) })

        dispatcher.execute(
            JasonAction(
                type = "\$util.share",
                options = JsonObject(
                    mapOf(
                        "items" to JsonArray(
                            listOf(
                                JsonObject(
                                    mapOf(
                                        "type" to JsonPrimitive("text"),
                                        "text" to JsonPrimitive("{{\$get.message}}")
                                    )
                                ),
                                JsonObject(
                                    mapOf(
                                        "type" to JsonPrimitive("url"),
                                        "url" to JsonPrimitive("{{\$get.link}}")
                                    )
                                )
                            )
                        )
                    )
                ),
                success = makeAction("\$set", mapOf("shared" to "true"))
            )
        )

        assertEquals("true", sm.local["shared"])
        assertEquals(
            listOf(
                ActionDispatcher.ShareItem(type = "text", text = "Hello"),
                ActionDispatcher.ShareItem(type = "url", url = "https://example.com/story")
            ),
            shared.single()
        )
    }

    @Test
    fun testUtilShareImageDataItemReachesHandler() = runTest {
        val sm = StateManager(context = null)
        val shared = mutableListOf<List<ActionDispatcher.ShareItem>>()
        val dispatcher = ActionDispatcher(sm, shareHandler = { shared.add(it) })

        dispatcher.execute(
            JasonAction(
                type = "\$util.share",
                options = JsonObject(
                    mapOf(
                        "items" to JsonArray(
                            listOf(
                                JsonObject(
                                    mapOf(
                                        "type" to JsonPrimitive("image"),
                                        "data" to JsonPrimitive("aGVsbG8="),
                                        "content_type" to JsonPrimitive("image/png")
                                    )
                                )
                            )
                        )
                    )
                ),
                success = makeAction("\$set", mapOf("image_shared" to "true"))
            )
        )

        assertEquals(
            listOf(ActionDispatcher.ShareItem(type = "image", data = "aGVsbG8=", contentType = "image/png")),
            shared.single()
        )
        assertEquals("true", sm.local["image_shared"])
    }

    @Test
    fun testUtilShareFileUrlItemAndProviderFailureRoutesErrorBranch() = runTest {
        val sm = StateManager(context = null)
        val shared = mutableListOf<List<ActionDispatcher.ShareItem>>()
        val failingDispatcher = ActionDispatcher(
            sm,
            shareHandler = { items ->
                shared.add(items)
                throw ActionDispatcher.ActionException("Share failed")
            }
        )

        failingDispatcher.execute(
            JasonAction(
                type = "\$util.share",
                options = JsonObject(
                    mapOf(
                        "items" to JsonArray(
                            listOf(
                                JsonObject(
                                    mapOf(
                                        "type" to JsonPrimitive("audio"),
                                        "file_url" to JsonPrimitive("file:///tmp/recorded.m4a")
                                    )
                                )
                            )
                        )
                    )
                ),
                error = makeAction("\$set", mapOf("share_failed" to "true"))
            )
        )

        assertEquals(listOf(ActionDispatcher.ShareItem(type = "audio", fileUrl = "file:///tmp/recorded.m4a")), shared.single())
        assertEquals("true", sm.local["share_failed"])
    }

    @Test
    fun testUtilShareMissingItemsRunsErrorBranch() = runTest {
        val sm = StateManager(context = null)
        val dispatcher = ActionDispatcher(sm, shareHandler = {})

        dispatcher.execute(
            JasonAction(
                type = "\$util.share",
                error = makeAction("\$set", mapOf("missing_share" to "true"))
            )
        )

        assertEquals("true", sm.local["missing_share"])
    }

    @Test
    fun testUtilShareUnavailableRunsErrorBranch() = runTest {
        val sm = StateManager(context = null)
        val dispatcher = ActionDispatcher(sm)

        dispatcher.execute(
            JasonAction(
                type = "\$util.share",
                options = JsonObject(
                    mapOf(
                        "items" to JsonArray(
                            listOf(
                                JsonObject(
                                    mapOf(
                                        "type" to JsonPrimitive("text"),
                                        "text" to JsonPrimitive("Hello")
                                    )
                                )
                            )
                        )
                    )
                ),
                error = makeAction("\$set", mapOf("share_unavailable" to "true"))
            )
        )

        assertEquals("true", sm.local["share_unavailable"])
    }

    @Test
    fun testVisionScanStoresPayloadAndRunsSuccessChain() = runTest {
        val sm = StateManager(context = null)
        var requestedType: String? = null
        val dispatcher = ActionDispatcher(
            sm,
            visionScanner = { request ->
                requestedType = request.type
                mapOf("content" to "hello-qr", "type" to 256, "format" to "qr")
            }
        )
        sm.set(mapOf("desired" to "qrcode"))

        dispatcher.execute(
            JasonAction(
                type = "\$vision.scan",
                options = JsonObject(mapOf("type" to JsonPrimitive("{{\$get.desired}}"))),
                success = makeAction("\$set", mapOf("scanned" to "{{\$jason.content}}"))
            )
        )

        assertEquals("qrcode", requestedType)
        assertEquals("hello-qr", sm.local["content"])
        assertEquals(256, sm.local["type"])
        assertEquals("hello-qr", sm.local["scanned"])
        assertEquals(mapOf("content" to "hello-qr", "type" to 256, "format" to "qr"), sm.local["\$jason"])
    }

    @Test
    fun testVisionScanDispatchesLegacyOnscanAction() = runTest {
        val sm = StateManager(context = null)
        val dispatcher = ActionDispatcher(
            sm,
            visionScanner = { mapOf("content" to "https://example.com", "type" to 256) }
        )
        dispatcher.setActionResolver { name ->
            if (name == "\$vision.onscan") {
                JasonAction(
                    type = "\$set",
                    options = JsonObject(mapOf("legacy_content" to JsonPrimitive("{{\$jason.content}}")))
                )
            } else null
        }

        dispatcher.execute(JasonAction(type = "\$vision.scan"))

        assertEquals("https://example.com", sm.local["legacy_content"])
        assertEquals(mapOf("content" to "https://example.com", "type" to 256), sm.local["\$jason"])
    }

    @Test
    fun testVisionScanRunsLegacyOnscanAndOriginalSuccessChain() = runTest {
        val sm = StateManager(context = null)
        val dispatcher = ActionDispatcher(
            sm,
            visionScanner = { mapOf("content" to "combined", "type" to 256) }
        )
        dispatcher.setActionResolver { name ->
            if (name == "\$vision.onscan") {
                makeAction("\$set", mapOf("legacy" to "{{\$jason.content}}"))
            } else null
        }

        dispatcher.execute(
            JasonAction(
                type = "\$vision.scan",
                success = makeAction("\$set", mapOf("success" to "{{\$jason.content}}"))
            )
        )

        assertEquals("combined", sm.local["legacy"])
        assertEquals("combined", sm.local["success"])
    }

    @Test
    fun testVisionScanUnavailableRoutesErrorBranch() = runTest {
        val sm = StateManager(context = null)
        val dispatcher = ActionDispatcher(sm)

        dispatcher.execute(
            JasonAction(
                type = "\$vision.scan",
                error = makeAction("\$set", mapOf("scan_error" to "true"))
            )
        )

        assertEquals("true", sm.local["scan_error"])
    }

    @Test
    fun testVisionScanCancellationRoutesErrorBranch() = runTest {
        val sm = StateManager(context = null)
        val dispatcher = ActionDispatcher(sm, visionScanner = { null })

        dispatcher.execute(
            JasonAction(
                type = "\$vision.scan",
                error = makeAction("\$set", mapOf("scan_cancelled" to "true"))
            )
        )

        assertEquals("true", sm.local["scan_cancelled"])
    }

    @Test
    fun testLogActionsDoNotCrashAndRunSuccessChain() = runTest {
        val (sm, dispatcher) = createDispatcher()

        dispatcher.execute(
            JasonAction(
                type = "\$log.info",
                options = JsonObject(mapOf("text" to JsonPrimitive("Hello {{flushed}}"))),
                success = makeAction("\$set", mapOf("logged" to "true"))
            )
        )
        dispatcher.execute(JasonAction(type = "\$log.debug", options = JsonObject(mapOf("message" to JsonPrimitive("Debug")))))
        dispatcher.execute(JasonAction(type = "\$log.error", options = JsonObject(mapOf("text" to JsonPrimitive("Error")))))
        dispatcher.execute(JasonAction(type = "\$log", options = JsonObject(mapOf("text" to JsonPrimitive("Generic")))))

        assertEquals("true", sm.local["logged"])
    }

    @Test
    fun testUnknownActionDoesNotCrash() = runTest {
        val (_, dispatcher) = createDispatcher()
        val action = makeAction("\$nonexistent.action")

        // Unknown actions just print, no exception
        dispatcher.execute(action)
    }

    @Test
    fun testSuccessChaining() = runTest {
        val (sm, dispatcher) = createDispatcher()
        val successAction = makeAction("\$set", mapOf("step" to "2"))
        val action = JasonAction(
            type = "\$set",
            options = JsonObject(mapOf("step" to JsonPrimitive("1"))),
            success = successAction
        )

        dispatcher.execute(action)

        // Success chain overrides step from "1" to "2"
        assertEquals("2", sm.local["step"])
    }
}
