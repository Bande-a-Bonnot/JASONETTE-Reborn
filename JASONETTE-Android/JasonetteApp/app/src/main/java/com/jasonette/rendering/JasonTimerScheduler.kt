package com.jasonette.rendering

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.CoroutineStart
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import java.util.concurrent.ConcurrentHashMap

/** Schedules Jasonette timer actions behind a deterministic test seam. */
interface JasonTimerScheduler {
    fun start(name: String, intervalMillis: Long, repeats: Boolean, action: suspend () -> Unit)
    fun stop(name: String? = null)
}

class CoroutineJasonTimerScheduler(
    private val scope: CoroutineScope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
) : JasonTimerScheduler {
    private val jobs = ConcurrentHashMap<String, Job>()

    override fun start(name: String, intervalMillis: Long, repeats: Boolean, action: suspend () -> Unit) {
        stop(name)
        require(intervalMillis > 0) { "Timer interval must be greater than zero" }
        val job = scope.launch(start = CoroutineStart.LAZY) {
            try {
                if (repeats) {
                    while (isActive) {
                        action()
                        delay(intervalMillis)
                    }
                } else {
                    delay(intervalMillis)
                    if (isActive) action()
                }
            } finally {
                jobs.remove(name)
            }
        }
        jobs[name] = job
        job.start()
    }

    override fun stop(name: String?) {
        if (name == null) {
            jobs.values.forEach { it.cancel() }
            jobs.clear()
        } else {
            jobs.remove(name)?.cancel()
        }
    }
}
