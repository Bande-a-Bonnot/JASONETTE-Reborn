# Jasonette Reborn

## Shell Tools

| Task | Tool |
|------|------|
| Find files | `fd` |
| Find text/strings | `rg` |
| Find code structures | `ast-grep` |
| Select from results | pipe to `fzf` |
| Process JSON | `jq` |
| Process YAML/XML | `yq` |

## Git

Set `SSH_AUTH_SOCK` before any git operation requiring authentication (push, pull, fetch, clone):

```bash
export SSH_AUTH_SOCK=~/.ssh/agent.sock
```

## Conventions

- Favour ast-grep over grep when researching
- Commit often, early and eagerly. Favour atomic commits.
- Use a TDD approach
- Run tests regularly to tighten your feedback loop
- Use UUIDv7 for all IDs. Strictly.

## Key Directories

- `docs/HANDOFF.md` - **Read on new sessions. Update before compaction.** Current state, what works, what's broken, key patterns, file map.
- `docs/plans/` - Implementation plans
- `docs/solutions/` - Documented learnings (27 docs, 11 categories). Search by YAML frontmatter: `module`, `tags`, `problem_type`, `category`
- `todos/` - Pending work items

## iOS Renderer

Build & test: `cd JASONETTE-iOS/JasonetteApp && swift test`

Pipeline: JSON → JasonDocument (Codable) → TemplateEngine → JasonetteViewModel → JasonetteView → ComponentView

### Patterns

- **Three-Place Rule**: New `JasonStyle` properties must go in (1) struct field, (2) `CodingKeys`, (3) `merging()`. Then verify rendering code reads it.
- **ifLet for optional modifiers**: Never pass nil to SwiftUI modifiers like `.foregroundColor()` — nil actively overrides parent values. Use the `ifLet` conditional modifier pattern.
- **strokeBorder not stroke**: `.stroke()` clips half the border outside bounds. `.strokeBorder()` draws inside.
- **Structural elements get dedicated views**: Footer and header are NOT routed through `ComponentView` — they have fixed semantics (anchor to edges, specific sub-elements).
- **Layers are ZStack overlays**: Positioned via `top`/`left`/`bottom`/`right` style properties using alignment + padding, above the ScrollView.

### What's Implemented

- 335 tests, 11 component types, 16 action types (4 stubs: `$get`, `$cache.get`, `$util.toast`, `$util.banner`)
- See `docs/plans/2026-03-28-fix-ios-components-actions-audit-plan.md` for the full audit and remaining Phase B-D work

## Tuist

- Info.plist MUST use `$(MARKETING_VERSION)` and `$(CURRENT_PROJECT_VERSION)` — Tuist `.extendingDefault` hardcodes `1.0`/`1` otherwise
- Version: `MARKETING_VERSION: "2.0.0"`, build number managed by Xcode Cloud
- Team ID: `PKPPLFK854`

## Parallel PR Workflow

When shipping parallel PRs from worktrees, explicitly scope each agent to ONLY its assigned unit — agents will independently duplicate adjacent work otherwise. See `docs/solutions/best-practices/parallel-pr-swarm-with-git-worktrees.md`.
