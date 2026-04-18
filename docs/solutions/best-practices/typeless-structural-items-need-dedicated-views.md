---
title: "Typeless structural items need dedicated views, not generic component dispatch"
date: 2026-04-17
module: JasonetteView
problem_type: best_practice
category: best-practices
component: tooling
severity: medium
tags: [ios, swiftui, sdui, rendering-pattern, structural-views, footer]
applies_when:
  - "A JSON node has an implicit/fixed shape but no `type` field"
  - "Items are routed through `ComponentView`/`ComponentRegistry` and render as `[Unknown: nil]`"
  - "You are extracting a purpose-built view (footer, header, tab bar, nav rail) out of generic dispatch"
  - "A structural container has children with semantics the generic renderer can't infer"
---

# Typeless Structural Items Need Dedicated Views

## Context

The iOS Jasonette renderer dispatches body components by `type` via `ComponentView` and `ComponentRegistry`. When `type` is nil, the fallback is `Text("[Unknown: nil]")`. That fallback is correct for body content — a generic component with no type is genuinely unrenderable.

But Jasonette's document format also has *structural* nodes whose shape is implicit. Footer tab items in `Jasonpedia/view/footer/tabs.json` look like:

```json
{ "image": "...", "text": "Info", "badge": "2", "url": "..." }
```

No `type`. They are conceptually "tab cells" with a fixed layout (image + text + optional badge, tap → navigate or action). Routing them through `ComponentView` painted `[Unknown: nil]` across the whole tab bar.

The existing pattern in this codebase — documented in [`../ui-bugs/swiftui-sdui-renderer-structural-rendering-gaps.md`](../ui-bugs/swiftui-sdui-renderer-structural-rendering-gaps.md) and summarized in `CLAUDE.md` as "Structural Elements Get Dedicated Views" — already covered `FooterInputView` (left button + text field + right button). Today's fix (commits `14f7659`, `509ec91` on `fix/network-response-and-tab-items`) extends the same pattern to footer tab items with `FooterTabItemView`, and the render path in `footerView()` now switches on `item.type == nil`.

## Guidance

When you introduce a dedicated structural view, treat it as a **full replacement** for `ComponentView` for that node. Before shipping, walk an **affordance checklist**:

1. **Every action route.** `ComponentView` handles `href` before `action` and does *not* handle a direct `url` field (that's `ButtonComponent`-specific). The new view must mirror `href > action` at minimum. If the structural shape also accepts a shorthand `url` on the item (footer tab items do), promote it into the `href` branch so url-only fixtures still navigate — don't wire a separate fourth branch that reorders precedence. Missing one turns some fixtures into inert views with no compile error.
2. **Every style property the generic renderer reads.** Width, height, padding (uniform and directional), opacity, border, alignment, color, background. Hard-coding `.frame(width: 24, height: 24)` for an icon silently overrides the `"height": "21"` the fixture author wrote.
3. **Every optional field declared on the model.** If you added `badge: String?` to `JasonComponent`, the view must render it when present. If `placeholder` exists, honor it.
4. **Closure and environment plumbing.** `onAction`, `onHref`, `StateManager`, `@Environment(\.openURL)` — anything the generic path injected must be wired by the dedicated view too. It's very easy to pass only `onHref` and forget `onAction`.

Build the checklist from the **model and the generic renderer**, not from the specific fixture in front of you. Fixtures exercise a subset; the affordance surface is larger.

## Why This Matters

`ComponentView` is a convergence point: every optional field, style modifier, and action dispatch is handled in one place. A dedicated structural view is an intentional **fork** of that dispatch. The fork starts empty, and the only discipline preventing regressions is the author remembering what the generic path did.

Code review catches some of this — CodeRabbit flagged the obvious shape of `FooterTabItemView`'s initial landing... actually, it didn't flag anything; it returned "no findings". The *missing* affordances are invisible to reviewers who don't cross-reference `ComponentView`. On this change, Codex (`gpt-5.4`, `model_reasoning_effort="xhigh"`) caught two P2s that CodeRabbit missed:

1. `onAction` was never wired, so action-only tab items (no `url`/`href`) were inert.
2. Icon frame was hard-coded to 24pt, ignoring `item.style.height`. Real fixtures set `"height": "21"`.

Both bugs compile, pass existing tests, and look correct in the one demo you happen to open. They only surface when a fixture exercises the missed affordance.

## When to Apply

Reach for a dedicated structural view when:

- The JSON node has **no `type` field** and a **fixed schema** (footer input, footer tab item, header title, nav bar).
- The node **anchors to screen geometry** rather than flowing inside the body (edges, safe areas, overlays).
- The node has **sub-elements with specific roles** (left/right button, badge, title) that the generic renderer cannot infer.

Do *not* reach for a dedicated view when:

- The node has a `type` — register a component instead.
- The "fixed shape" is actually a convention that varies across demos. Add a `type` to the model.

## Examples

### Before: generic dispatch produced `[Unknown: nil]`

```swift
// footerView() — old
ForEach(items) { item in
    ComponentView(item, headStyles: headStyles, onHref: ..., onAction: ...)
}
```

With `item.type == nil`, every tab rendered the unknown-type fallback.

### After: switch on type presence

```swift
// footerView() — new
if item.type == nil {
    FooterTabItemView(
        item: item,
        headStyles: headStyles,                        // easy to forget
        onHref: { viewModel.handleHref($0) },
        onAction: { viewModel.handleAction($0) }       // easy to forget
    )
} else {
    ComponentView(item, headStyles: headStyles, onHref: ..., onAction: ...)
}
```

`FooterTabItemView` walks the affordance checklist:

```swift
// Icon respects the resolved (class + inline) style; falls back to 24pt square.
let resolved = JasonStyleModifier.resolve(style: item.style,
                                          headStyles: headStyles,
                                          className: item.class)
let iconWidth = resolved.width?.cgFloat ?? resolved.height?.cgFloat ?? 24
let iconHeight = resolved.height?.cgFloat ?? resolved.width?.cgFloat ?? 24
AsyncImage(url: url) { $0.resizable().scaledToFit() }
    .frame(width: iconWidth, height: iconHeight)

// Action priority mirrors ComponentView (href > action). The typeless tab-item
// shape also accepts a shorthand `url` on the item; when `href` is absent we
// synthesize a `JasonHref` from it in a dedicated `else if` branch so url-only
// fixtures still navigate. When both `href` and `url` are present, `href` wins
// and we populate its missing `.url` field from the shorthand.
if let href = item.href {
    Button {
        var h = href
        if h.url == nil, let urlString = item.url, !urlString.isEmpty {
            h.url = urlString
        }
        onHref?(h)
    } label: { content }.buttonStyle(.plain)
} else if let urlString = item.url, !urlString.isEmpty {
    Button {
        var href = JasonHref()
        href.url = urlString
        onHref?(href)
    } label: { content }.buttonStyle(.plain)
} else if let action = item.action {
    Button { onAction?(action) } label: { content }.buttonStyle(.plain)
}

// Badge is optional but must be rendered when present
if let badge = item.badge, !badge.isEmpty { /* red capsule overlay */ }
```

Both `FooterInputView` and `FooterTabItemView` live in `JASONETTE-iOS/JasonetteApp/Sources/Jasonette/Rendering/JasonetteView.swift` — useful to keep them side-by-side as a reference for the next extraction.

## Related

- [`../ui-bugs/swiftui-sdui-renderer-structural-rendering-gaps.md`](../ui-bugs/swiftui-sdui-renderer-structural-rendering-gaps.md) — the original `FooterInputView` extraction that established this pattern.
- `CLAUDE.md` → "Structural elements get dedicated views" bullet under iOS Renderer Patterns.
- [`multi-model-review-coderabbit-plus-codex-xhigh.md`](./multi-model-review-coderabbit-plus-codex-xhigh.md) — process learning from the same session on how both P2s were caught before landing.
- Branch: `fix/network-response-and-tab-items` (commits `14f7659`, `509ec91`).
