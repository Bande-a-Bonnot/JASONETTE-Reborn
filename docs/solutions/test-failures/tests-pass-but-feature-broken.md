---
title: "Tests Pass but Feature Is Broken"
category: test-failures
tags: [testing, e2e, false-positive, cli, vitest, typescript]
module: web-renderer
symptom: "All 198 tests pass, vite build succeeds, but the shipped CLI binary crashes with MODULE_NOT_FOUND"
root_cause: "Tests exercised TypeScript source via vitest/tsx, never the compiled JavaScript binary that users actually run"
---

# Tests Pass but Feature Is Broken

## Problem

All 198 tests passed (140 template-engine + 58 web-renderer). The vite build
succeeded. Every implementation phase was marked complete. But when asked the
simplest possible question — "does it work?" — the actual CLI binary was
completely broken:

```
$ jasonette validate example.json
Error: Cannot find module '/path/to/bin/cli.js'
    at Module._resolveFilename (node:internal/modules/cjs/loader:...)
    ...
MODULE_NOT_FOUND
```

`bin/cli.js` was never compiled. The file did not exist on disk. The package
shipped a binary entry point that pointed to nothing.

## Why the Tests Didn't Catch It

The CLI test suite used `execSync` to invoke the CLI:

```typescript
// What the tests actually ran:
execSync('npx tsx src/cli.ts validate fixtures/valid.json');
```

This worked because:

1. **vitest** handles TypeScript natively via esbuild transforms — no
   compilation step needed.
2. **tsx** (`npx tsx src/cli.ts`) executes TypeScript source directly — again,
   no compiled output required.

The tests never touched `bin/cli.js`. They never needed it to exist. They
verified that the CLI logic was correct, but they did not verify that the
deliverable artifact was functional.

## The Pattern: Tests-Pass-but-Broken

This is a general failure mode, not specific to CLIs. It occurs whenever:

1. **The test harness has capabilities the runtime does not.** vitest/esbuild
   can import TypeScript. Node.js cannot. The test harness silently papered
   over a missing build step.

2. **Tests exercise code through the harness, not through the delivery
   mechanism.** The tests imported source files and invoked `tsx`. Users run
   `node bin/cli.js`. These are different execution paths with different
   requirements.

3. **All tests pass, CI is green, the artifact is broken.** There is no test
   that fails. There is no signal that anything is wrong. Confidence is high.
   The shipped product does not work.

Other instances of this pattern:

| What you test | What you ship | What breaks |
|---|---|---|
| `npx tsx src/cli.ts` | `node bin/cli.js` | Binary not compiled |
| `import { render } from '../src/index.ts'` | `import { render } from 'jasonette'` | dist bundle missing or malformed |
| `npm run dev` | Docker image | Missing env vars, wrong node version, missing native deps |
| vitest with jsdom | Real browser | API differences, missing polyfills |

## The Key Insight

The question "does it work?" is fundamentally different from "do the tests
pass?"

- **"Do the tests pass?"** verifies individual behaviors in isolation, under
  controlled conditions, through a test harness.
- **"Does it work?"** verifies the integrated, built, packaged, deployed,
  end-to-end experience that a user actually encounters.

Both are necessary. Neither is sufficient alone. A codebase with 100% test
coverage and a green CI pipeline can still ship a binary that crashes on
launch.

## Solution

Test the actual artifact, not just the source.

### For a CLI

Test the compiled binary, not the TypeScript source:

```typescript
// ❌ Tests the source — proves the logic works, not the binary
execSync('npx tsx src/cli.ts validate fixtures/valid.json');

// ✅ Tests the artifact — proves what users will actually run
execSync('node bin/cli.js validate fixtures/valid.json');
```

This requires a build step before the test runs. That is the point. If the
build is broken, the test fails. If the binary is missing, the test fails.

### For a library

Test the dist bundle, not the src import:

```typescript
// ❌ Source import — vitest resolves TypeScript directly
import { render } from '../src/index.ts';

// ✅ Dist import — tests what consumers will actually get
import { render } from '../dist/index.js';
```

### For a server

Test the built image, not the dev server:

```bash
# ❌ Dev server — has different middleware, hot reload, TypeScript support
npm run dev

# ✅ Production image — tests the actual deployment artifact
docker build -t app . && docker run -p 3000:3000 app
curl http://localhost:3000/health
```

## Prevention

### 1. Add a smoke test that runs the compiled binary

A single test that builds and then executes the real artifact:

```typescript
import { execSync } from 'node:child_process';

describe('CLI smoke test', () => {
  beforeAll(() => {
    execSync('npm run build', { cwd: packageRoot });
  });

  it('compiled binary runs without error', () => {
    const result = execSync('node bin/cli.js --help', {
      cwd: packageRoot,
      encoding: 'utf-8',
    });
    expect(result).toContain('Usage:');
  });

  it('validates a known-good file', () => {
    const result = execSync(
      'node bin/cli.js validate fixtures/valid.json',
      { cwd: packageRoot, encoding: 'utf-8' },
    );
    expect(result).toContain('valid');
  });
});
```

### 2. Test the packaged artifact

Simulate what `npm install -g` does:

```bash
npm run build
npm pack
npm install -g ./jasonette-web-renderer-*.tgz
jasonette --help
jasonette validate fixtures/valid.json
```

If any step fails, the package is not shippable.

### 3. Separate test tiers in CI

```yaml
jobs:
  unit-tests:
    # Fast, run on every push
    run: vitest run

  build:
    # Compile TypeScript, bundle with vite
    run: npm run build

  smoke-tests:
    needs: build
    # Run against the compiled output
    run: node bin/cli.js --help && node bin/cli.js validate fixtures/valid.json

  e2e-tests:
    needs: build
    # Full end-to-end against the packaged artifact
    run: |
      npm pack
      npm install -g *.tgz
      jasonette validate fixtures/valid.json
      jasonette serve fixtures/ &
      curl --retry 5 --retry-delay 1 http://localhost:3000
```

## Checklist

When declaring a feature "done," verify:

- [ ] Unit tests pass (`vitest run`)
- [ ] Build succeeds (`npm run build`)
- [ ] Compiled binary exists and runs (`node bin/cli.js --help`)
- [ ] Packaged artifact installs and works (`npm pack && npm install -g *.tgz`)
- [ ] The answer to "does it work?" is yes — not "the tests pass"
