# Repo-gated `language/angular/` handbook bucket

> In the context of wiring Rex to load the new C#/.NET + Angular coding-standard handbooks, facing the fact that Angular code shares its file extensions (`.ts` / `.html`) with React, Next.js and NestJS, I decided to add a dedicated `language/angular/` bucket gated on the repo actually being an Angular project, to achieve precise handbook targeting, accepting a small exception to the otherwise extension-only discovery convention.

## Context

The private custom-handbooks now include `language/csharp/` and `language/angular/` buckets. Rex's handbook discovery (`.claude/agents/code-reviewer.md` § 8) matches `language/<lang>/` buckets by file extension — `typescript/` → `**/*.{ts,tsx}`, `python/` → `**/*.py`, etc.

C# maps cleanly: `.cs` is unambiguous, so `csharp/` → `**/*.cs` follows the existing convention with no special handling.

Angular does not. Angular components are `.ts` + `.html` — the same extensions used by React, Next.js and NestJS repos elsewhere in the portfolio. A naive `angular/` → `**/*.{ts,html}` match would load Angular-specific rules (signals, `@if`/`@for`, standalone, OnPush, Transloco, Tailwind) on every TypeScript PR in *any* repo, producing false-positive findings on non-Angular codebases and training the operator to ignore the layer.

## Options Considered

| Option | Pros | Cons |
|--------|------|------|
| Put Angular rules under `language/typescript/` | Zero new logic; pure convention | Fires on ALL `.ts` — React/Next/Nest included. False positives everywhere. |
| **Dedicated `language/angular/`, repo-gated** | Precise — loads only on Angular repos; deterministic | One bucket is no longer pure-extension; adds a repo-shape check to the shell |
| Semantic (MCP) discovery only | No shell edit, no fork divergence | Best-effort, non-deterministic (top-K by score); won't reliably fire per PR |

## Decision

Chosen: **dedicated `language/angular/` bucket, repo-gated**, because Angular rules must apply to Angular code only, and the repo-shape signal (an `angular.json` outside `node_modules`, or `@angular/core` in a `package.json`) is a cheap, reliable discriminator that a bare extension match can't provide. The bucket loads when the diff touches `**/*.{ts,html}` **and** the repo is an Angular project.

## Consequences

- Angular handbooks load on Angular repos only; React/Next/Nest TypeScript PRs are unaffected.
- The `angular/` bucket is the one documented exception to extension-only matching — recorded in the discovery tables in `code-reviewer.md` and `handbooks/README.md`.
- The discovery shell gains a repo-shape probe (`find angular.json` / `grep @angular/core`) for that bucket.
- This is a fork-local customization to `code-reviewer.md`; it may require conflict resolution when syncing from upstream via `/update`.

## Artifacts

- KaEssam/apexyard#1
- Discovery shell + tables: `.claude/agents/code-reviewer.md` § 8; `handbooks/README.md`
