---
title: "Phase 1: Web Platform"
type: feat
date: 2026-02-28
status: in-progress
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

- [ ] `packages/web-renderer/package.json` — name: `@jasonette/web`
- [ ] `packages/web-renderer/tsconfig.json`
- [ ] `packages/web-renderer/vite.config.ts` — library mode (ESM + CJS + UMD)
- [ ] `packages/web-renderer/vitest.config.ts`
- [ ] Core architecture:
  - `src/renderer.ts` — main entry, document fetch + template engine integration
  - `src/components/` — component renderers (label, button, image, etc.)
  - `src/layouts/` — layout renderers (vertical, horizontal)
  - `src/actions/` — action executors
  - `src/navigation.ts` — SPA navigation with History API
  - `src/state.ts` — $get/$set/$cache state management
  - `src/types.ts` — TypeScript interfaces

### 1.2 — Component Rendering

- [ ] `label` — text with style (font, size, color, etc.)
- [ ] `button` — clickable with action/href
- [ ] `image` — URL-based with style (width, height, corner_radius)
- [ ] `textfield` — single-line input with name/placeholder
- [ ] `textarea` — multi-line input
- [ ] `html` — HTML rendering via iframe sandbox or innerHTML
- [ ] `slider` — range input with name/value
- [ ] `space` — spacer element with style (height)
- [ ] `switch` — toggle input
- [ ] `map` — stub (Tier 2)

### 1.3 — Layout System

- [ ] `vertical` layout — components stacked vertically
- [ ] `horizontal` layout — components side by side
- [ ] Nested layouts — layouts within layouts
- [ ] Layout `style` — spacing, padding, background, etc.
- [ ] `sections` rendering — array of section objects with header/items/footer
- [ ] `header` rendering — page header with title/menu
- [ ] `footer` rendering — tabs and input areas
- [ ] `layers` rendering — overlay elements

### 1.4 — Action System

- [ ] Action executor with success/error chaining
- [ ] `$render` — re-render body with new data
- [ ] `$reload` — reload document from URL
- [ ] `$network.request` — fetch with options (url, method, headers, body)
- [ ] `$set` / `$get` — local state management
- [ ] `$cache.set` / `$cache.get` / `$cache.reset` — persistent state (localStorage)
- [ ] `$util.alert` / `$util.banner` / `$util.toast` — user feedback
- [ ] `$timer.start` / `$timer.stop` — repeating timers
- [ ] `$log` — console logging
- [ ] `$lambda` / `trigger` / `$return` — action composition
- [ ] `$flush` — clear cache/state

### 1.5 — Navigation

- [ ] `$href` — push new view (History.pushState)
- [ ] `$back` — go back (history.back)
- [ ] `$close` — close modal/view
- [ ] `view: "web"` — open in new tab (window.open)
- [ ] `view: "app"` — navigate within app
- [ ] `transition: "modal"` — dialog overlay
- [ ] `transition: "replace"` — replace current view
- [ ] `preload` — loading placeholder during fetch
- [ ] Browser back button handling

### 1.6 — Lifecycle Hooks

- [ ] `$load` — on first document load
- [ ] `$show` — on view becoming visible
- [ ] `$foreground` — page visibility API
- [ ] `$pull` — pull-to-refresh gesture

### 1.7 — Dev Tools

- [ ] `jasonette serve <file>` — dev server with live reload
- [ ] `jasonette validate <file>` — JSON Schema validation
- [ ] `--format json` flag for all CLI commands
- [ ] JSON validation with helpful error messages
- [ ] Hot reload on JSON file change

### 1.8 — Testing & CI

- [ ] Unit tests for each component renderer
- [ ] Unit tests for layout system
- [ ] Unit tests for action system
- [ ] Integration tests rendering Jasonpedia view examples
- [ ] CI job in GitHub Actions
- [ ] Bundle size check (<50KB gzipped target)

## Architecture

```
packages/web-renderer/
├── src/
│   ├── index.ts          # Public API
│   ├── renderer.ts       # Main renderer: fetch → template → DOM
│   ├── components/
│   │   ├── index.ts      # Component registry
│   │   ├── label.ts
│   │   ├── button.ts
│   │   ├── image.ts
│   │   ├── textfield.ts
│   │   ├── textarea.ts
│   │   ├── html.ts
│   │   ├── slider.ts
│   │   ├── space.ts
│   │   └── switch.ts
│   ├── layouts/
│   │   ├── index.ts
│   │   ├── vertical.ts
│   │   └── horizontal.ts
│   ├── actions/
│   │   ├── index.ts      # Action executor
│   │   ├── render.ts
│   │   ├── network.ts
│   │   ├── state.ts
│   │   ├── cache.ts
│   │   ├── util.ts
│   │   ├── timer.ts
│   │   └── log.ts
│   ├── navigation.ts
│   ├── state.ts
│   ├── style.ts          # Style resolver (class lookups, CSS generation)
│   └── types.ts
├── test/
├── bin/
│   └── cli.ts            # CLI entry point
├── package.json
├── tsconfig.json
└── vite.config.ts
```

## Success Criteria

- [ ] All Jasonpedia view examples render correctly
- [ ] Navigation works as SPA with History API
- [ ] Action chaining (success/error) works correctly
- [ ] State management ($get/$set/$cache) persists correctly
- [ ] CLI validates and serves JSON documents
- [ ] Bundle <50KB gzipped
- [ ] CI passes
