package com.jasonette

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.BackHandler
import androidx.activity.compose.setContent
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.remember
import com.jasonette.rendering.JasonetteScreen
import java.security.SecureRandom
import java.util.UUID

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            MaterialTheme {
                val entryUrl = "https://bande-a-bonnot.github.io/JASONETTE-Reborn/Jasonpedia/demo.json"
                val navigationStack = remember {
                    mutableStateListOf(JasonetteNavigationEntry(entryUrl, UUIDv7.generate()))
                }
                val currentEntry = navigationStack.last()
                val popOrFinish: () -> Unit = {
                    if (navigationStack.size > 1) {
                        navigationStack.removeAt(navigationStack.lastIndex)
                    } else {
                        finish()
                    }
                }

                BackHandler(enabled = navigationStack.size > 1) {
                    navigationStack.removeAt(navigationStack.lastIndex)
                }

                JasonetteScreen(
                    url = currentEntry.url,
                    viewModelKey = currentEntry.id,
                    onNavigate = { href ->
                        href.url?.let { destination ->
                            val entry = JasonetteNavigationEntry(destination, UUIDv7.generate())
                            if (href.transition == "replace" || href.view == "replace") {
                                navigationStack[navigationStack.lastIndex] = entry
                            } else {
                                navigationStack.add(entry)
                            }
                        }
                    },
                    onBack = popOrFinish,
                    onClose = popOrFinish
                )
            }
        }
    }
}

private data class JasonetteNavigationEntry(val url: String, val id: String)

private object UUIDv7 {
    private val random = SecureRandom()

    fun generate(): String {
        val timestampMillis = System.currentTimeMillis() and 0x0000_FFFF_FFFF_FFFFL
        val randomLong = random.nextLong()
        val randomA = randomLong and 0x0FFFL
        val randomB = random.nextLong() and 0x3FFF_FFFF_FFFF_FFFFL
        val mostSignificantBits = (timestampMillis shl 16) or (0x7L shl 12) or randomA
        val leastSignificantBits = (0x2L shl 62) or randomB
        return UUID(mostSignificantBits, leastSignificantBits).toString()
    }
}
