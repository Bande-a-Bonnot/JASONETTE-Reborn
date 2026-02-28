---
title: "CLI binary declared in package.json but never compiled from TypeScript source"
category: build-errors
tags: [esbuild, cli, typescript, vite, package-json-bin]
module: web-renderer
symptom: "Running `node packages/web-renderer/bin/cli.js` fails with MODULE_NOT_FOUND despite tests passing"
root_cause: "Build script produced library bundle and type declarations only; no step compiled the CLI entry point from src/cli.ts to bin/cli.js"
---

# CLI Binary Not Compiled

## Problem

The `web-renderer` package declared a CLI binary in `package.json`:

```json
{
  "bin": {
    "jasonette": "./bin/cli.js"
  }
}
```

However, `bin/cli.js` was never compiled from the TypeScript source at `src/cli.ts`. Attempting to run the CLI after a build produced:

```
node packages/web-renderer/bin/cli.js validate file.json
# Error: Cannot find module '...'
# code: 'MODULE_NOT_FOUND'
```

Tests gave no indication of the problem because vitest handles TypeScript natively --- it never needs a compiled JS artifact to exercise the CLI logic.

## Why It Went Undetected

1. **vitest transpiles on the fly.** Test files import `src/cli.ts` directly. vitest uses esbuild internally to handle TypeScript, so the source is never required to exist as compiled JS for tests to pass.
2. **The build script had a blind spot.** The existing build pipeline did two things and two things only:
   - `vite build` --- produced the library bundle in `dist/`.
   - `tsc --emitDeclarationOnly` --- produced `.d.ts` type declarations.
   Neither step targeted `src/cli.ts` as a standalone entry point destined for `bin/`.
3. **tsconfig.cli.json was set to `noEmit: true`.** Even if someone assumed tsc was handling the CLI, that config explicitly told the compiler to emit nothing.

The gap: the package advertised a binary it could never deliver.

## Root Cause

The build script:

```json
"build": "vite build && tsc --emitDeclarationOnly"
```

produced only the library bundle (`dist/`) and type declarations. There was no compilation step for the CLI entry point. The TypeScript config for the CLI (`tsconfig.cli.json`) had `"noEmit": true`, which meant even a targeted `tsc` invocation against that config would produce no output.

## Solution

### 1. Add a dedicated CLI build step using esbuild

```json
"build:cli": "esbuild src/cli.ts --bundle --platform=node --format=esm --outfile=bin/cli.js --packages=external"
```

Key flags:

| Flag | Purpose |
|------|---------|
| `--bundle` | Inline local imports so `bin/cli.js` is self-contained |
| `--platform=node` | Target Node.js (resolves `node:` built-ins correctly) |
| `--format=esm` | Emit ESM to match the package's module format |
| `--outfile=bin/cli.js` | Write directly to the declared `bin` path |
| `--packages=external` | Do not bundle `node_modules` dependencies; let Node resolve them at runtime |

### 2. Chain the new step into the main build

```json
"build": "vite build && tsc --emitDeclarationOnly && cp src/jasonette.css dist/jasonette.css && npm run build:cli"
```

The CLI build runs last because it has no downstream dependents in the pipeline, and running it after the library build ensures the `dist/` assets it may reference are already in place.

## Gotcha: esbuild Duplicates Shebangs

If `src/cli.ts` already starts with:

```typescript
#!/usr/bin/env node
```

and you also pass `--banner:js='#!/usr/bin/env node'` to esbuild, the output will contain **two** shebangs:

```
#!/usr/bin/env node
#\!/usr/bin/env node
```

The second line (with the escaped `!`) is not a valid shebang --- it is treated as JavaScript, which causes:

```
SyntaxError: Invalid or unexpected token
```

**Rule:** Do not use `--banner:js` to inject a shebang if the source file already contains one. esbuild preserves the original shebang from the source automatically.

## Additional Issue: Dev Server Asset Resolution

After the CLI compiled successfully, the dev server it spawned could not find the renderer's JS and CSS bundles. The cause: the CLI resolved assets relative to `import.meta.dirname`, which points to `bin/`. The built assets live in `dist/`.

**Before (broken):**

```typescript
const assetPath = resolve(import.meta.dirname, asset);
// Resolves to: packages/web-renderer/bin/jasonette.js --- does not exist
```

**After (fixed):**

```typescript
const distDir = resolve(import.meta.dirname, '..', 'dist');
const assetPath = resolve(distDir, asset);
// Resolves to: packages/web-renderer/dist/jasonette.js --- correct
```

Using a relative traversal from the CLI's own location (`import.meta.dirname`) to the sibling `dist/` directory keeps the resolution stable regardless of the working directory the user invokes the CLI from.

## Prevention

1. **End-to-end CLI smoke test in CI.** After the build step, run the actual compiled binary against a known-good input:
   ```yaml
   - run: npm run build
   - run: node packages/web-renderer/bin/cli.js validate fixtures/minimal.json
   ```
   This catches any MODULE_NOT_FOUND or shebang errors that unit tests will never surface.

2. **Treat `bin/` entries as first-class build outputs.** Any path declared under `"bin"` in `package.json` must have a corresponding build step that produces it. Audit this whenever adding a new CLI command.

3. **Do not rely solely on vitest for CLI correctness.** vitest's transparent TypeScript handling is a feature for development speed, but it masks the difference between "the code logic works" and "the shipped artifact works." Both must be verified.
