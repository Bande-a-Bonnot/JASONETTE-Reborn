---
title: "Vite library mode does not bundle standalone CSS files"
category: build-errors
tags: [vite, css, library-mode, build]
module: web-renderer
symptom: "CLI dev server returns 404 for /__jasonette__/jasonette.css because the CSS file is missing from dist/"
root_cause: "Vite library mode only bundles JS entry points; standalone CSS files not imported in the JS entry are silently excluded from the output"
---

# Vite Library Mode Does Not Bundle Standalone CSS Files

## Symptom

After building the web renderer package with `vite build`, the CLI dev server serves
assets from `dist/` under the `/__jasonette__/` route. Requests for
`/__jasonette__/jasonette.css` return **404 Not Found** even though the source file
`src/jasonette.css` exists and the page's `<link>` tag references it correctly.

The JS bundle appears in `dist/` as expected. Only the CSS is missing.

## Investigation

Inspecting the `dist/` directory after a build confirms no `.css` file is present:

```
dist/
  jasonette.js
  jasonette.umd.cjs
```

The Vite config uses library mode:

```ts
// vite.config.ts
export default defineConfig({
  build: {
    lib: {
      entry: 'src/index.ts',
      name: 'Jasonette',
      formats: ['es', 'umd'],
    },
  },
});
```

The JS entry point (`src/index.ts`) exports only JS modules and does **not** import the
CSS file. Vite's library mode processes the dependency graph starting from the configured
entry point. Anything outside that graph -- including standalone CSS files sitting next to
the entry -- is ignored entirely. There is no warning or error; the file is simply absent
from the output.

## Root Cause

Vite's `build.lib` configuration bundles the JS entry and its transitive JS/TS imports.
Standalone CSS files that are not part of the import graph are **not** copied, processed,
or referenced in the output. This is by design: library mode assumes the entry point
fully describes what should be built.

## Solution

Add an explicit copy step to the build script so that the CSS file is always present in
`dist/` alongside the JS bundles:

```json
{
  "scripts": {
    "build": "vite build && tsc --emitDeclarationOnly && cp src/jasonette.css dist/jasonette.css && npm run build:cli"
  }
}
```

This keeps the CSS as a standalone distributable file, which is the desired outcome for
Jasonette.

## Alternative Approaches Considered

### 1. Import CSS in the JS entry point

```ts
// src/index.ts
import './jasonette.css';
```

Vite would detect the import and extract the CSS into a separate file in `dist/`.
However, this couples the CSS to the JS bundle and forces every consumer to configure
CSS extraction or handling in their own build toolchain. Rejected because it shifts
complexity onto consumers.

### 2. Use `vite-plugin-css-injected-by-js`

This plugin inlines the CSS into the JS bundle and injects it into the DOM at runtime
via a `<style>` tag. It eliminates the need for a separate CSS file entirely, but adds
runtime overhead and makes it harder for consumers to inspect or override styles.
Rejected because it conflicts with the goal of keeping CSS independently customisable.

### 3. Use a Rollup copy plugin (`rollup-plugin-copy`)

```ts
import copy from 'rollup-plugin-copy';

export default defineConfig({
  plugins: [
    copy({
      targets: [{ src: 'src/jasonette.css', dest: 'dist' }],
    }),
  ],
});
```

Works correctly but introduces an additional dependency and config surface for what
amounts to a single file copy. Rejected in favour of the simpler shell command.

## Why CSS Is Intentionally Separate

In Jasonette, the CSS file is a first-class distributable artifact, not an implementation
detail of the JS bundle. Consumers may want to:

- Override specific styles without forking the package.
- Load the CSS from a CDN independently of the JS.
- Inline the CSS into a server-rendered HTML shell.
- Skip the default styles entirely and provide their own.

Keeping CSS out of the JS import graph preserves all of these options. The explicit `cp`
in the build script is the simplest mechanism that maintains this separation.

## Key Takeaway

Vite library mode builds exactly what the JS entry point imports -- nothing more. If a
file needs to appear in `dist/` but is not part of the JS dependency graph, you must
arrange for it to get there yourself, whether through a shell command, a copy plugin, or
a post-build script.
