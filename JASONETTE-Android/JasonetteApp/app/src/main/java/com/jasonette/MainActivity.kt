package com.jasonette

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.material3.MaterialTheme
import com.jasonette.rendering.JasonetteScreen

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            MaterialTheme {
                JasonetteScreen(url = "https://bande-a-bonnot.github.io/JASONETTE-Reborn/Jasonpedia/demo.json")
            }
        }
    }
}
