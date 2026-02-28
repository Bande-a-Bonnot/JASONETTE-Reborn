---
title: "Compose State Hoisting for Jasonette Components"
category: architecture
tags: [android, compose, state-management, jetpack-compose]
module: JASONETTE-Android
symptom: "Input components lose state on recomposition"
root_cause: "Internal state via remember{} not connected to ViewModel"
---

# Compose State Hoisting for Jasonette Components

## Problem

Input components (TextField, Slider, Switch) used internal `remember {}` state,
making them uncontrolled. State was invisible to the ViewModel and lost during
recomposition.

## Solution

Make components stateless — accept `value` and `onValueChange` callbacks. State
is managed centrally via `StateManager`, passed through `ComponentView`.

```kotlin
// Before (wrong)
@Composable
fun TextFieldComponent(name: String, placeholder: String) {
    var text by remember { mutableStateOf("") } // isolated state
    OutlinedTextField(value = text, onValueChange = { text = it })
}

// After (correct)
@Composable
fun TextFieldComponent(
    name: String,
    placeholder: String,
    value: String,
    onValueChange: (String) -> Unit
) {
    OutlinedTextField(value = value, onValueChange = onValueChange)
}
```

## Key Insight

Jasonette components are data-driven (JSON → UI). All state must flow through
a central StateManager so templates can reference values via `$get`.
