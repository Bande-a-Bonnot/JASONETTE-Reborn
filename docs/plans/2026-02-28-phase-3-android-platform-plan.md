---
title: "Phase 3: Android Platform"
type: feat
date: 2026-02-28
status: completed
parent: docs/plans/2026-02-26-feat-jasonette-revival-roadmap-plan.md
milestone: 6
branch: feat/phase-3-android-platform
---

# Phase 3: Android Platform

## Goal

Native Android app that renders `$jason` JSON using modern Kotlin and Jetpack
Compose. Mirror the iOS architecture: template engine port, component registry,
action dispatcher, navigation.

## Deliverables

- [x] Gradle project with Kotlin, Compose, min SDK 26, target SDK 35
- [x] Template engine port (expression parser + evaluator + template engine)
- [x] Codable-equivalent data models (@Serializable)
- [x] Document loader (OkHttp/Ktor)
- [x] State manager
- [x] 10 Compose components (label, image, button, textfield, textarea, slider, space, switch, map, layouts)
- [x] Style modifier system
- [x] JasonetteScreen composable (main renderer)
- [x] Action dispatcher with coroutines
- [x] Navigation (Compose Navigation)
- [x] Unit tests (50+)
- [x] CI job (GitHub Actions)

## Technical Decisions

- **Jetpack Compose** for all UI — LazyColumn for recycling, no RecyclerView
- **kotlinx.serialization** for JSON parsing (Kotlin-native, no reflection)
- **Ktor** or plain HttpURLConnection for networking
- **Compose Navigation** for $href handling
- **Kotlin coroutines** for async action execution
- **SharedPreferences** for $cache persistence
