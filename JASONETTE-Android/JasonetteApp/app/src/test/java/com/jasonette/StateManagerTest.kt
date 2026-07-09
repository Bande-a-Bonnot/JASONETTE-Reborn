package com.jasonette

import com.jasonette.core.StateManager
import org.junit.Assert.*
import org.junit.Test

class StateManagerTest {
    private fun createManager() = StateManager(context = null)

    @Test
    fun testSetStoresValues() {
        val sm = createManager()
        sm.set(mapOf("name" to "Alice", "age" to "30"))

        assertEquals("Alice", sm.local["name"])
        assertEquals("30", sm.local["age"])
    }

    @Test
    fun testGetReturnsCurrentState() {
        val sm = createManager()
        sm.set(mapOf("x" to "1", "y" to "2"))

        val state = sm.get()
        assertEquals("1", state["x"])
        assertEquals("2", state["y"])
        // get() returns a snapshot (toMap), not the live map
        sm.set(mapOf("x" to "changed"))
        assertEquals("1", state["x"]) // snapshot unchanged
    }

    @Test
    fun testFlushClearsLocalState() {
        val sm = createManager()
        sm.set(mapOf("key" to "value"))
        assertEquals("value", sm.local["key"])

        sm.flush()
        assertTrue(sm.local.isEmpty())
    }

    @Test
    fun testLocalStateSeparateFromCache() {
        // With null context, cache ops are no-ops
        val sm = createManager()
        sm.set(mapOf("local_key" to "local_val"))
        sm.cacheSet(mapOf("cache_key" to "cache_val"))

        // Local state has the local key
        assertEquals("local_val", sm.local["local_key"])
        // Cache returns empty with null context
        assertTrue(sm.cacheGet().isEmpty())
        // cacheReset is also a no-op
        sm.cacheReset()
        assertEquals("local_val", sm.local["local_key"])
    }

    @Test
    fun testGlobalSetAndResetMaintainSeparateStore() {
        val sm = createManager()

        val first = sm.globalSet(mapOf("token" to "abc", "profile" to mapOf("name" to "Ada")))
        val second = sm.globalSet(mapOf("count" to 2))
        val reset = sm.globalReset(listOf("token"))

        assertEquals("abc", first["token"])
        assertEquals("Ada", (second["profile"] as Map<*, *>)["name"])
        assertEquals(2, second["count"])
        assertFalse(reset.containsKey("token"))
        assertEquals(2, reset["count"])
        assertTrue(sm.local.isEmpty())
    }

    @Test
    fun testSessionSetAndResetMaintainDomainScopedStore() {
        val sm = createManager()
        val session = mapOf(
            "header" to mapOf("Authorization" to "Bearer abc"),
            "body" to mapOf("api_key" to "secret")
        )

        sm.sessionSet("example.com", session)
        assertEquals(session, sm.sessionForDomain("EXAMPLE.com"))

        sm.sessionReset("example.com")
        assertNull(sm.sessionForDomain("example.com"))
        assertTrue(sm.globalGet().isEmpty())
    }
}
