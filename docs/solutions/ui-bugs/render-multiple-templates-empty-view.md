---
title: "$render multiple templates produces empty view"
date: 2026-03-19
category: ui-bugs
module: Jasonette iOS Renderer
problem_type: ui_bug
component: frontend_stimulus
symptoms:
  - "Navigating to Core -> $render -> Multiple templates shows empty view"
  - "JasonTemplates only decodes 'body' template, drops all other named templates"
  - "Template output decoded as JasonRoot instead of JasonBody — decode fails silently"
root_cause: logic_error
resolution_type: code_fix
severity: high
tags: [swiftui, templates, render, jasonette, codable, action-dispatcher]
---

# $render Multiple Templates Produces Empty View

## Problem

The `templates.json` demo defines two named templates ("body" and "horizontal") under `head.templates`. Navigating to it showed a completely empty view — no content, no buttons, nothing.

## Symptoms

- Empty view on the Multiple Templates demo screen
- `JasonTemplates` struct only had `body: AnyCodable?` — the "horizontal" template was silently dropped during JSON decoding
- Template rendering fell back to `doc.jason` which had no top-level `body` (the entire body was supposed to come from the template)

## What Didn't Work

The architecture assumed `head.templates` only had a `body` key. The Jasonette spec supports arbitrary named templates (`"horizontal"`, `"grid"`, etc.), but the Swift model hardcoded a single property.

## Solution

Three fixes, each addressing a different layer:

**1. JasonTemplates → dynamic dictionary**
```swift
// Before: only "body" decoded
public struct JasonTemplates: Codable, Sendable {
    public var body: AnyCodable?
}

// After: all named templates preserved
public struct JasonTemplates: Codable, Sendable {
    private var storage: [String: AnyCodable] = [:]
    public subscript(name: String) -> AnyCodable? { ... }
    public var body: AnyCodable? { storage["body"] }
    // Custom Codable via singleValueContainer
}
```

**2. Decode template output as JasonBody, not JasonRoot**
```swift
// Before: failed because template output is {sections, layers}, not {head, body}
var root = try decoder.decode(JasonRoot.self, from: renderedData)

// After: decode as body, assemble root
let body = try decoder.decode(JasonBody.self, from: renderedData)
renderedRoot = JasonRoot(head: head, body: body)
```

**3. $render action reads options.template**
```swift
// Before: no-op
case "$render":
    stateManager.objectWillChange.send()

// After: renderHandler callback with template name
case "$render":
    let templateName = options["template"]?.string
    renderHandler?(templateName)
```

ViewModel tracks `activeTemplateName` (defaults to "body"), validates template exists before switching, and re-renders.

## Why This Works

Each fix closes a gap in the template rendering pipeline: decoding preserves all templates, rendering targets the correct type, and the action system communicates the template name. The `$render` without `options.template` defaults to "body" — matching the original Jasonette spec behavior.

## Prevention

- When modeling JSON with arbitrary keys, use a dictionary-backed struct with custom Codable — not fixed properties
- Template output is always body-level (sections, layers, header, style) — never decode as root-level
- Use Combine `$renderedRoot` subscriptions for async test assertions instead of `Task.sleep` — deterministic and not flaky on CI

## Related Issues

- See also: [swiftui-sdui-renderer-structural-rendering-gaps.md](swiftui-sdui-renderer-structural-rendering-gaps.md) — the Phase A fixes that build on this
- PR #12 (merged)
