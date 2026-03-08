---
title: "Cross-Platform Rendering and Navigation Audit + UI Testing Plan"
type: fix
date: 2026-03-08
deepened: 2026-03-08
---

## Enhancement Summary

**Deepened on:** 2026-03-08
**Research agents used:** SwiftUI navigation, CSS color parsing, XCUITest patterns, input binding

### Key Improvements

1. Concrete Swift code for `Color(css:)` unified parser (hex + rgb/rgba, no regex, no dependencies)
2. Item-driven `.sheet(item:)` pattern for modals — avoids multiple boolean `.sheet` pitfalls
3. `@Environment(\.openURL)` for mailto/tel — cross-platform, not `UIApplication.shared`
4. `StateManager.binding(forKey:default:)` factory — connects inputs to state without `@State`
5. Tuist `product: .uiTests` configuration for XCUITest target
6. Launch argument stubbing strategy for deterministic UI tests

# Cross-Platform Rendering and Navigation Audit

Comprehensive audit of all rendering, navigation, and action-handling issues across iOS, Android, and Web. The web renderer is the reference implementation — iOS and Android need to reach parity.

## Problem Statement

The Jasonette app renders the demo.json, but many features visible in the JSON are broken or missing on iOS and Android. Users encounter crashes, non-functional transitions, and missing UI elements. The web renderer works correctly for most of these features.

## Issues Inventory

### iOS Issues (Critical)

| # | Issue | Symptom | Root Cause | File |
|---|-------|---------|------------|------|
| 1 | Modal transitions don't open | Tapping "Instagram"/"Twitter" in demo.json pushes instead of presenting modal | `JasonetteNavigationView` only uses `NavigationStack` push — no `.sheet()` or `.fullScreenCover()` modifier. `transition: "modal"` is parsed but ignored | `Rendering/JasonetteNavigationView.swift` |
| 2 | Mail links don't work | Tapping "Send yourself Documentation" does nothing | `view: "app"` href is not handled — no `UIApplication.shared.open(url)` call | `Core/ActionDispatcher.swift` |
| 3 | Browser links don't work | Tapping "View JSON" menu item loads URL as Jasonette document | `view: "web"` href is not handled — no `SFSafariViewController` or `openURL` | `Core/ActionDispatcher.swift` |
| 4 | Header "With header" crashes | Navigating to Views > Header > With header crashes the app | Header style contains `background` property that triggers rendering code path not handling nil color from `rgb()` parse failure | `Rendering/JasonetteView.swift`, `Components/JasonStyleModifier.swift` |
| 5 | `$render` test crashes on JSONSerialization | Core > Render demo crashes | Template `render()` re-serializes rendered body back to JSON. If the rendered template produces a structure that `JSONSerialization` can't handle (e.g., `AnyCodable` wrapping unexpected types), it crashes | `Rendering/JasonetteViewModel.swift` |
| 6 | `$snapshot` shows loading animation forever | Core > Snapshot demo — swipe down starts spinner, never completes | `$snapshot` action is completely unimplemented. The pull-to-refresh triggers `$pull` lifecycle but the `$snapshot` action in the handler is a no-op | `Core/ActionDispatcher.swift` |
| 7 | `rgb()`/`rgba()` colors not parsed | Colored backgrounds and text using CSS color functions render as default colors | `Color(hex:)` initializer only handles `#RRGGBB`/`#RRGGBBAA`. Demo.json uses `rgba(14,122,254,0.1)` and `rgb(14,122,254)` | `Components/JasonStyleModifier.swift` |
| 8 | Multi-class styles not applied | `class: "bold padded"` only applies one class | Code does `headStyles[cls]` with entire string as key, doesn't split on spaces | `Components/JasonStyleModifier.swift` |
| 9 | `$back`/`$close` are no-ops | Back/close actions do nothing | `handleHref` returns early for these view types, never pops navigation | `Core/ActionDispatcher.swift` |
| 10 | Footer not rendered | Tab bars and input bars from JSON are invisible | `documentBody` renders header, sections, layers — but skips `body.footer` | `Rendering/JasonetteView.swift` |
| 11 | Input components are uncontrolled | TextField, TextArea, Slider, Switch changes don't persist to state | Components use `@State private var` locally, never write back to `StateManager` | `Components/TextFieldComponent.swift` etc. |
| 12 | `$util.alert/toast/banner` are no-ops | Alert/toast actions do nothing visible | Action cases `break` immediately — no SwiftUI `.alert()` modifier | `Core/ActionDispatcher.swift` |
| 13 | `$timer` not implemented | Timer demos don't work (mario, stopwatch) | No timer action handler at all | `Core/ActionDispatcher.swift` |
| 14 | Header background/style not rendered | Header shows as plain navigation bar | `headerView` uses `.navigationTitle()` for title, ignores background/color/font from header style | `Rendering/JasonetteView.swift` |

### Android Issues

| # | Issue | Root Cause | File |
|---|-------|------------|------|
| 15 | No inter-screen navigation | `onNavigate` callback exists but is not wired to start new activities/composables | `MainActivity.kt` |
| 16 | `$render` is a stub | Calls `objectWillChange` but doesn't re-run template engine | `ActionDispatcher.kt` |
| 17 | `$reload` is a stub | No-op, doesn't re-fetch document | `ActionDispatcher.kt` |
| 18 | No footer rendering | Same as iOS — footer section ignored | `JasonetteScreen.kt` |
| 19 | No lifecycle hooks beyond `$load` | `$show`, `$foreground`, `$pull` not implemented | `JasonetteScreen.kt` |
| 20 | `rgb()`/`rgba()` colors not parsed | Same as iOS — only hex colors supported | `ComponentView.kt` |
| 21 | Multi-class styles not applied | Same as iOS — no space-splitting | `ComponentView.kt` |
| 22 | Demo URL points to dead domain | `https://jasonette.com/demo.json` — original Jasonette domain | `MainActivity.kt` |
| 23 | No `$util`, `$timer`, `$snapshot`, `$lambda` | Same missing actions as iOS | `ActionDispatcher.kt` |

### Web Renderer Issues (Minor)

| # | Issue | File |
|---|-------|------|
| 24 | `$snapshot` not implemented | `actions/index.ts` |
| 25 | `view: "app"` (mailto/tel) not implemented | `renderer.ts` |
| 26 | Map component is a stub placeholder | `components/index.ts` |

## Proposed Solution

### Phase 1: Fix iOS Crashes and Critical Rendering (Priority: P0)

These block basic demo.json usability.

**1.1 Fix `rgb()`/`rgba()` color parsing** (`JasonStyleModifier.swift`)

Add a unified `Color(css:)` initializer that dispatches on prefix. Use manual string splitting (no regex — the format is simple and fixed):

```swift
extension Color {
    init?(css: String) {
        let s = css.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if s.hasPrefix("#") {
            self.init(hex: s)
        } else if s.hasPrefix("rgb") {
            self.init(cssRGB: s)
        } else { return nil }
    }

    init?(cssRGB: String) {
        let s = cssRGB.trimmingCharacters(in: .whitespaces).lowercased()
        let isRGBA = s.hasPrefix("rgba(")
        let isRGB = s.hasPrefix("rgb(")
        guard (isRGB || isRGBA), s.hasSuffix(")") else { return nil }
        let prefix = isRGBA ? 5 : 4
        let inner = s.dropFirst(prefix).dropLast()
        let parts = inner.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        guard (isRGB && parts.count == 3) || (isRGBA && parts.count == 4),
              let r = Int(parts[0]), let g = Int(parts[1]), let b = Int(parts[2]),
              (0...255).contains(r), (0...255).contains(g), (0...255).contains(b)
        else { return nil }
        let a: Double = parts.count == 4 ? min(max(Double(parts[3]) ?? 1, 0), 1) : 1.0
        self.init(red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: a)
    }
}
```

Then update all `Color(hex:)` callsites in `JasonStyleModifier` to use `Color(css:)`.

For Android (`ComponentView.kt`), same pattern with `Color(red, green, blue, alpha)` constructor. Or use `android.graphics.Color.parseColor()` for hex + named colors, plus a manual `fromCssRgb()` for `rgb()`/`rgba()`.

**1.2 Fix multi-class style resolution** (`JasonStyleModifier.swift`)
- Split class string on whitespace: `cls.split(separator: " ")`
- Merge styles from each class in order (later classes override earlier)
- Match web renderer behavior: `style.ts:90`

**1.3 Fix header crash** (`JasonetteView.swift`)
- Guard against nil color from failed `rgb()` parse
- After 1.1, the `rgb()` parse will work, but add defensive nil-coalescing regardless

**1.4 Fix `$render` crash** (`JasonetteViewModel.swift`)
- The JSON re-serialization path (`AnyCodable` → `JSONSerialization` → `JSONDecoder`) can fail on edge cases
- Add `do/catch` around the serialization step, fall back to raw document body on failure

### Phase 2: Navigation and Href Handling (Priority: P0)

**2.1 Implement modal transitions** (`JasonetteNavigationView.swift`)

Use item-driven `.sheet(item:)` with `URL` made `Identifiable`. This avoids the pitfall of multiple boolean `.sheet` modifiers (only the first one wins in SwiftUI):

```swift
extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}

struct JasonetteNavigationView: View {
    @State private var path: [URL] = []
    @State private var modalURL: URL?     // item-driven sheet
    @State private var safariURL: URL?    // separate channel for web views

    var body: some View {
        NavigationStack(path: $path) {
            JasonetteView(url: rootURL)
                .navigationDestination(for: URL.self) { url in
                    JasonetteView(url: url)
                }
        }
        .sheet(item: $modalURL) { url in
            NavigationStack {
                JasonetteView(url: url)
            }
        }
        .sheet(item: $safariURL) { url in
            SafariView(url: url).ignoresSafeArea()
        }
    }
}
```

**Pitfall**: Never dismiss a sheet and modify NavigationPath simultaneously — sequence them with a brief delay if needed.

**2.2 Implement `view: "web"`** (`JasonetteNavigationView.swift`)

Create a `SafariView` wrapper (UIViewControllerRepresentable for SFSafariViewController). Present via the `safariURL` sheet above. Use `#if canImport(SafariServices)` for iOS-only, fall back to `openURL` on macOS/tvOS/visionOS:

```swift
#if canImport(SafariServices)
import SafariServices
struct SafariView: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }
    func updateUIViewController(_ vc: SFSafariViewController, context: Context) {}
}
#endif
```

**2.3 Implement `view: "app"`** (`JasonetteNavigationView.swift`)

Use `@Environment(\.openURL)` (SwiftUI-native, works on iOS/macOS/visionOS) instead of `UIApplication.shared.open()`:

```swift
@Environment(\.openURL) private var openURL

func handleAppURL(_ url: URL) {
    openURL(url)  // system handles mailto:, tel:, sms: etc.
}
```

**2.4 Implement `$back`/`$close`**

- `$back`: `path.removeLast()` on the NavigationPath. Or use `@Environment(\.dismiss)` from the pushed view.
- `$close`: Set `modalURL = nil` to dismiss the sheet. `@Environment(\.dismiss)` must be declared in the *presented* view, not the parent.

**Pitfall**: `@Environment(\.dismiss)` in the parent scope dismisses the parent, not the child. Always declare it inside the presented view.

### Phase 3: Missing UI Elements (Priority: P1)

**3.1 Render footer** (`JasonetteView.swift`)
- Tab footer: render as SwiftUI `TabView` or custom bottom bar
- Input footer: render as text field + button at bottom of screen

**3.2 Render header with style** (`JasonetteView.swift`)
- Apply header background color via `.toolbarBackground()` modifier (iOS 16+)
- Apply header text color via `.toolbarColorScheme()` or custom title view

**3.3 Connect input components to StateManager** (all input components)

Add binding factory methods to StateManager:

```swift
extension StateManager {
    func binding(forKey key: String, default defaultValue: String = "") -> Binding<String> {
        Binding<String>(
            get: { self.local[key] as? String ?? defaultValue },
            set: { self.local[key] = $0 }
        )
    }
    func binding(forKey key: String, default defaultValue: Double = 0) -> Binding<Double> {
        Binding<Double>(
            get: { self.local[key] as? Double ?? Double(self.local[key] as? Int ?? 0) },
            set: { self.local[key] = $0 }
        )
    }
    func binding(forKey key: String, default defaultValue: Bool = false) -> Binding<Bool> {
        Binding<Bool>(
            get: { self.local[key] as? Bool ?? defaultValue },
            set: { self.local[key] = $0 }
        )
    }
}
```

Then replace `@State private var` in all input components with `@EnvironmentObject var stateManager: StateManager` and use the binding factory. Creating `Binding(get:set:)` in `var body` is O(1) and safe — it's a lightweight value type holding two closures.

Seed initial values from JSON `value` field during rendering, with a "don't overwrite" guard:
```swift
if stateManager.local[name] == nil, let initial = component.value { stateManager.local[name] = initial }
```

### Phase 4: Missing Actions (Priority: P1)

**4.1 Implement `$util.alert`** (`ActionDispatcher.swift`)
- Post notification with alert config
- `JasonetteView` observes and shows `.alert()` modifier

**4.2 Implement `$util.toast/banner`** (`ActionDispatcher.swift`)
- Toast: temporary overlay at bottom of screen
- Banner: temporary overlay at top

**4.3 Implement `$timer.start/stop`** (`ActionDispatcher.swift`)
- `Timer.scheduledTimer` with repeat interval
- Store timer references by name for `$timer.stop`
- Execute success action on each tick

### Phase 5: Android Parity (Priority: P2)

**5.1 Fix demo URL** — Change to GitHub Pages URL
**5.2 Wire navigation** — Use Jetpack Navigation Compose
**5.3 Implement `$render`/`$reload`** — Re-run template engine / re-fetch document
**5.4 Add lifecycle hooks** — `$show`, `$foreground` via `Lifecycle.Event`
**5.5 Fix color/class parsing** — Same fixes as iOS Phase 1
**5.6 Implement footer** — Material3 `BottomAppBar` or `NavigationBar`

### Phase 6: Web Parity (Priority: P3)

**6.1 Implement `view: "app"`** for mailto/tel links
**6.2 Implement `$snapshot`** across all platforms (if feasible — requires platform-specific screenshot APIs)

## Acceptance Criteria

### Functional Requirements

- [x] Demo.json renders fully on iOS with all colors, styles, and header visible
- [x] "Send yourself Documentation" opens Mail app on iOS
- [x] "View JSON" opens browser/Safari on iOS
- [x] Instagram/Twitter showcase items open as modal sheets on iOS
- [x] Core > Render demo works without crash on iOS
- [x] Views > Header > With header renders without crash on iOS
- [x] `$back`/`$close` navigate correctly on iOS
- [x] Footer tabs render on iOS
- [x] Input components persist values to StateManager on iOS
- [x] `$util.alert` shows native alert on iOS
- [x] `$timer` demos (mario, stopwatch) function on iOS
- [x] Android demo URL points to working GitHub Pages URL
- [ ] Android can navigate between screens

### Non-Functional Requirements

- [x] No force-unwraps in new code
- [ ] All new action handlers have unit tests
- [x] Color parsing has unit tests for hex, rgb(), rgba() formats
- [x] Multi-class resolution has unit tests

### Quality Gates

- [x] `swift test` passes (all existing + new tests)
- [ ] `./gradlew test` passes on Android
- [ ] `npm test` passes on web packages
- [ ] No regressions in existing 56 iOS tests

## UI Testing Plan

### Tier 1: Smoke Tests (All Platforms)

Verify the app launches and renders demo.json without crashing.

| Test | iOS | Android | Web |
|------|-----|---------|-----|
| App launches and shows "Jasonpedia" title | XCUITest | Espresso | Playwright |
| Demo.json sections are visible (Tutorial, Showcase) | XCUITest | Espresso | Playwright |
| Tapping "Core" navigates to core/index.json | XCUITest | Espresso | Playwright |
| Back navigation returns to demo.json | XCUITest | Espresso | Playwright |

### Tier 2: Component Rendering Tests

Verify each component type renders correctly from Jasonpedia fixtures.

| Component | Fixture | Assertions |
|-----------|---------|------------|
| label | `view/component/label.json` | Text content, font, color |
| image | `view/component/image.json` | Image loads, dimensions |
| button | `view/component/button.json` | Tappable, image/text visible |
| textfield | `view/component/textfield.json` | Editable, placeholder visible |
| textarea | `view/component/textarea.json` | Multi-line input works |
| slider | `view/component/slider.json` | Draggable, value updates |
| switch | `view/component/switch.json` | Toggleable |
| space | `view/component/space.json` | Adds vertical spacing |
| vertical layout | `view/layout/vertical.json` | Children stacked vertically |
| horizontal layout | `view/layout/horizontal.json` | Children stacked horizontally |
| nested layout | `view/layout/nested.json` | Deeply nested layouts render |

### Tier 3: Navigation and Transition Tests

| Test | Fixture | Assertions |
|------|---------|------------|
| Push navigation | `core/href/index.json` | New screen pushed, back works |
| Modal transition | `demo.json` → Instagram | Sheet presented, dismiss works |
| `view: "web"` | `demo.json` → View JSON menu | Safari/browser opens |
| `view: "app"` (mailto) | `demo.json` → Send Documentation | Mail app opens (or canOpenURL check) |
| Tab navigation | `core/href/tabs.json` | Tab bar visible, switching works |

### Tier 4: Action and State Tests

| Test | Fixture | Assertions |
|------|---------|------------|
| `$render` with template | `core/render/index.json` | Template renders data into components |
| `$render` with templates | `core/render/templates.json` | Multiple templates resolve |
| `$network.request` | `action/network/index.json` | Data fetched and rendered |
| `$set`/`$get` state | `action/variable/index.json` | State persists across renders |
| `$cache` persistence | `action/variable/index.json` | Values survive app restart |
| `$timer` | `action/timer/stopwatch.json` | Counter increments on interval |
| `$util.alert` | — | Native alert appears |

### Tier 5: Template Engine Integration Tests

| Test | Fixture | Assertions |
|------|---------|------------|
| `{{#each}}` rendering | `template/each.json` | List items rendered from array |
| `{{#if}}` conditional | `template/if.json` | Correct branch rendered |
| Inline template | `template/inline.json` | Template applied inline |
| CSV template | `template/csv.json` | CSV data parsed and rendered |
| Network template | `template/network.json` | Remote data fetched and templated |

### Tier 6: Style and Visual Tests

| Test | Assertions |
|------|------------|
| Hex colors (`#8bb92d`) | Background/text color correct |
| `rgb()` colors | Parsed and applied correctly |
| `rgba()` with opacity | Opacity applied |
| Multi-class (`"bold padded"`) | Both styles merged |
| Header background | Colored header bar visible |
| Padding and corner radius | Spacing and rounding applied |

### Testing Infrastructure Per Platform

**iOS (XCUITest)**:

Add UI test target to Tuist `Project.swift`:

```swift
.target(
    name: "Jasonette-iOS-UITests",
    destinations: [.iPhone, .iPad],
    product: .uiTests,
    bundleId: "com.bande-a-bonnot.jasonette.uitests",
    deploymentTargets: .iOS("16.0"),
    infoPlist: .default,
    sources: ["UITests/iOS/**"],
    dependencies: [.target(name: "Jasonette-iOS")]
),
```

Use launch arguments for stubbed JSON (deterministic, no network):

```swift
// In app: check ProcessInfo for --uitesting-stub, load bundled fixture
// In test:
override func setUp() {
    app.launchArguments = ["--uitesting-stub"]
    app.launch()
}
```

Add `.accessibilityIdentifier()` to all components for test targeting. Use `waitForExistence(timeout:)` for all assertions — never `sleep()`.

For visual regression, add `swift-snapshot-testing` (Point-Free) to the UI test target.

**Android (Compose Testing)**:

```kotlin
@get:Rule val composeTestRule = createComposeRule()

@Test fun homeScreen_displaysItems() {
    composeTestRule.setContent { JasonetteScreen(url = stubURL) }
    composeTestRule.onNodeWithText("Jasonpedia").assertIsDisplayed()
}
```

Use `Modifier.testTag("id")` instead of accessibility identifiers. Compose tests run in-process (5-10x faster than XCUITest).

**Web (Playwright)**:

```typescript
test('renders demo.json', async ({ page }) => {
    await page.route('**/demo.json', route =>
        route.fulfill({ json: stubJSON })
    );
    await page.goto('http://localhost:3000');
    await expect(page.getByText('Jasonpedia')).toBeVisible();
});
```

Playwright has built-in `toHaveScreenshot()` — no third-party library needed.

| Capability | XCUITest | Compose | Playwright |
|---|---|---|---|
| Runs in-process | No | Yes | No |
| Element IDs | `.accessibilityIdentifier()` | `Modifier.testTag()` | `data-testid` |
| Network mocking | Launch args / stub server | Hilt DI | `page.route()` |
| Screenshot testing | swift-snapshot-testing | Built-in | Built-in |
| Speed | Slowest | Fastest | Medium |

## Dependencies & Risks

| Risk | Mitigation |
|------|------------|
| `SFSafariViewController` not available on macOS/tvOS/visionOS | Use `#if canImport(SafariServices)` guard, fall back to `openURL` |
| `UIApplication.shared` not available on macOS | Use `NSWorkspace.shared.open(url)` on macOS, conditional compilation |
| Modal presentation on tvOS limited | Use `fullScreenCover` instead of `sheet` on tvOS |
| Jasonpedia fixtures reference external APIs that may be down | Use local fixture server for CI tests |
| Android navigation rewrite is large scope | Can be deferred to Phase 5 without blocking iOS fixes |

## References

### Internal

- `Sources/Jasonette/Core/ActionDispatcher.swift` — Action handler (most fixes here)
- `Sources/Jasonette/Rendering/JasonetteNavigationView.swift` — Navigation (modal fix)
- `Sources/Jasonette/Components/JasonStyleModifier.swift` — Style system (color/class fix)
- `Sources/Jasonette/Rendering/JasonetteView.swift` — Main view (header/footer fix)
- `packages/web-renderer/src/` — Reference implementation for all features
- `spec/actions.md` — Action catalogue with tier definitions

### Existing Solution Docs

- `docs/solutions/architecture-patterns/reviving-a-decade-old-cross-platform-project.md`
- `docs/solutions/test-failures/tests-pass-but-feature-broken.md`
- `docs/solutions/android-compose-state-hoisting.md`

### Jasonpedia Fixtures Used

- `Jasonpedia/demo.json` — Main demo (exercises most features)
- `Jasonpedia/core/` — Href, render, snapshot
- `Jasonpedia/view/` — Components, layouts, headers, footers
- `Jasonpedia/action/` — Network, timer, variable, script
- `Jasonpedia/template/` — Each, if, inline, CSV, network
