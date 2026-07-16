# Fork tracks upstream main closely — drop the removed site tree

> In the context of a split-portfolio ops fork of `me2resh/apexyard` whose operator wants low-friction updates, facing a 39-file delta against `upstream/main` that made every `/update` conflict, I decided to delete upstream's removed `site/` tree and its CI, and to restore the two READMEs upstream still ships, to achieve near-fast-forward upstream merges, accepting that this fork can no longer build the apexyard marketing site and that a small necessary delta remains.

## Context

The fork was upgraded v3.3.0 → v5.0.0. The operator's stated goal is to *follow upstream's main* so staying up to date is easy.

Update friction is a direct function of fork delta: every tracked file that differs from upstream is a potential conflict on every merge. The delta measured 39 files, but 27 of them were **upstream's own marketing website** — `site/*` (24 pages), `netlify.toml`, `.github/workflows/site-counts-check.yml`, `.github/workflows/link-check.yml`, and a 269-line `.claude/hooks/tests/test_site_counts.sh`.

Upstream **deleted `site/` after v3.3.0**; `upstream/main` at v5.0.0 contains zero `site/` files. The fork kept them through the merge, so it now carries a tree the framework itself threw away. The fork had also deleted `projects/README.md` and `workspace/README.md` during its split-portfolio migration — but `/update`'s own step 8a states `workspace/README.md` is a framework artefact that should stay in the public fork, so those deletions were over-reach and are themselves delta.

Numbering note: this AgDR uses a **9000+ range**. Upstream is at AgDR-0092 and climbing; fork-local decisions in the 9000s can never collide with an upstream number.

## Options Considered

| Option | Pros | Cons |
|--------|------|------|
| Drop all 27 site files + restore the 2 READMEs | Delta 39 → ~8 files, nearly all small; updates approach fast-forward; removes a tree upstream already deleted | Fork can no longer build/deploy the apexyard site |
| Drop `site/` only, keep `netlify.toml` + workflows | Retains deploy config if the site is ever revived | The CI checks reference files that no longer exist and would fail on every run; keeps ~3 files of pointless delta |
| Keep everything | Zero work now | Every future `/update` re-conflicts in the same places; the cost recurs forever and grows |

## Decision

Chosen: **drop all 27 site-related files and restore `projects/README.md` + `workspace/README.md` from upstream**, because the site tree delivers no value to an adopter fork (it is upstream's marketing site, already deleted upstream), while costing conflict friction on every update — which is precisely the thing the operator asked to make easy.

## Consequences

- Fork delta drops from 39 files to roughly 8; future upstream merges stay close to fast-forward.
- This fork can no longer build or deploy a copy of the apexyard marketing site. Accepted: it was never deployed from here.
- Everything removed stays recoverable from git history, and from `upstream` at any tag ≤ v3.3.0.
- The residual delta is deliberate and must stay:

  | File | Why it must differ |
  |------|--------------------|
  | `.claude/project-config.json` | The `portfolio` block pointing at the sibling private repo. Tracked upstream, so it will conflict occasionally — unavoidable in split-portfolio mode. |
  | `.claude/framework-version` | The v5.0.0 migration anchor. Not tracked upstream. |
  | `.gitignore` | Split-portfolio lines + `openapi.json` (keeps a managed project's generated API spec out of this **public** fork). |
  | 6 hook/skill patches (~30 lines) | Local fixes, incl. the Windows CR-strip fix in `_lib-read-config.sh`. |

- The hook patches will conflict whenever upstream touches those files. Evidence from the v5 merge suggests this shrinks over time: upstream had independently fixed two of them (`remind-mcp-tools.sh`, `validate-pr-create.sh`), and generalised the fork's cd-target fix into a shared `pr_cmd_cd_target()` library — so those local patches were dropped in favour of upstream's.

## Artifacts

- Ticket: `KaEssam/apexyard-portfolio#1`
- Upstream removal of `site/`: last touched at `5b61952` (v3.3.0); absent from `upstream/main` at v5.0.0
- Merge commit: `0b9dfec` (v3.3.0 → v5.0.0)
