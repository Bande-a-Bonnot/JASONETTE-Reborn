---
title: "fix: Horizontal layout components scroll vertically instead of horizontally"
type: fix
date: 2026-03-18
---

# Fix Horizontal Scroll Direction

## Overview

`type: "horizontal"` components render as a plain `HStack` inside the page's vertical `ScrollView`. When content overflows, it gets clipped or pushed vertically rather than scrolling horizontally as expected.

## Root Cause

`LayoutView.swift` renders the `.horizontal` case as a bare `HStack`. This `HStack` sits inside `JasonetteView.documentBody`'s vertical `ScrollView > LazyVStack`, so overflow follows the parent's vertical scroll axis.

## Fix

Wrap the `HStack` in `ScrollView(.horizontal, showsIndicators: false)` in `LayoutView.swift`.

## Acceptance Criteria

- [x] Horizontal layouts scroll horizontally
- [x] Vertical layouts unchanged
- [x] Tests pass
- [x] Simulator verification
