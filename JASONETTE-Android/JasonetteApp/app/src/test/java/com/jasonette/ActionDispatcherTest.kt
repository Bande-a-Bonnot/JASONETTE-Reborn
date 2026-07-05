package com.jasonette

import com.jasonette.core.JasonAction
import com.jasonette.core.JasonHref
import com.jasonette.core.StateManager
import com.jasonette.rendering.ActionDispatcher
import com.jasonette.rendering.JasonTimerScheduler
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
