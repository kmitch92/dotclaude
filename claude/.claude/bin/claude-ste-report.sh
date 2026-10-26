#!/usr/bin/env bash
# claude-ste-report.sh - summarises the STE (Simplified Technical English)
# lint log into a plain-text report. The log is a JSONL file (one JSON
# event object per line) written by claude-ste-gate.sh and the linter it
# calls: "lint" events (one per Stop-hook run, with scope "main" or "sub",
# rc 0/1/3, block/warn word lists, a per-id counts object, and a
# prose_words count) and "gate-error" events (the linter itself failed to
# run).
#
# Metrics, in order:
#   lints          total "lint" events (any scope).
#   hit rate       share of lint events with rc==2 (hard violation) — the
#                  share of replies that broke at least one must-fix rule.
#   gate errors    count of "gate-error" events — the linter could not
#                  run at all (missing binary, bad exit code, ...).
#   register hits  one count each for NARRATION, FILLER-OPEN and SLOP —
#                  the three register faults the user cares about most.
#   top ids        the rule ids (e.g. SLOP, NARRATION) that fire most
#                  often, summed from every event's "counts" object.
#   top slop       phrases with the id SLOP, grouped by phrase, with the
#                  hint (what to do instead) from the most recent
#                  occurrence of that phrase.
#   prose words    min/median/max word count of main-scope replies.
#
# This report is the evidence for tuning claude/.claude/ste/phrases.tsv
# (the phrase list behind NARRATION, FILLER-OPEN and SLOP): frequent "top
# slop" entries are candidates to add or adjust there.
#
# Usage: claude-ste-report.sh [--log PATH] [--days N]
#   --log PATH   JSONL log to read (default: $STE_LOG or
#                $HOME/.claude/ste/lint.log.jsonl)
#   --days N     only count lines whose "ts" falls within the last N days
#
# Missing or empty log: prints "lints: 0" and exits 0. Lines that are not
# valid JSON are skipped. Requires jq.

set -uo pipefail

LOG_PATH="${STE_LOG:-$HOME/.claude/ste/lint.log.jsonl}"
DAYS=""

while [ $# -gt 0 ]; do
  case "$1" in
    --log) LOG_PATH="$2"; shift 2 ;;
    --days) DAYS="$2"; shift 2 ;;
    *) shift ;;
  esac
done

if [ ! -s "$LOG_PATH" ]; then
  echo "lints: 0"
  exit 0
fi

CUTOFF=""
if [ -n "$DAYS" ]; then
  CUTOFF="$(date -u -d "$DAYS days ago" +%Y-%m-%dT%H:%M:%SZ)"
fi

jq -nR -r --arg cutoff "$CUTOFF" '
  def round0: (. + 0.5) | floor;

  [inputs
   | select(length > 0)
   | (try fromjson catch null)
   | select(. != null and (type == "object"))
   | select($cutoff == "" or ((.ts // "") >= $cutoff))
  ] as $all

  | ($all | map(select(.event == "lint"))) as $lints
  | ($lints | length) as $lint_count
  | ($lints | map(select(.rc == 2)) | length) as $rc2_count
  | (if $lint_count == 0 then 0 else (($rc2_count * 100 / $lint_count) | round0) end) as $hit_rate

  | ($lints | map(select(.scope == "main"))) as $main

  | ($all | map(select(.event == "gate-error")) | length) as $gate_errors

  | (reduce ($all[] | (.counts // {}) | to_entries[]) as $e
       ({}; .[$e.key] = (.[$e.key] // 0) + $e.value)) as $id_counts
  | ($id_counts | to_entries | sort_by([-.value, .key]) | .[0:10]) as $top_ids
  | ([$id_counts["NARRATION"] // 0, $id_counts["FILLER-OPEN"] // 0, $id_counts["SLOP"] // 0]) as $register_hits

  | ($lints
     | map(. as $ev | (($ev.warn // []) + ($ev.block // [])) | map(select(.id == "SLOP") | {text: .text, hint: .hint, ts: $ev.ts}))
     | add // []) as $slop_entries
  | ($slop_entries
     | group_by(.text)
     | map({text: .[0].text, count: length, hint: (max_by(.ts).hint)})
     | sort_by([-.count, .text])
     | .[0:20]) as $top_slop

  | ($main | map(.prose_words) | sort) as $pw
  | ($pw | length) as $pwn

  | "lints: \($lint_count)",
    "hit rate: \($hit_rate)%",
    "gate errors: \($gate_errors)",
    "register hits:",
    "  NARRATION \($register_hits[0])",
    "  FILLER-OPEN \($register_hits[1])",
    "  SLOP \($register_hits[2])",
    "top ids:",
    ($top_ids[] | "  \(.key) \(.value)"),
    "top slop:",
    ($top_slop[] | "  \(.text) \(.count) -> \(.hint)"),
    (if $pwn == 0 then empty else
       ($pw[0]) as $min
       | ($pw[$pwn - 1]) as $max
       | (if ($pwn % 2) == 1
          then $pw[(($pwn - 1) / 2) | floor]
          else ($pw[(($pwn / 2) | floor) - 1] + $pw[($pwn / 2) | floor]) / 2
          end) as $median
       | "prose words: min \($min) median \($median) max \($max)"
     end)
' "$LOG_PATH"
