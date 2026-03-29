---
title: "Fix $render multiple templates producing empty view"
type: fix
date: 2026-03-19
deepened: 2026-03-19
---

# Fix $render Multiple Templates

## Enhancement Summary

**Deepened on:** 2026-03-19
**Sections enhanced:** 4 phases + edge cases
**Research agents used:** learnings-researcher (anycodable, codable, swiftui), architecture-strategist, pattern-recognition, code-simplicity

### Key Improvements
1. AnyCodable crash prevention: always `.unwrapped` before `JSONSerialization`
2. Confirmed struct approach is safe (no recursive Codable issue)
3. Conditional SwiftUI modifier application for horizontal section styling

## Overview

Navigating to Core -> $render -> Multiple templates produces an empty view. The `templates.json` demo defines two named templates (`"body"` and `"horizontal"`) under `head.templates`, but three bugs prevent them from rendering.

## Problem Statement

The `templates.json` document has no top-level `$jason.body` — the entire body comes from named templates in `head.templates`. Three things break:

1. **`JasonTemplates` struct is too narrow** (`JasonDocument.swift:25-27`): Only has `body: AnyCodable?`, so the `"horizontal"` template is silently dropped during decoding.

2. **Template output decoded as wrong type** (`JasonetteViewModel.swift:115`): The rendered template is a body-level dict (`{style, header, layers, sections}`), but the code tries to decode it as `JasonRoot` (`{head, body}`). Decoding fails, fallback uses `doc.jason` which has no `body` — empty view.

3. **`$render` action ignores `options.template`** (`ActionDispatcher.swift:79-80`): Only calls `objectWillChange.send()`. Never reads the template name from options, so tapping "Horizontal"/"Vertical" buttons cannot switch templates.

## Proposed Solution

### Phase 1: Fix `JasonTemplates` to support arbitrary named templates

**File:** `JasonDocument.swift:25-27`

Replace the fixed `body` property with a dynamic dictionary:

```swift
// Before
public struct JasonTemplates: Codable, Sendable {
    public var body: AnyCodable?
}

// After
public struct JasonTemplates: Codable, Sendable {
    private var storage: [String: AnyCodable] = [:]

    public subscript(name: String) -> AnyCodable? {
        get { storage[name] }
        set { storage[name] = newValue }
    }

    public var body: AnyCodable? { storage["body"] }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        storage = try container.decode([String: AnyCodable].self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(storage)
    }
}
```

#### Research Insights

**From `docs/solutions/swift-recursive-codable-structs.md`:**
- Using `[String: AnyCodable]` as storage in a struct is safe — `AnyCodable` provides the indirection layer. No risk of infinite-size struct (unlike recursive self-references which require `class`).
- `JasonComponent` and `JasonAction` are already `final class` in this codebase precisely because they self-reference. `JasonTemplates` does not self-reference, so struct is correct.

**From `docs/solutions/runtime-errors/anycodable-nsjsonserialization-crash.md`:**
- When `JSONDecoder` decodes `[String: AnyCodable]`, nested values are wrapped in `AnyCodable`. Always call `.unwrapped` before passing to `JSONSerialization` APIs to strip wrappers and avoid `NSInvalidArgumentException` crashes.
- The existing `render()` method already calls `template.unwrapped` on line 104 — this pattern must be preserved.

### Phase 2: Fix template rendering to decode as `JasonBody`

**File:** `JasonetteViewModel.swift:98-127`

The rendered template produces a body structure, not a root. Decode as `JasonBody` and assemble the `JasonRoot`:

```swift
// Before
var root = try decoder.decode(JasonRoot.self, from: renderedData)
root.head = head
renderedRoot = root

// After
let body = try decoder.decode(JasonBody.self, from: renderedData)
renderedRoot = JasonRoot(head: head, body: body)
```

Also need to make `JasonRoot` initializable:

```swift
// JasonDocument.swift
public struct JasonRoot: Codable, Sendable {
    public var head: JasonHead?
    public var body: JasonBody?

    public init(head: JasonHead? = nil, body: JasonBody? = nil) {
        self.head = head
        self.body = body
    }
}
```

#### Research Insights

**AnyCodable crash prevention (critical):**
The full render path must ensure `.unwrapped` is called before `JSONSerialization.data(withJSONObject:)`. The existing guard `JSONSerialization.isValidJSONObject(rendered)` catches this — `isValidJSONObject` returns false for AnyCodable-wrapped values, preventing the crash. Keep this guard.

### Phase 3: Track active template and wire `$render` action

**File:** `JasonetteViewModel.swift`

Add state to track the active template name:

```swift
@Published private var activeTemplateName: String = "body"
```

Update `render()` to use the active template:

```swift
private func render(_ doc: JasonDocument) {
    let head = doc.jason.head
    let data = head?.data?.compactMapValues { $0.unwrapped } ?? [:]
    let context = data.merging(stateManager.local) { _, new in new }

    if let template = head?.templates?[activeTemplateName] {
        let rendered = TemplateEngine.render(template.unwrapped, context: context)

        guard JSONSerialization.isValidJSONObject(rendered) else {
            renderedRoot = doc.jason
            return
        }
        do {
            let renderedData = try JSONSerialization.data(withJSONObject: rendered)
            let body = try decoder.decode(JasonBody.self, from: renderedData)
            renderedRoot = JasonRoot(head: head, body: body)
        } catch {
            renderedRoot = doc.jason
        }
    } else {
        renderedRoot = doc.jason
    }
}
```

**File:** `ActionDispatcher.swift`

Add a render handler callback (same pattern as navigation/reload/alert handlers):

```swift
private var renderHandler: ((String?) -> Void)?

public func setRenderHandler(_ handler: @escaping (String?) -> Void) {
    self.renderHandler = handler
}

// In dispatch():
case "$render":
    let templateName = options["template"]?.string
    renderHandler?(templateName)
```

**File:** `JasonetteViewModel.swift` (wireHandlers)

```swift
actionDispatcher.setRenderHandler { [weak self] templateName in
    guard let self else { return }
    if let name = templateName {
        self.activeTemplateName = name
    }
    if let doc = self.document { self.render(doc) }
}
```

#### Research Insights

**Handler pattern consistency:**
The existing codebase uses the exact same callback pattern for navigation, reload, and alert handlers:
- `private var handler: ((...) -> Void)?`
- `public func setHandler(_ handler: @escaping (...) -> Void)`
- Wired in `wireHandlers()` with `[weak self]`

The renderHandler follows this pattern exactly. No new abstractions needed.

**Reset `activeTemplateName` on reload:**
When the document reloads (new URL navigation), `activeTemplateName` should reset to `"body"`. This happens naturally since each `JasonetteViewModel` instance is created per-URL with its own state.

### Phase 4: Handle `JasonSection.type` for horizontal layouts

The `"horizontal"` template uses `"type": "horizontal"` on sections. Check if `JasonSection` supports this.

**File:** `JasonDocument.swift:43-47`

```swift
// Add type field
public struct JasonSection: Codable, Sendable {
    public var type: String?  // "horizontal" for horizontal scroll
    public var header: JasonComponent?
    public var items: [JasonComponent]?
    public var style: JasonStyle?
}
```

Then ensure the section renderer respects `type: "horizontal"` (render items in `ScrollView(.horizontal)` / `LazyHStack` instead of `LazyVStack`).

#### Research Insights

**From `docs/solutions/build-errors/swiftui-modifier-gotchas.md`:**
- When styling the horizontal `ScrollView`, never pass `nil` to `.foregroundColor()` or `.background()` — it silently overrides inherited colors. Use conditional modifier application.
- Reference: `LayoutView.swift` already implements `ScrollView(.horizontal)` + `HStack` for component-level horizontal layouts. Reuse the same pattern for section-level horizontal scrolling.

**From existing `LayoutView.swift`:**
The existing horizontal layout for components uses `ScrollView(.horizontal, showsIndicators: false)` with `HStack`. The section-level horizontal should follow the same pattern but with section items instead of sub-components.

## Acceptance Criteria

- [x] `templates.json` loads and renders the default "body" template showing Simpsons characters in a vertical list
- [x] Tapping "Horizontal" switches to the horizontal carousel template
- [x] Tapping "Vertical" switches back to the vertical list template
- [x] Floating layer buttons ("Horizontal"/"Vertical") render on both templates
- [x] All existing tests pass (`swift test`)
- [x] New tests cover:
  - [x] `JasonTemplates` decodes arbitrary named templates
  - [x] `JasonTemplates` subscript access works
  - [x] Template rendering decodes as `JasonBody` (not `JasonRoot`)
  - [x] `$render` action with `options.template` triggers template switch
  - [x] `$render` action without template re-renders current template
  - [x] Unknown template name falls back gracefully

## Edge Cases

- **Unknown template name in `$render`**: If `options.template` names a template that doesn't exist, keep the current template and log a warning
- **No `"body"` template**: If `head.templates` exists but has no `"body"` key, fall through to `doc.jason.body` (raw body)
- **Both `head.templates.body` and top-level `body`**: Template takes precedence (matches original Jasonette behavior)
- **Template with layers**: Layers in the template body should render as floating overlays (existing layer rendering handles this)
- **AnyCodable wrapping**: Template values from `[String: AnyCodable]` storage must be `.unwrapped` before `JSONSerialization` — already handled by existing `template.unwrapped` call

## Files to Modify

| File | Change |
|------|--------|
| `Sources/Jasonette/Core/JasonDocument.swift` | `JasonTemplates` → dynamic dict; `JasonRoot` init; `JasonSection.type` |
| `Sources/Jasonette/Rendering/JasonetteViewModel.swift` | Active template tracking; decode as `JasonBody`; render handler |
| `Sources/Jasonette/Core/ActionDispatcher.swift` | Render handler callback; `$render` reads `options.template` |
| `Sources/Jasonette/Rendering/SectionView.swift` | Horizontal section layout support |
| `Tests/JasonetteTests/` | New tests for all changes |

## References

- `Jasonpedia/core/render/templates.json` — the demo fixture
- `Jasonpedia/core/render/index.json` — the menu page linking to templates
- `docs/solutions/test-failures/ios-test-isolation-patterns.md` — DI test patterns
- `docs/solutions/architecture-patterns/reviving-a-decade-old-cross-platform-project.md` — learning #20 (DI everywhere)
- `docs/solutions/runtime-errors/anycodable-nsjsonserialization-crash.md` — always `.unwrapped` before JSONSerialization
- `docs/solutions/swift-recursive-codable-structs.md` — struct vs class for Codable types
- `docs/solutions/build-errors/swiftui-modifier-gotchas.md` — conditional modifier application
