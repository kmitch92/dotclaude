#!/usr/bin/env bash
# claude-ste-report.sh - summarises the STE (Simplified Technical English)
# lint log into a plain-text report. The log is a JSONL file (one JSON
# event object per line) written by claude-ste-gate.sh and the linter it
# calls: "lint" events (one per Stop-hook run, with scope "main" or "sub",
# rc 0/1/2, block/warn word lists, a per-id counts object, and a
# prose_words count) and "gate-error" events (the linter itself failed to
# run).
#
# Metrics, in order:
#   lints          total "lint" events (any scope).
#   block rate     share of lint events with rc==2 (hard violation) —
#                  how often the linter would block a Stop.
#   retry rate     among main-scope rc==2 events, the share followed by a
#                  later main-scope lint event in the same session — how
#                  often a block was survived by a retry instead of
#                  getting stuck.
#   gate errors    count of "gate-error" events — the linter could not
#                  run at all (missing binary, bad exit code, ...).
#   top ids        the rule ids (e.g. UNAPPROVED, UNKNOWN) that fire most
#                  often, summed from every event's "counts" object.
#   top unapproved words with the id UNAPPROVED, grouped by word, with
#                  the hint (suggested replacement) from the most recent
#                  occurrence of that word.
#   top unknown    words with the id UNKNOWN, grouped by word — words the
#                  linter does not recognise at all.
#   prose words    min/median/max word count of main-scope replies.
#
# This report is the evidence for tuning claude/.claude/ste/glossary.txt
# (approved replacements for banned or unknown words) and
# claude/.claude/ste/banned.txt (words to flag): frequent "top unapproved"
# or "top unknown" entries are candidates to add there.
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
  | (if $lint_count == 0 then 0 else (($rc2_count * 100 / $lint_count) | round0) end) as $block_rate

  | ($lints | map(select(.scope == "main"))) as $main
  | ($main | map(select(.rc == 2))) as $rc2main
  | ($rc2main | length) as $rc2main_count
  | ($rc2main
     | map(. as $item | ($main | any(.session == $item.session and .ts > $item.ts)))
     | map(select(.))
     | length) as $retried_count
  | (if $rc2main_count == 0 then 0 else (($retried_count * 100 / $rc2main_count) | round0) end) as $retry_rate

  | ($all | map(select(.event == "gate-error")) | length) as $gate_errors

  | (reduce ($all[] | (.counts // {}) | to_entries[]) as $e
       ({}; .[$e.key] = (.[$e.key] // 0) + $e.value)) as $id_counts
  | ($id_counts | to_entries | sort_by([-.value, .key]) | .[0:10]) as $top_ids

  | ($lints
     | map(. as $ev | ($ev.block // []) | map(select(.id == "UNAPPROVED") | {text: .text, hint: .hint, ts: $ev.ts}))
     | add // []) as $unapproved_entries
  | ($unapproved_entries
     | group_by(.text)
     | map({text: .[0].text, count: length, hint: (max_by(.ts).hint)})
     | sort_by([-.count, .text])
     | .[0:20]) as $top_unapproved

  | ($lints
     | map(. as $ev | ($ev.warn // []) | map(select(.id == "UNKNOWN") | {text: .text}))
     | add // []) as $unknown_entries
  | ($unknown_entries
     | group_by(.text)
     | map({text: .[0].text, count: length})
     | sort_by([-.count, .text])
     | .[0:20]) as $top_unknown

  | ($main | map(.prose_words) | sort) as $pw
  | ($pw | length) as $pwn

  | "lints: \($lint_count)",
    "block rate: \($block_rate)%",
    "retry rate: \($retry_rate)%",
    "gate errors: \($gate_errors)",
    "top ids:",
    ($top_ids[] | "  \(.key) \(.value)"),
    "top unapproved:",
    ($top_unapproved[] | "  \(.text) \(.count) -> \(.hint)"),
    "top unknown:",
    ($top_unknown[] | "  \(.text) \(.count)"),
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
