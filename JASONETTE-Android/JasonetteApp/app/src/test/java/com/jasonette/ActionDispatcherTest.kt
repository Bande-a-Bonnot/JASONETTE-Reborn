package com.jasonette

import com.jasonette.core.JasonAction
import com.jasonette.core.JasonHref
import com.jasonette.core.StateManager
import com.jasonette.rendering.ActionDispatcher
import kotlinx.coroutines.test.runTest
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import org.junit.Assert.*
import org.junit.Test

class ActionDispatcherTest {
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
        dispatcher.setRenderHandler { renderCount++ }
        val action = makeAction("\$render")

        dispatcher.execute(action)

        assertEquals(1, renderCount)
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
    fun testNamedTriggerResolvesHeadAction() = runTest {
        val (sm, dispatcher) = createDispatcher()
        dispatcher.setActionResolver { name ->
            if (name == "send") makeAction("\$set", mapOf("sent" to "true")) else null
        }

        dispatcher.execute(JasonAction(trigger = "send"))

        assertEquals("true", sm.local["sent"])
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
