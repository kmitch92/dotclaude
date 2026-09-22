#!/usr/bin/env bash
# PreToolUse[Bash] hook for the worker agent: workers may not run build
# commands or test suites. Blocks (exit 2, reason on stderr) when any simple
# command in the Bash command line matches certain build and test tools with
# specific arguments. Text inside quotes is ignored, so `echo "npm run build"`
# is allowed. Non-Bash tools and unparseable input exit 0: the hook never
# blocks on its own failure.
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
      if (j > nt) continue

      # Extract base name from path
      cmd_name = t[j]
      gsub(/.*\//, "", cmd_name)

      # Handle npx, bunx, pnpm dlx (drop wrapper, treat next as head)
      if (cmd_name == "npx" || cmd_name == "bunx") {
        j++
        if (j > nt) continue
        cmd_name = t[j]
        gsub(/.*\//, "", cmd_name)
      } else if (cmd_name == "pnpm" && j + 1 <= nt && t[j+1] == "dlx") {
        j += 2
        if (j > nt) continue
        cmd_name = t[j]
        gsub(/.*\//, "", cmd_name)
      }

      # Block direct build tools
      if (cmd_name ~ /^(make|ninja|tox|nox|bazel|gradle|gradlew|mvn|mvnw|sbt|dotnet)$/) {
        print cmd_name
        exit
      }

      # Block cmake --build
      if (cmd_name == "cmake") {
        for (m = j + 1; m <= nt; m++) {
          if (t[m] == "--build") {
            print "cmake --build"
            exit
          }
        }
        continue
      }

      # Block npm, pnpm, yarn, bun
      if (cmd_name ~ /^(npm|pnpm|yarn|bun)$/) {
        m = j + 1
        while (m <= nt && t[m] ~ /^-/) m++
        if (m > nt) continue

        # Check for build or test directly
        if (t[m] == "build" || t[m] == "test") {
          print cmd_name " " t[m]
          exit
        }

        # Check for "run" followed by script name
        if (t[m] == "run" && m + 1 <= nt) {
          script = t[m+1]
          if (script == "build" || script == "test" || script ~ /^build:/ || script ~ /^test:/ || script ~ /e2e/ || script ~ /integration/) {
            print cmd_name " run"
            exit
          }
        }
        continue
      }

      # Block cargo build, test, run, bench (but allow if specific target/test given)
      if (cmd_name == "cargo") {
        subcmd = ""
        has_target = 0
        for (m = j + 1; m <= nt; m++) {
          if (t[m] ~ /^(build|test|run|bench)$/ && subcmd == "") {
            subcmd = t[m]
          }
          # Detect specific target arguments (--lib, --bin, ::, etc.)
          if (t[m] ~ /^--(lib|bin|example|test|bench)$/ || t[m] ~ /::/) {
            has_target = 1
          }
          # Non-flag args after the subcommand suggest specific targets
          if (subcmd != "" && t[m] !~ /^-/ && t[m] != subcmd) {
            has_target = 1
          }
        }
        if (subcmd != "" && !has_target) {
          print "cargo " subcmd
          exit
        }
        continue
      }

      # Block go build/test/vet with ./...
      if (cmd_name == "go") {
        found_subcmd = ""
        found_dots = 0
        for (m = j + 1; m <= nt; m++) {
          if (t[m] ~ /^(build|test|vet)$/) found_subcmd = t[m]
          if (t[m] == "./...") found_dots = 1
        }
        if (found_subcmd != "" && found_dots) {
          print "go " found_subcmd
          exit
        }
        continue
      }

      # Block pytest
      if (cmd_name == "pytest") {
        has_path = 0
        has_integration_e2e = 0
        for (m = j + 1; m <= nt; m++) {
          arg = t[m]
          # If this is a flag that consumes a value
          if (arg ~ /^(-k|-m|-n|-p|--maxfail|-c|--rootdir)$/ && m + 1 <= nt) {
            m++
            consumed_arg = t[m]
            # Check consumed value for integration/e2e
            if (consumed_arg ~ /integration/ || consumed_arg ~ /e2e/) {
              has_integration_e2e = 1
            }
            continue
          }
          # Check for integration or e2e in non-flag args
          if (arg ~ /integration/ || arg ~ /e2e/) {
            has_integration_e2e = 1
          }
          # Check if path-like (non-flag with / or starts with . or ends with .py or contains ::)
          if (arg !~ /^-/ && (index(arg, "/") > 0 || substr(arg, 1, 1) == "." || arg ~ /\.py$/ || index(arg, "::") > 0)) {
            has_path = 1
          }
        }
        if (has_integration_e2e || !has_path) {
          print "pytest"
          exit
        }
        continue
      }

      # Block python/python3 -m pytest or -m unittest
      if (cmd_name ~ /^python3?$/) {
        m = j + 1
        while (m <= nt) {
          if (t[m] == "-m" && m + 1 <= nt) {
            if (t[m+1] == "unittest") {
              print "python -m unittest"
              exit
            }
            if (t[m+1] == "pytest") {
              has_path = 0
              has_integration_e2e = 0
              for (n = m + 2; n <= nt; n++) {
                arg = t[n]
                # If this is a flag that consumes a value
                if (arg ~ /^(-k|-m|-n|-p|--maxfail|-c|--rootdir)$/ && n + 1 <= nt) {
                  n++
                  consumed_arg = t[n]
                  # Check consumed value for integration/e2e
                  if (consumed_arg ~ /integration/ || consumed_arg ~ /e2e/) {
                    has_integration_e2e = 1
                  }
                  continue
                }
                # Check for integration or e2e in non-flag args
                if (arg ~ /integration/ || arg ~ /e2e/) {
                  has_integration_e2e = 1
                }
                # Check if path-like (non-flag with / or starts with . or ends with .py or contains ::)
                if (arg !~ /^-/ && (index(arg, "/") > 0 || substr(arg, 1, 1) == "." || arg ~ /\.py$/ || index(arg, "::") > 0)) {
                  has_path = 1
                }
              }
              if (has_integration_e2e || !has_path) {
                print "python -m pytest"
                exit
              }
            }
            m += 2
          } else {
            m++
          }
        }
        continue
      }

      # Block jest, vitest, mocha, ava
      if (cmd_name ~ /^(jest|vitest|mocha|ava)$/) {
        has_non_flag_non_runner = 0
        for (m = j + 1; m <= nt; m++) {
          if (t[m] !~ /^-/ && t[m] != "run" && t[m] != "watch") {
            has_non_flag_non_runner = 1
            break
          }
        }
        if (!has_non_flag_non_runner) {
          print cmd_name
          exit
        }
        continue
      }

      # Block playwright and cypress
      if (cmd_name ~ /^(playwright|cypress)$/) {
        print cmd_name
        exit
      }

      # Block docker build and docker compose
      if (cmd_name == "docker") {
        for (m = j + 1; m <= nt; m++) {
          if (t[m] == "build") {
            print "docker build"
            exit
          }
          if (t[m] == "compose") {
            for (n = m + 1; n <= nt; n++) {
              if (t[n] ~ /^(up|build)$/) {
                print "docker compose"
                exit
              }
            }
          }
        }
        continue
      }

      # Block docker-compose up/build
      if (cmd_name == "docker-compose") {
        for (m = j + 1; m <= nt; m++) {
          if (t[m] ~ /^(up|build)$/) {
            print "docker-compose"
            exit
          }
        }
        continue
      }

      # Block tsc -b or --build
      if (cmd_name == "tsc") {
        for (m = j + 1; m <= nt; m++) {
          if (t[m] == "-b" || t[m] == "--build") {
            print "tsc"
            exit
          }
        }
        continue
      }
    }
  }')

if [ -n "$op" ]; then
  echo "Blocked: workers do not run builds or whole test suites ($op). Run only the specific test files in ACCEPTANCE, then report back to the orchestrator." >&2
  exit 2
fi
exit 0
