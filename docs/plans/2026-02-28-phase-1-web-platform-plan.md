---
title: "Phase 1: Web Platform"
type: feat
date: 2026-02-28
status: completed
parent: docs/plans/2026-02-26-feat-jasonette-revival-roadmap-plan.md
milestone: 3
branch: feat/phase-1-web-platform
---

# Phase 1: Web Platform

## Goal

Ship a working web renderer that renders `$jason` JSON documents in the browser. Web first because it has the smallest surface area (1,033 lines original), fastest feedback loop (no Xcode/Gradle), and serves as the reference implementation.

## Deliverables

1. **`packages/web-renderer/`** — TypeScript web renderer using `@jasonette/template-engine`
2. **Component rendering** — All Tier 1 components: label, button, image, textfield, textarea, html, slider, space
3. **Layout system** — Vertical, horizontal, nested layouts
4. **Navigation** — SPA with History API (`$href`, `$back`, `$close`)
5. **Tier 1 actions** — `$render`, `$reload`, `$network.request`, `$set`/`$get`, `$cache.*`, `$util.*`, `$timer.*`, `$log.*`
6. **Dev server** — Live reload with JSON validation
7. **CLI** — `jasonette validate` and `jasonette serve`

## Tasks

### 1.1 — Project Setup & Core Architecture

- [x] `packages/web-renderer/package.json` — name: `@jasonette/web`
- [x] `packages/web-renderer/tsconfig.json`
- [x] `packages/web-renderer/vite.config.ts` — library mode (ESM + CJS + UMD)
- [x] `packages/web-renderer/vitest.config.ts`
- [x] Core architecture:
  - `src/renderer.ts` — main entry, document fetch + template engine integration
  - `src/components/` — component renderers (label, button, image, etc.)
  - `src/layouts/` — layout renderers (vertical, horizontal)
  - `src/actions/` — action executors
  - `src/style.ts` — style resolution
  - `src/types.ts` — TypeScript interfaces

### 1.2 — Component Rendering

- [x] `label` — text with style (font, size, color, etc.)
- [x] `button` — clickable with action/href
- [x] `image` — URL-based with style (width, height, corner_radius)
- [x] `textfield` — single-line input with name/placeholder
- [x] `textarea` — multi-line input
- [x] `html` — HTML rendering via iframe sandbox or innerHTML
- [x] `slider` — range input with name/value
- [x] `space` — spacer element with style (height)
- [x] `switch` — toggle input
- [x] `map` — stub (Tier 2)

### 1.3 — Layout System

- [x] `vertical` layout — components stacked vertically
- [x] `horizontal` layout — components side by side
- [x] Nested layouts — layouts within layouts
- [x] Layout `style` — spacing, padding, background, etc.
- [x] `sections` rendering — array of section objects with header/items/footer
- [x] `header` rendering — page header with title/menu
- [x] `footer` rendering — tabs and input areas
- [x] `layers` rendering — overlay elements

### 1.4 — Action System

- [x] Action executor with success/error chaining
- [x] `$render` — re-render body with new data
- [x] `$reload` — reload document from URL
- [x] `$network.request` — fetch with options (url, method, headers, body)
- [x] `$set` / `$get` — local state management
- [x] `$cache.set` / `$cache.get` / `$cache.reset` — persistent state (localStorage)
- [x] `$util.alert` / `$util.banner` / `$util.toast` — user feedback
- [x] `$timer.start` / `$timer.stop` — repeating timers
- [x] `$log` — console logging
- [x] `$lambda` — action composition
- [x] `$flush` — clear cache/state

### 1.5 — Navigation

- [x] `$href` — push new view (History.pushState)
- [x] `$back` — go back (history.back)
- [x] `$close` — close modal/view
- [x] `view: "web"` — open in new tab (window.open)
- [x] `transition: "modal"` — dialog overlay
- [x] `transition: "replace"` — replace current view
- [x] Browser back button handling

### 1.6 — Lifecycle Hooks

- [x] `$load` — on first document load
- [x] `$show` — on view becoming visible
- [x] `$foreground` — page visibility API
- [x] `$pull` — pull-to-refresh gesture

### 1.7 — Dev Tools

- [x] `jasonette serve <file>` — dev server with live reload (SSE)
- [x] `jasonette validate <file>` — JSON structure validation
- [x] `--format json` flag for validation output
- [x] Hot reload on JSON file change

### 1.8 — Testing & CI

- [x] Unit tests for each component renderer (13 tests)
- [x] Unit tests for layout system (10 tests)
- [x] Unit tests for style system (11 tests)
- [x] Unit tests for renderer (8 tests)
- [x] Lifecycle hook tests (4 tests)
- [x] Integration tests rendering Jasonpedia fixtures (7 tests)
- [x] CLI tests (5 tests)
- [x] CI job in GitHub Actions
- [x] Bundle size: 49KB ESM, 13KB gzipped (under 50KB target)

## Results

- **58 tests passing** across 7 test files
- **Build output**: ESM 49KB, CJS 31KB, UMD 31KB, gzipped 13KB
- **10 component types**, **15 action types**, **3 lifecycle hooks**
- **CLI**: serve with SSE live reload, validate with JSON output
