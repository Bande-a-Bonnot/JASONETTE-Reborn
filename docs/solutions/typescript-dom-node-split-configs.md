---
title: "Split TypeScript Configs for DOM and Node Code"
category: configuration-fixes
tags: [typescript, tsconfig, dom, node, cli]
module: web-renderer
symptom: "TypeScript errors about missing node:fs or process in browser code"
root_cause: "Single tsconfig includes both DOM (browser) and Node (CLI) files"
---

# Split TypeScript Configs for DOM and Node Code

## Problem

A package that has both browser code (renderer) and Node code (CLI) cannot
use a single tsconfig. Browser code needs `lib: ["DOM"]` but not `@types/node`.
Node code needs `@types/node` but not DOM types.

## Resolution

Create two tsconfig files:

**tsconfig.json** (browser code — default):

```json
{
  "compilerOptions": {
    "lib": ["ES2022", "DOM", "DOM.Iterable"]
  },
  "include": ["src/**/*.ts"],
  "exclude": ["src/cli.ts"]
}
```

**tsconfig.cli.json** (Node CLI code):

```json
{
  "compilerOptions": {
    "types": ["node"],
    "lib": ["ES2022"],
    "noEmit": true
  },
  "include": ["src/cli.ts"]
}
```

In CI, typecheck both:

```bash
tsc --noEmit               # Browser code
tsc -p tsconfig.cli.json   # CLI code
```
