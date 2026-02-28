package com.jasonette.rendering

import android.app.Application
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import com.jasonette.components.ComponentView
import com.jasonette.core.*

/**
 * Main composable that renders a complete Jasonette document.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun JasonetteScreen(
    viewModel: JasonetteViewModel,
    onNavigate: ((JasonHref) -> Unit)? = null
) {
    val uiState by viewModel.uiState.collectAsState()

    when (val state = uiState) {
        is UiState.Loading -> {
            Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                CircularProgressIndicator()
            }
        }
        is UiState.Error -> {
            Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text(state.message, color = MaterialTheme.colorScheme.error)
                    Spacer(Modifier.height(16.dp))
                    Button(onClick = { viewModel.reload() }) {
                        Text("Retry")
                    }
                }
            }
        }
        is UiState.Loaded -> {
            val root = state.root
            val head = root.head
            val body = root.body
            val headStyles = head?.styles ?: emptyMap()

            Scaffold(
                topBar = {
                    head?.title?.let { title ->
                        TopAppBar(title = { Text(title) })
                    }
                }
            ) { padding ->
                LazyColumn(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(padding),
                    verticalArrangement = Arrangement.spacedBy(0.dp)
                ) {
                    // Sections
                    body?.sections?.forEach { section ->
                        section.header?.let { header ->
                            item {
                                ComponentView(
                                    header,
                                    headStyles = headStyles,
                                    stateManager = viewModel.stateManager,
                                    onHref = onNavigate,
                                    onAction = { viewModel.handleAction(it) }
                                )
                            }
                        }
                        items(section.items ?: emptyList()) { component ->
                            ComponentView(
                                component,
                                headStyles = headStyles,
                                stateManager = viewModel.stateManager,
                                onHref = onNavigate,
                                onAction = { viewModel.handleAction(it) }
                            )
                        }
                    }

                    // Layers
                    body?.layers?.let { layers ->
                        items(layers) { component ->
                            ComponentView(
                                component,
                                headStyles = headStyles,
                                stateManager = viewModel.stateManager,
                                onHref = onNavigate,
                                onAction = { viewModel.handleAction(it) }
                            )
                        }
                    }
                }
            }
        }
    }

    LaunchedEffect(Unit) { viewModel.loadIfNeeded() }
}

/** Convenience overload that creates a ViewModel from a URL. */
@Composable
fun JasonetteScreen(
    url: String,
    onNavigate: ((JasonHref) -> Unit)? = null
) {
    val application = LocalContext.current.applicationContext as Application
    val viewModel = remember { JasonetteViewModel(application, url = url) }
    JasonetteScreen(viewModel = viewModel, onNavigate = onNavigate)
}
