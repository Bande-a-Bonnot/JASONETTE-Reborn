---
title: "jsdom Test Quirks for Web Renderer"
category: testing
tags: [jsdom, vitest, dom, web-renderer]
module: web-renderer
symptom: "Test assertions fail despite correct implementation"
root_cause: "jsdom normalizes URLs, expands CSS shorthands, and handles storage differently"
---

# jsdom Test Quirks for Web Renderer

## Problem

When testing DOM manipulation in vitest with jsdom environment, several
assertions fail even though the implementation is correct.

## Quirks Found

### 1. URL Normalization

jsdom adds a trailing slash to URLs:

```typescript
// ❌ Fails — jsdom normalizes to 'https://img.png/'
expect(img.src).toBe('https://img.png');

// ✅ Works
expect(img.src).toContain('https://img.png');
```

### 2. CSS Shorthand Expansion

Setting `flex: '1'` expands to `flex: 1 1 0%`:

```typescript
el.style.flex = '1';

// ❌ Fails — jsdom expands shorthands
expect(el.style.flex).toBe('1');

// ✅ Works
expect(el.style.flex).toContain('1');
```

### 3. localStorage Warnings

jsdom warns about localStorage without a storage file path. This is harmless
but clutters test output. No fix needed — just ignore the warning.

## Resolution

Use `toContain()` instead of `toBe()` for URL and CSS shorthand assertions.
