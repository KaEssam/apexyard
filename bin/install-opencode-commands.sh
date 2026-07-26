#!/usr/bin/env bash
# Install the apexyard opencode skill-parity shims into a project's local
# `.opencode/commands/` directory — one `<skill-name>.md` per
# `.claude/skills/<name>/SKILL.md`, each a thin re-export that embeds the
# SKILL.md via opencode's `@` file-reference and forwards `$ARGUMENTS`.
#
# WHY THIS SCRIPT EXISTS
# ----------------------
# opencode (opencode.ai) is one of apexyard's three supported harnesses. The
# gate adapter (`bin/install-opencode-adapter.sh`, AgDR-0092) already bridges
# the MECHANICAL gates (merge block, ticket-first, secrets, red-CI, AgDR) by
# shelling out to the unmodified `.claude/hooks/*.sh` on `tool.execute.before`.
# But apexyard's 64 `.claude/skills/*/SKILL.md` are NOT surfaced as opencode
# `/commands` — under Claude Code each SKILL.md becomes a typed slash command
# (`/feature`, `/handover`, `/projects`, `/inbox`, `/code-review`,
# `/approve-merge`, ...); under opencode the adopter had to manually `Read`
# each SKILL.md and tell the model to follow it. So opencode was at parity
# with Claude Code for enforcement, but NOT for workflow invocation.
#
# This script closes that gap mechanically: it generates one
# `.opencode/commands/<name>.md` shim per skill. The shim's body uses
# opencode's `@<path>` reference (see opencode docs/commands) to embed the
# SKILL.md content into the prompt and `$ARGUMENTS` to forward parameters, so
# the SKILL.md stays the single source of truth — a skill update needs no
# shim change, only a re-run of this script (which is idempotent).
#
# WHAT THIS SCRIPT DOES NOT DO
# ----------------------------
# It does not duplicate skill logic, rewrite SKILL.md content, or copy any
# hook. It is purely a redirect/vocabulary bridge — the same "thin transport"
# shape the gate adapter (AgDR-0092) and the Codex adapter (AgDR-0088)
# already established for their respective concerns. Per-skill `subtask`
# tuning (whether heavy audit skills like `/launch-check` should force a
# subagent to keep the primary context clean) is deliberately left unset in
# v1 — opencode picks per its agent config; see AgDR-0095 for the deferred
# decision and the follow-up it names.
#
# Sibling of `bin/install-opencode-adapter.sh` (gates) and
# `bin/install-pi-adapter.sh` (pi-flavored gate transport). Run BOTH the
# adapter script AND this one for full opencode === Claude Code parity.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TARGET_DIR=""
SKILLS_DIR=""

usage() {
  cat <<'USAGE'
Usage: bin/install-opencode-commands.sh [--target-dir <path>] [--skills-dir <path>] [--root <path>]

Generates one opencode `/command` shim per .claude/skills/<name>/SKILL.md
into <target-dir>/, the directory opencode scans for custom commands. Each
shim embeds its SKILL.md via opencode's @ file-reference and forwards
$ARGUMENTS, so the SKILL.md stays the single source of truth.

Options:
  --target-dir PATH  Directory opencode scans for commands.
                      Defaults to "<cwd>/.opencode/commands" — run this
                      script from the project you want opencode to expose
                      the skill menu in.
  --skills-dir PATH  Directory of skills to bridge. Defaults to
                      "<root>/.claude/skills".
  --root PATH        Path to the apexyard ops fork (where .claude/skills/
                      lives). Defaults to this script's own repo root.
  -h, --help          Show this help.

Example (installing into the current project's own working tree):
  bash /path/to/apexyard/bin/install-opencode-commands.sh
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --target-dir)
      [ "$#" -ge 2 ] || { echo "ERROR: --target-dir requires a path" >&2; exit 2; }
      TARGET_DIR="$2"
      shift
      ;;
    --skills-dir)
      [ "$#" -ge 2 ] || { echo "ERROR: --skills-dir requires a path" >&2; exit 2; }
      SKILLS_DIR="$2"
      shift
      ;;
    --root)
      [ "$#" -ge 2 ] || { echo "ERROR: --root requires a path" >&2; exit 2; }
      ROOT="$2"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

ROOT="$(cd "$ROOT" && pwd)"
[ -z "$SKILLS_DIR" ] && SKILLS_DIR="$ROOT/.claude/skills"
[ -z "$TARGET_DIR" ] && TARGET_DIR="$(pwd)/.opencode/commands"

[ -d "$SKILLS_DIR" ] || { echo "ERROR: skills directory not found: $SKILLS_DIR" >&2; exit 1; }

mkdir -p "$TARGET_DIR"

count=0
skipped=0
for skill_dir in "$SKILLS_DIR"/*/; do
  skill_dir="${skill_dir%/}"
  name="$(basename "$skill_dir")"
  skill_file="$skill_dir/SKILL.md"
  if [ ! -f "$skill_file" ]; then
    echo "  skip: $name (no SKILL.md)" >&2
    skipped=$((skipped + 1))
    continue
  fi

  # Parse the YAML `description:` field from the SKILL.md frontmatter (the
  # line starting with `description:` between the `---` fences). Fall back to
  # the first `#` heading line if no description field is present.
  description=""
  in_frontmatter=0
  # Strip a trailing CR so the parser works whether the SKILL.md uses LF
  # (repo-internal) or CRLF (common on Windows checkouts) line endings —
  # a bare `---` line under CRLF is `---\r`, which the `---)` case would
  # otherwise never match, silently skipping the whole frontmatter.
  while IFS= read -r line; do
    line="${line%$'\r'}"
    case "$line" in
      "---")
        in_frontmatter=$((in_frontmatter ^ 1))
        continue
        ;;
    esac
    if [ "$in_frontmatter" -eq 1 ] && [ -z "$description" ]; then
      case "$line" in
        description:*)
          description="${line#description: }"
          description="${description# }"
          ;;
      esac
    fi
  done < "$skill_file"

  if [ -z "$description" ]; then
    description="$(grep -m1 -E '^# ' "$skill_file" | sed -E 's/^#+\s*//')"
  fi
  [ -z "$description" ] && description="apexyard skill: $name"

  # YAML-safe: wrap in double quotes, escape backslash and double-quote.
  description_esc="${description//\\/\\\\}"
  description_esc="${description_esc//\"/\\\"}"

  dest="$TARGET_DIR/$name.md"
  cat > "$dest" <<SHIM
---
description: "$description_esc"
---

Follow the apexyard skill defined in @.claude/skills/$name/SKILL.md and execute its process step by step.

\$ARGUMENTS
SHIM
  count=$((count + 1))
done

echo "Generated $count opencode command shim(s) into: $TARGET_DIR"
[ "$skipped" -gt 0 ] && echo "  ($skipped skill dir(s) skipped — no SKILL.md)" >&2
echo ""
echo "Next: run opencode from the project containing $TARGET_DIR — type / in the TUI to see /$name-style menu."
echo "Pair with bin/install-opencode-adapter.sh for full opencode === Claude Code parity (gates + skills)."