---
status: pending
priority: p1
issue_id: "002"
tags: [code-review, security, navigation]
dependencies: []
---

# Navigation `default` Branch Does Not Validate URL Scheme

## Problem Statement

`JasonetteNavigationView.handleNavigation` validates URL schemes for `"web"` and `"app"` view types, but the `default` branch (push / modal navigation) performs no scheme check. A `javascript:`, `data:`, or `file:` URL in an `href` will enter the navigation stack before being rejected by `DocumentLoader`. The defence should be at the entry point, not deferred to the loader.

## Findings

In `JasonetteViewModel.handleHref`, the URL is constructed and posted as a notification with no scheme validation:
```swift
guard let urlStr = href.url, let url = URL(string: urlStr) else { return }
NotificationCenter.default.post(name: .jasonetteNavigate, ...)
```

In `JasonetteNavigationView.handleNavigation`, the `default:` branch calls `path.append(url)` / sets `modalURL` with no scheme check. The URL goes to `JasonetteView(url:)` → `DocumentLoader.load(from:)` which *does* validate, but the invalid URL has already entered the navigation system.

## Proposed Solutions

### Option A: Validate in `handleHref` before posting notification (recommended)

```swift
guard let urlStr = href.url,
      let url = URL(string: urlStr),
      let scheme = url.scheme?.lowercased(),
      ["http", "https"].contains(scheme) else { return }
```
- Pros: Single validation point, defence-in-depth, prevents any invalid URL from entering the notification system
- Cons: None

### Option B: Validate in `JasonetteNavigationView.handleNavigation` `default` branch

Add the same scheme check before `path.append(url)`.
- Pros: Closer to the navigation stack
- Cons: Two validation points to maintain (here and in `DocumentLoader`)

## Recommended Action

Option A — validate in `handleHref` in `JasonetteViewModel`.

## Technical Details

- **Affected files:** `Rendering/JasonetteViewModel.swift` (handleHref method)
- **Effort:** Small

## Acceptance Criteria

- [ ] `href` with `file://` URL is silently ignored (no navigation, no crash)
- [ ] `href` with `javascript:` URL is silently ignored
- [ ] `href` with `https://` URL navigates correctly
- [ ] Test: `testHandleHrefWithFileURLIsIgnored`
- [ ] Test: `testHandleHrefWithJavascriptURLIsIgnored`

## Work Log

- 2026-03-12: Identified by security-sentinel agent during code review of PR fix/testflight-crashes-and-component-tests
