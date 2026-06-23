#!/usr/bin/env bash
# Stop hook: gently remind to keep README.md in sync with the project.
#
# When a turn ends with uncommitted changes to project files (R code, the
# website, data, workflows, or env files), this nudges Claude once to confirm
# the README still reflects the project. It fires at most once per turn
# (guarded by stop_hook_active) and is a reminder, not a hard gate, so the
# turn can still wrap up if the README is already accurate.

cd "${CLAUDE_PROJECT_DIR:-.}" 2>/dev/null || true

input=$(cat)

# Avoid re-triggering after we have already nudged once this turn.
if [ "$(printf '%s' "$input" | jq -r '.stop_hook_active // false')" = "true" ]; then
  exit 0
fi

# Paths whose changes might make the README stale. README edits themselves do
# not match these prefixes, so a README-only change never triggers the nudge.
changed=$(git status --porcelain 2>/dev/null | cut -c4- \
  | grep -E '^(R/|website/|data_clean/|data_raw/|\.github/|wrangler\.toml|renv\.lock)')

if [ -n "$changed" ]; then
  jq -n --arg files "$changed" '{
    decision: "block",
    reason: ("Project files changed this turn:\n" + $files +
      "\n\nBefore finishing, check README.md and confirm it still reflects the project structure, datasets, and how to run things. If it is already accurate, no change is needed, just say so and wrap up.")
  }'
fi

exit 0
