#!/usr/bin/env bash
# PreToolUse[Bash] hook for the worker agent: workers may not commit, push,
# rebase, hard-reset, checkout, restore, clean, or stash. Blocks (exit 2, reason
# on stderr) when any simple command in the Bash command line is
# `git [global opts] commit|push|rebase|checkout|restore|clean|stash` or
# `git reset --hard` — including after cd, &&, ;, | and git -C <dir>.
# Text inside quotes is ignored, so `echo "git commit"` is allowed.
# Non-Bash tools and unparseable input exit 0: the hook never blocks on its own failure.
set -uo pipefail

input=$(cat) || exit 0
tool=$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null) || exit 0
[ "$tool" = "Bash" ] || exit 0
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null) || exit 0
[ -n "$cmd" ] || exit 0

op=$(printf '%s\n' "$cmd" | awk -v sq="'" '
  { s = s (NR > 1 ? "\n" : "") $0 }
  END {
    # Replace quoted text with a placeholder word; turn separators into newlines.
    out = ""; q = ""; n = length(s)
    for (i = 1; i <= n; i++) {
      c = substr(s, i, 1)
      if (q != "") {
        if (q == "\"" && c == "\\") { i++; continue }
        if (c == q) { q = ""; out = out "Q" }
        continue
      }
      # Backslash-newline is a line continuation; an escaped space/tab stays inside the word.
      if (c == "\\") { i++; nc = substr(s, i, 1); out = out (nc == "\n" ? " " : (nc == " " || nc == "\t" ? "_" : nc)); continue }
      if (c == sq || c == "\"") { q = c; continue }
      if (index(";&|()`\n", c)) { out = out "\n"; continue }
      out = out c
    }
    nseg = split(out, segs, "\n")
    for (k = 1; k <= nseg; k++) {
      nt = split(segs[k], t, " ")
      j = 1
      while (j <= nt && (t[j] ~ /^[A-Za-z_][A-Za-z0-9_]*=/ || t[j] ~ /^(sudo|command|exec|env|time|nohup|then|do|else|[{]|!)$/)) j++
      if (j > nt || (t[j] != "git" && t[j] !~ /\/git$/)) continue
      for (j++; j <= nt && t[j] ~ /^-/; j++)
        if (t[j] ~ /^(-C|-c|--git-dir|--work-tree|--namespace|--config-env)$/) j++
      if (j > nt) continue
      if (t[j] == "commit" || t[j] == "push" || t[j] == "rebase" || t[j] == "checkout" || t[j] == "restore" || t[j] == "clean" || t[j] == "stash") { print t[j]; exit }
      if (t[j] == "reset")
        for (m = j + 1; m <= nt; m++) if (t[m] == "--hard") { print "reset --hard"; exit }
    }
  }')

if [ -n "$op" ]; then
  echo "Blocked: workers may not run git $op. These operations destroy uncommitted work in the shared tree; leave your changes uncommitted and report back." >&2
  exit 2
fi
exit 0
