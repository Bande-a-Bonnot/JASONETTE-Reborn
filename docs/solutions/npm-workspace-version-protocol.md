---
title: "npm Workspaces Version Protocol"
category: configuration-fixes
tags: [npm, workspaces, monorepo, package.json]
module: packages
symptom: "npm install fails with protocol error on workspace:* dependency"
root_cause: "npm does not support pnpm's workspace:* protocol"
---

# npm Workspaces Version Protocol

## Problem

When specifying workspace dependencies in a monorepo, using `workspace:*`
(pnpm protocol) causes npm to fail during install.

## Example

```json
{
  "dependencies": {
    "@jasonette/template-engine": "workspace:*"
  }
}
```

Error: `npm ERR! Invalid version: workspace:*`

## Resolution

Use the actual package version instead. npm workspaces resolve local packages
automatically when the version matches:

```json
{
  "dependencies": {
    "@jasonette/template-engine": "0.1.0"
  }
}
```

npm sees the version matches the local workspace package and resolves it
locally. No protocol prefix needed.
