# AgDR-0094 — Restore the frontier-model pin on Rex/Hakim/Tariq; `model: inherit` was a regression, not a supersession

> In the context of a cost-motivated commit (`b95086c`) that switched Rex, Hakim, and Tariq from `model: opus` to `model: inherit`, facing a direct conflict with AgDR-0087's live-evidence frontier-floor requirement and AgDR-0089's eval methodology (both premised on these three agents staying pinned), I decided **to restore `model: opus` on all three gate-critical reviewer agents**, to keep the merge-gate review floor at the level the framework's own evidence says it needs to be, accepting the per-review cost `model: inherit` was trying to avoid.

## Context

An xhigh multi-agent review of the ops fork's own `chore/GH-1-rex-csharp-angular-discovery` branch (2026-07-20) surfaced that `b95086c` ("chore: align reviewer agents to framework-default model: inherit") switched `code-reviewer.md`, `security-reviewer.md`, and `solution-architect.md` from `model: opus` to `model: inherit` — meaning these three now silently run on whatever model the orchestrating session happens to be using, rather than always on the framework's strongest available model.

This directly contradicts two standing decisions:

- **AgDR-0087** — reasoning-layer agents (Rex/Hakim/Tariq/Naqid) require a frontier-model floor. Live evidence: a real merged security-relevant PR (#793, a fail-closed CI-gate fix) fed to a strong local model missed the one load-bearing security question the review checklist asked it to check, raising only generic nitpicks instead — "a fluent-but-incomplete review that looks thorough while missing the actual risk is a worse failure mode for a merge-gate reviewer than a visible timeout."
- **AgDR-0089** — the eval-agents methodology explicitly relies on Rex/Hakim/Tariq being opus-pinned for run-to-run reproducibility ("no model is credibly stronger than the opus-pinned agents being measured").

`security-reviewer.md`'s own file-level comment (line 2) independently confirms `opus` was AgDR-0050's original, deliberate value for this exact agent ("AgDR-0050 § Axis 2 promotes Hakim ... from the v0 inherit baseline to opus for OWASP / threat-model depth") — so `inherit` was reverting a prior considered decision, not applying a new one.

`b95086c` was a real, deliberate choice (recorded separately as user preference — see the operator's own memory note on reviewer-agent cost) aimed at avoiding the cost of always running Opus for a review. That intent is legitimate but was applied too broadly: it landed on the three specific agents the framework's merge/security/architecture gates depend on, not on a lower-stakes role where a capability dip is tolerable.

## Options Considered

| Option | Pros | Cons |
|--------|------|------|
| (a) Leave `model: inherit` as-is | Cheapest; matches the operator's stated cost preference | Contradicts AgDR-0087's live evidence and AgDR-0089's reproducibility premise; a session running on Sonnet/Haiku/a local fallback silently drops the merge-gate review below the documented floor with no warning anywhere in the gate hooks |
| (b) Restore `model: opus` on all three | Matches AgDR-0087/0089's requirements exactly; closes the gap the xhigh review found; the merge gate's review quality no longer depends on which model happened to be driving the orchestrator | Reintroduces the per-review Opus cost `b95086c` was trying to avoid |
| (c) Split the difference — `inherit` with an explicit minimum-tier floor | Would preserve some savings on already-strong sessions | Not expressible in the current agent frontmatter schema (`model:` is a literal name or `inherit`, no floor/minimum concept); would require harness changes out of scope here |

## Decision

Chosen: **(b) — restore `model: opus`** on `code-reviewer.md` (Rex), `security-reviewer.md` (Hakim), and `solution-architect.md` (Tariq).

AgDR-0087's evidence is concrete (a real missed security risk, not a hypothetical), and these three agents sit directly in front of the merge gate, the security gate, and the architecture gate — exactly the roles AgDR-0087 named as non-negotiable. Naqid (`contrarian.md`) was already unaffected and stays `opus`. The cost-saving intent behind `b95086c` is not rejected outright — it simply doesn't apply to gate-critical reviewers; a future AgDR is free to apply `inherit` (or a cheaper explicit pin) to a genuinely low-stakes, non-gating agent role if one is identified.

## Consequences

- Rex, Hakim, and Tariq run on Opus regardless of which model drives the orchestrating session — the merge/security/architecture gates keep a constant review-quality floor.
- The MeterTracker wave-1 Rex reviews already completed in the affected window (this session, prior to this fix) ran under `inherit`; they are not retroactively invalidated here since wave-1 was mechanical/zero-behaviour-change and non-security, but the upcoming security Must-fix wave (2 confirmed live auth vulnerabilities) MUST run its Rex/Hakim reviews after this fix lands, not before.
- Per-review cost returns to the pre-`b95086c` baseline for these three agents.
- Discovery gap findings from the same xhigh review (the `handbooks/language/dotnet/` bucket never wired into Rex's discovery script; `handbooks/README.md`'s stale "fifth bucket" count; the `.sql`-only diff gap for two SQL-scoped csharp handbooks) were fixed in the same pass as this AgDR — see the accompanying commit.

## Artifacts

- Superseded-in-scope commit: `b95086c` ("chore: align reviewer agents to framework-default model: inherit")
- Controlling prior decisions: [AgDR-0087](AgDR-0087-reasoning-agents-require-frontier-model.md), [AgDR-0089](AgDR-0089-eval-agents-methodology.md), [AgDR-0050](AgDR-0050-agent-runtime-overhaul.md) § Axis 2
- Discovered via: xhigh multi-agent code-review workflow run against `chore/GH-1-rex-csharp-angular-discovery` (2026-07-20)
