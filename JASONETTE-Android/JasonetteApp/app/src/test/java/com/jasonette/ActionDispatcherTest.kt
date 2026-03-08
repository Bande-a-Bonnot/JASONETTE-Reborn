package com.jasonette

import com.jasonette.core.JasonAction
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
    fun testRenderDoesNotCrash() = runTest {
        val (_, dispatcher) = createDispatcher()
        val action = makeAction("\$render")

        // $render is a no-op in ActionDispatcher (handled by ViewModel)
        dispatcher.execute(action)
    }

    @Test
    fun testReloadDoesNotCrash() = runTest {
        val (_, dispatcher) = createDispatcher()
        val action = makeAction("\$reload")

        // $reload is a no-op in ActionDispatcher (handled by ViewModel)
        dispatcher.execute(action)
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
