---
title: "Fix iOS Components & Actions — Comprehensive Audit"
type: fix
date: 2026-03-28
---

# Fix iOS Components & Actions — Comprehensive Audit

User tested every Jasonpedia demo. Most are broken or show nothing. This plan addresses each reported issue, grouped by root cause so shared fixes unlock multiple demos at once.

---

## Phase A — Architecture Fixes (unblocks ~10 demos)

These are structural problems in the renderer. Fixing them cascades across many demos.

### A1. Layers must be ZStack overlays with absolute positioning

**Problem:** Layers are rendered sequentially in a `LazyVStack` inside a `ScrollView`. They should be floating overlays on top of body content, positioned via `top`/`bottom`/`left`/`right` style properties.

**Affected demos:** Static Layers, Dynamic Layers, CatchAll!, Weather, Background, $render templates

**Plan:**
- Move layers OUT of the ScrollView
- Wrap the body in a `ZStack`
- Render layers as overlay views with `.position()` or `.offset()` based on style's `top`/`left`/`bottom`/`right` values
- Support percentage-based positioning (e.g. `"bottom": "30%-87"`)
- Support `z_index` style property via `.zIndex()` modifier

**Files:** `JasonetteView.swift`, `JasonStyleModifier.swift`, `JasonStyle` model

### A2. Body background not applied

**Problem:** `JasonBody.background` is parsed but never rendered. The Background demo, templates demo, and others set dynamic backgrounds via `"background": "{{$get.bg}}"`.

**Affected demos:** Background, $render templates, Static/Dynamic Layers

**Plan:**
- In `JasonetteView`, read `body.background` and apply as `.background()` on the root container
- Support color strings (hex, rgb, rgba) — reuse `Color(css:)`
- Support image URL strings as background (via `AsyncImage`)
- Camera backgrounds are out of scope for now (requires AVFoundation)

**Files:** `JasonetteView.swift`

### A3. Footer input not rendered

**Problem:** `JasonFooter.input` is parsed into the model but the view only renders `footer.tabs`. The Chat Input demo defines a footer with a textfield, left button, and right button — none of which appear.

**Affected demos:** Chat Input

**Plan:**
- In `footerView()`, add an `else if let input = footer.input` branch
- Render input as an `HStack` with optional left component, a `TextField`, and optional right component
- Bind the text field to `StateManager` via `name` attribute
- Wire left/right button actions

**Files:** `JasonetteView.swift`, `JasonDocument.swift` (may need to adjust `input` type from `[String: JasonComponent]` to a proper struct)

### A4. Missing style properties

**Problem:** Multiple style properties are parsed but never applied: `opacity`, `border_color`, `border_width`, `align`, `spacing`, directional padding (`padding_left` etc.). This causes blank/broken rendering in many demos.

**Affected demos:** Common Styling (blank), Secure TextField (no borders), opacity demo, many others

**Plan:**
- `opacity` → `.opacity()` modifier
- `border_color` + `border_width` → `.overlay(RoundedRectangle(...).stroke(...))`
- `align` → `.frame(alignment:)` for left/center/right
- `spacing` → passed to HStack/VStack initializers (already partially done in LayoutView)
- Directional padding → `.padding(.leading, ...)` etc.

**Files:** `JasonStyleModifier.swift`

---

## Phase B — Missing Actions (unblocks ~8 demos)

### B1. `$util.toast` and `$util.banner`

**Problem:** Both are `break` stubs. Many demos use `$util.banner` to show feedback (textarea value, dynamic layers confirmation, button demos).

**Affected demos:** Static Layers, Dynamic Layers, Textarea, Textfield

**Plan:**
- Implement as a temporary overlay banner at top of screen (toast) or bottom (banner)
- Add a `bannerHandler` callback to `ActionDispatcher`, similar to `alertHandler`
- In `JasonetteView`, show as a `.overlay()` with auto-dismiss after ~2 seconds
- Extract `title` and `description` from options

**Files:** `ActionDispatcher.swift`, `JasonetteView.swift`, `JasonetteViewModel.swift`

### B2. `$snapshot`

**Problem:** No implementation at all. Used by Background demo, CatchAll!, and the dedicated $snapshot demo.

**Affected demos:** Background, CatchAll!, $snapshot demo

**Plan:**
- Use `ImageRenderer` (iOS 16+) to capture the current `JasonetteView` as a `UIImage`
- Add a `snapshotHandler` callback to `ActionDispatcher`
- On success, set `$jason.data` to the base64-encoded image data
- Chain to success action (typically `$util.share`)

**Files:** `ActionDispatcher.swift`, `JasonetteView.swift`, `JasonetteViewModel.swift`

### B3. `$util.share`

**Problem:** Not implemented. Used after `$snapshot` to share captured images, and standalone.

**Affected demos:** Background, $snapshot demo

**Plan:**
- Present `UIActivityViewController` with share items
- Support item types: `text`, `image` (from base64 data), `url`
- Add `shareHandler` callback to `ActionDispatcher`

**Files:** `ActionDispatcher.swift`, `JasonetteView.swift`

### B4. `$audio.play`

**Problem:** Not implemented. Used in Static Layers (1UP sound) and Button demo (Mario button).

**Affected demos:** Static Layers, Button demo (3.json)

**Plan:**
- Use `AVAudioPlayer` or `AVPlayer` for URL-based audio
- Support `url` option for remote audio files
- Add to ActionDispatcher switch statement

**Files:** `ActionDispatcher.swift`

### B5. `$geo.get`

**Problem:** Not implemented. Weather demo chains `$geo.get` → `$network.request` with lat/lon.

**Affected demos:** Weather

**Plan:**
- Use `CLLocationManager` to request current location
- On success, set `$jason` with `{ coord: "lat,lon" }` and chain to success action
- Handle permission prompt and errors

**Files:** `ActionDispatcher.swift` (or new `GeoAction` helper)

### B6. `$media.camera`

**Problem:** Not implemented. Used in Chat Input and CatchAll! demos.

**Affected demos:** Chat Input, CatchAll!

**Plan:**
- Present `UIImagePickerController` with camera source (or photo library fallback on simulator)
- On capture, set `$jason.data` with base64 image data
- Chain to success action

**Files:** `ActionDispatcher.swift`

---

## Phase C — Component Fixes

### C1. Map: region and pins

**Problem:** `MapStubComponent` is an empty `Map()` with no configuration. Demos expect region centering (lat/lon + width/height) and pin annotations with title/description.

**Affected demos:** Map demos (all 3 variants)

**Plan:**
- Accept region from component data: `region.coord` (lat,lon string), `region.width`, `region.height`
- Convert width/height to `MKCoordinateSpan` (degrees)
- Accept `pins` array with `coord`, `title`, `description`
- Use `Map(initialPosition:)` with `MapCameraPosition` and `Annotation` views
- Rename from `MapStubComponent` to `MapComponent`

**Files:** `MapStubComponent.swift` → `MapComponent.swift`, `ComponentRegistry.swift`

### C2. Secure text field

**Problem:** `textfield` ignores `style.secure`. Secure TextField demo shows regular text fields instead of password fields.

**Affected demos:** Secure TextField demo

**Plan:**
- In `TextFieldComponent`, check `style.secure` (or a `secure` prop on the component)
- If secure, use SwiftUI `SecureField` instead of `TextField`
- Parse `secure` from the component's style in `JasonStyle`

**Files:** `TextFieldComponent.swift`, `JasonStyle.swift` (add `secure` property)

### C3. HTML component

**Problem:** No implementation. Shows `[Unknown: html]`.

**Affected demos:** HTML demo

**Plan:**
- Create `HTMLComponent` using `WKWebView` wrapped in `UIViewRepresentable`
- Accept `text` (HTML content) and `css` (CSS string) from the component
- Combine into a full HTML document and load in the web view
- Auto-size height to content

**Files:** New `HTMLComponent.swift`, `ComponentRegistry.swift`

### C4. Button component renders blank

**Problem:** The Button demos (1.json, 2.json) show blank screens. The demo index uses `{{#each items}}` which should work, but the linked sub-demos use `"type": "button"` components with styling that may not render.

**Plan:**
- Verify `ButtonComponent` actually renders its text label and applies styles
- Ensure `width`/`height` style properties work on button components
- The blank screen may be a navigation issue (href to relative URLs like `1.json`)
- Check if relative URL resolution works for sub-demos

**Files:** `ButtonComponent.swift`, possibly `DocumentLoader.swift` for relative URL resolution

### C5. Animated GIF support

**Problem:** `AsyncImage` renders only the first frame of GIFs.

**Affected demos:** Image demo (animated gif), Background demo (cat gif)

**Plan:**
- Detect `.gif` URLs or response content-type
- Use a lightweight GIF renderer — either a custom `UIViewRepresentable` wrapping a `UIImageView` with `animatedImage`, or a small package
- Fall back to `AsyncImage` for non-GIF images

**Files:** `ImageComponent.swift`

### C6. Keyboard dismiss on text inputs

**Problem:** No way to dismiss the keyboard from `TextField` or `TextArea`.

**Plan:**
- Add a `.toolbar { ToolbarItemGroup(placement: .keyboard) { Button("Done") { focused = false } } }`
- Add `@FocusState` to track focus
- Add `.submitLabel(.done)` on TextField
- Add `.onSubmit { }` handler

**Files:** `TextFieldComponent.swift`, `TextAreaComponent.swift`

---

## Phase D — Data & Navigation Fixes

### D1. `$network.request` drops array responses

**Problem:** Response parsing does `as? [String: Any]` — arrays are silently lost. Demos like CatchAll that return array data get nothing.

**Plan:**
- Also handle `as? [Any]` responses
- Set `$response` for both dict and array JSON
- Handle non-JSON responses (set as string)

**Files:** `ActionDispatcher.swift`

### D2. Tabs rendering `[Unknown: nil]`

**Problem:** The tabs demo items may have properties (image, text, badge, url) that don't map to a `JasonComponent.type`. Tab items might lack a `type` field, defaulting to nil → `[Unknown: nil]`.

**Plan:**
- In tab rendering, if a tab item has no `type`, infer a default tab component that renders `image` + `text` + optional `badge`
- Or: ensure tab items in the JSON have proper `type` fields
- Fix the "modal controls presenter's navigation" issue — tabs with href should navigate the current view, not open modals

**Files:** `JasonetteView.swift` (footer tab rendering), `ComponentRegistry.swift`

### D3. Relative URL resolution for sub-demos

**Problem:** Button demo links to `1.json`, `2.json` etc. via `href`. If relative URLs aren't resolved against the current document's base URL, navigation breaks (blank screens).

**Plan:**
- When handling `$href`, resolve the URL relative to the current document's URL
- Store the source URL in the ViewModel
- Use `URL(string: href.url, relativeTo: currentURL)`

**Files:** `JasonetteViewModel.swift`, `DocumentLoader.swift`

---

## Ordering & Dependencies

```
A1 (layers) ──┐
A2 (background)┤
A4 (styles) ───┼── unblocks: Static/Dynamic Layers, Templates, Background
               │
B1 (toast/banner)── unblocks: Layers feedback, Textarea, Textfield
               │
A3 (footer input)── unblocks: Chat Input
               │
C2 (secure) ───┬── unblocks: Secure TextField
C6 (keyboard) ─┘
               │
C1 (map) ──────── unblocks: Map demos
C3 (html) ─────── unblocks: HTML demo
C4 (button) ───┬── unblocks: Button demos
D3 (rel URLs) ─┘
               │
B2 (snapshot) ─┬── unblocks: $snapshot, Background
B3 (share) ────┘
               │
B4 (audio) ────── unblocks: Layers 1UP, Button Mario
B5 (geo) ──────── unblocks: Weather (also needs B2, A1, A2)
B6 (camera) ───── unblocks: Chat Input camera, CatchAll
               │
C5 (gif) ──────── unblocks: animated images
D1 (array resp)── unblocks: API demos returning arrays
D2 (tabs) ─────── unblocks: Tabs demo
```

## Estimated scope

- **Phase A** (architecture): 4 tasks, high impact — fixes are structural and unblock many demos
- **Phase B** (actions): 6 tasks, medium-to-high impact — each is self-contained
- **Phase C** (components): 6 tasks, medium impact — each fixes specific demos
- **Phase D** (data/nav): 3 tasks, targeted fixes

**Recommended start:** A1 → A4 → A2 → B1 → then fan out to independent tracks.
