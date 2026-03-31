---
status: ready
priority: p3
issue_id: "016"
tags: [docs, solution-doc, code-review]
dependencies: []
---

# Version Number Inconsistency in Accent Character Solution Doc

## Problem Statement
In `docs/solutions/integration-issues/xcode-cloud-accent-character-team-name-crash.md`, line 67 states `CFBundleShortVersionString=1.0` but line 64 shows `MARKETING_VERSION: "0.1.0"`. These should be consistent.

## Findings
- Location: `docs/solutions/integration-issues/xcode-cloud-accent-character-team-name-crash.md:64-67`
- The "Before" code block shows `MARKETING_VERSION: "0.1.0"` but the comment says `CFBundleShortVersionString=1.0`
- The comment describes the original hardcoded state, while the code block shows the Tuist config — they're documenting different things but it reads as contradictory

## Recommended Action
Clarify the comment to distinguish between the Info.plist hardcoded value (1.0) and the Tuist build setting (0.1.0), or align them.

## Acceptance Criteria
- [ ] Version references in the solution doc are consistent or clearly distinguished

## Notes
Source: CodeRabbit review on PR #13, 2026-03-30
