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

- `docs/plans/` - Implementation plans
- `docs/solutions/` - Documented learnings
- `todos/` - Pending work items
