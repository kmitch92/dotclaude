#!/usr/bin/env bash
# Usage: compact-timeline.sh TRANSCRIPT_PATH -> markdown on stdout, exit 0.
#   Missing argument or unreadable file -> exit 1, one line on stderr,
#   nothing on stdout. Reads a Claude Code session transcript (one JSON
#   record per line) and emits markdown with exactly seven "## " sections,
#   in order: Asks, Actions, Tests, Errors, Files, Agents, Compactions.
#   Malformed JSON lines are skipped, not fatal. Only bash + jq are used.
#   COMPACT_TIMELINE_MAX_ACTIONS (env, default 150) caps the Actions list
#   to the newest N entries, noting how many older ones were dropped.
set -uo pipefail

if [ "$#" -lt 1 ]; then
  echo "compact-timeline.sh: usage: compact-timeline.sh TRANSCRIPT_PATH" >&2
  exit 1
fi

transcript="$1"

if [ ! -r "$transcript" ]; then
  echo "compact-timeline.sh: cannot read transcript file: $transcript" >&2
  exit 1
fi

max_actions="${COMPACT_TIMELINE_MAX_ACTIONS:-150}"

prog_file="$(mktemp "${TMPDIR:-/tmp}/compact-timeline-prog.XXXXXX")"
clean_file="$(mktemp "${TMPDIR:-/tmp}/compact-timeline-clean.XXXXXX")"
cleanup() { rm -f "$prog_file" "$clean_file"; }
trap cleanup EXIT

cat > "$prog_file" <<'JQ'
def hhmm: .[11:16];

def trunc(n):
  (gsub("\r\n"; " ") | gsub("\r"; " ") | gsub("\n"; " ")) as $s
  | if ($s|length) > n then ($s[0:n] + "…") else $s end;

def content_text:
  if type=="array" then
    ([.[] | select(.type=="text") | (.text // "")] | join("\n"))
  elif type=="string" then .
  else "" end;

def target_for(name; inp):
  if (name=="Edit" or name=="Write" or name=="NotebookEdit" or name=="Read") then (inp.file_path // "")
  elif name=="Bash" then
    (if (inp.description // null) != null then inp.description
     else ((inp.command // "")[0:100]) end)
  elif name=="Agent" then ((inp.subagent_type // "") + ": " + (inp.description // ""))
  elif name=="Skill" then (inp.skill // "")
  elif (name=="Grep" or name=="Glob") then (inp.pattern // "")
  else "" end;

def status_for(tr; id):
  if (tr[id] != null) then (if tr[id].is_error then "ERROR" else "ok" end) else "no result" end;

def is_excluded_global:
  ((.isSidechain // false) == true) or ((.isMeta // false) == true);

def is_ask_noise:
  (.message.content | (
      startswith("<command-name>")
      or startswith("<local-command-stdout>")
      or startswith("Caveat: The messages below")
      or startswith("[Request interrupted")
      or . == "Warmup"
      or test("^/[A-Za-z][A-Za-z0-9_:-]*( |$)")
  ));

(map(select(is_excluded_global | not))) as $records

| ([ $records[] | select(.type=="user" and (.message.content|type)=="string") | select(is_ask_noise | not) ]) as $asks

| ([ $records[] | select(.type=="assistant")
      | . as $rec
      | (($rec.message.content) // [])[]
      | select(.type=="tool_use")
      | {ts: $rec.timestamp, id: .id, name: .name, input: (.input // {})}
   ]) as $tool_uses

| ([ $records[] | select(.type=="user" and (.message.content|type)=="array")
      | . as $rec
      | (($rec.message.content) // [])[]
      | select(.type=="tool_result")
      | {id: .tool_use_id, is_error: (.is_error // false), text: (.content | content_text), ts: $rec.timestamp}
   ]) as $tool_results_list

| (reduce $tool_results_list[] as $r ({}; .[$r.id] = $r)) as $tool_results

| ([ $records[] | select(.type=="system" and .subtype=="compact_boundary") ]) as $boundaries

# Asks body
| ([ $asks | to_entries[]
      | (.key) as $i
      | (.value) as $a
      | "\($i + 1). \($a.timestamp|hhmm)  \($a.message.content|trunc(300))"
        + (if $i == 0 then "  [initial ask]" else "" end)
   ]) as $ask_lines
| (if ($ask_lines|length) == 0 then ["none"] else $ask_lines end) as $asks_body

# Actions body (with cap)
| ([ $tool_uses[]
      | "\(.ts|hhmm)  \(.name)  \(target_for(.name; .input))  \(status_for($tool_results; .id))"
   ]) as $all_action_lines
| ($all_action_lines|length) as $total_actions
| (
    if $total_actions > $max_actions then
      ($total_actions - $max_actions) as $dropped
      | ["(dropped \($dropped) older actions)"] + ($all_action_lines[$dropped:])
    else
      $all_action_lines
    end
  ) as $actions_body

# Tests body
| "(^|[^a-z])(test|tests|jest|vitest|pytest|mocha|spec)([^a-z]|$)|\\.test\\.sh|go test|cargo test|npm (run )?test|pnpm test|yarn test|bun test" as $test_re
| ([ $tool_uses[]
      | select(.name == "Bash")
      | select(((.input.command // "")|ascii_downcase) | test($test_re))
   ]) as $test_actions
| ([ $test_actions[]
      | . as $t
      | ($tool_results[$t.id]) as $res
      | (if $res then (if $res.is_error then "ERROR" else "ok" end) else "no result" end) as $st
      | ($t.input.command // "") as $cmd
      | (
          [ "\($t.ts|hhmm)  \($cmd[0:120])  \($st)" ]
          + (
              if $res then
                (($res.text // "") | split("\n") | map(select(length>0))) as $nonempty
                | ($nonempty | if length > 3 then .[-3:] else . end) | map("  " + .)
              else [] end
            )
        )
   ] | flatten) as $tests_body0
| (if ($tests_body0|length) == 0 then ["none"] else $tests_body0 end) as $tests_body

# Errors body
| ([ $tool_results_list[]
      | select(.is_error == true)
      | . as $r
      | ($tool_uses | map(select(.id == $r.id)) | .[0]) as $tu
      | "\($r.ts|hhmm)  \(if $tu then $tu.name else "" end)  \($r.text | split("\n")[0] | (if (length) > 200 then .[0:200] else . end))"
   ]) as $errors_body0
| (if ($errors_body0|length) == 0 then ["none"] else $errors_body0 end) as $errors_body

# Files body
| ([ $tool_uses[] | select(.name=="Edit" or .name=="Write" or .name=="NotebookEdit") | (.input.file_path // "") | select(length > 0) ]) as $edited_all
| (reduce $edited_all[] as $p ([]; if (index($p)) then . else . + [$p] end)) as $edited_unique
| ([ $tool_uses[] | select(.name=="Read") | (.input.file_path // "") | select(length > 0) ]) as $read_all
| ([ $read_all[] | select(. as $p | ($edited_unique | index($p)) == null) ]) as $read_filtered
| (reduce $read_filtered[] as $p ([]; if (index($p)) then . else . + [$p] end)) as $read_unique
| (
    ["edited:"]
    + (if ($edited_unique|length)==0 then ["  none"] else ($edited_unique | map("  " + .)) end)
    + ["read:"]
    + (if ($read_unique|length)==0 then ["  none"] else ($read_unique | map("  " + .)) end)
  ) as $files_body

# Agents body
| ([ $tool_uses[]
      | select(.name == "Agent")
      | "\(.ts|hhmm)  \(.input.subagent_type // "")  \(.input.description // "")  \(status_for($tool_results; .id))"
   ]) as $agents_body0
| (if ($agents_body0|length) == 0 then ["none"] else $agents_body0 end) as $agents_body

# Compactions body
| ($boundaries | length) as $n_compactions
| (
    if $n_compactions == 0 then ["none"]
    else
      ["\($n_compactions) prior compaction(s)"]
      + [ $boundaries[]
          | "\(.timestamp|hhmm)  trigger=\(.compactMetadata.trigger)  preTokens=\(.compactMetadata.preTokens)  summarised=\(.compactMetadata.messagesSummarized)"
        ]
    end
  ) as $compactions_body

| (
    ["## Asks"] + $asks_body
    + [""] + ["## Actions"] + $actions_body
    + [""] + ["## Tests"] + $tests_body
    + [""] + ["## Errors"] + $errors_body
    + [""] + ["## Files"] + $files_body
    + [""] + ["## Agents"] + $agents_body
    + [""] + ["## Compactions"] + $compactions_body
  )
| join("\n")
JQ

jq -R 'fromjson?' "$transcript" > "$clean_file" 2>/dev/null

jq -r -s --argjson max_actions "$max_actions" -f "$prog_file" "$clean_file"
