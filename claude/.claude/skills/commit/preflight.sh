#!/usr/bin/env bash
# preflight.sh — pre-commit sanity check: large files, junk paths, secrets, binaries.
# macOS (bash 3.2, BSD tools) and Linux (bash 5, GNU tools) compatible.
#
# Usage:
#   preflight.sh                 check every pending path (git status --porcelain)
#   preflight.sh --staged        check only staged paths (git diff --cached)
#   preflight.sh <path>...       check exactly those paths
#
# Findings print as KIND<TAB>detail<TAB>path. KIND is one of LARGE, JUNK,
# SECRET, BINARY, SUSPECT.
#
# Exit codes: 0 = no findings, 1 = at least one LARGE/JUNK/SECRET/BINARY
# finding, 3 = findings exist but all of them are SUSPECT, 2 = not a git repo.
#
# SUSPECT is a lower-confidence secret finding: a pattern that looks like a
# credential but sits in a test/fixture path (see is_test_path), or whose
# matched text is obviously synthetic (see is_synthetic), or (for
# generic-assignment) a quoted value that survived the placeholder/entropy
# filter. Drop rules for generic-assignment, in order: drop if the value
# contains interpolation/template syntax ($ { } ( ) < > % or whitespace);
# drop if it case-insensitively contains a placeholder word (example,
# sample, dummy, fake, placeholder, changeme, replace, your, xxx, test,
# secret, password, token, redacted, hunter2, foo, bar, lorem, abc, 123,
# null, none, todo); drop if shorter than 12 chars or if fewer than two of
# lowercase/uppercase/digit/other are present; otherwise SUSPECT in a test
# path or if the matched text is synthetic, SECRET elsewhere. Drop rules
# take precedence over the synthetic check: a dropped value produces no
# line at all. The synthetic check applies to every secret rule: the
# matched text (the full regex match; for private-key, the BEGIN header
# line plus the next non-empty line) is synthetic if it contains a run of
# 8+ consecutive ascending letters or digits, any single character
# repeated 6+ times in a row, or one of fake/example/sample/dummy/
# placeholder/test/redacted (case-insensitive).
set -u

usage_error() {
    echo "preflight: not inside a git work tree" >&2
    echo "usage: preflight.sh [--staged] [path...]" >&2
}

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    usage_error
    exit 2
fi

repo_top="$(git rev-parse --show-toplevel)"
orig_pwd="$(pwd -P)"
max_kb="${PREFLIGHT_MAX_KB:-512}"

cd "$repo_top" || exit 2

total_findings=0
high_findings=0
files_with_findings=0

secret_names=(
    openai-key
    aws-access-key
    github-token
    github-pat
    slack-token
    private-key
    jwt
    google-api-key
    url-credentials
    generic-assignment
)

secret_pats=(
    "sk-[A-Za-z0-9_-]{20,}"
    "AKIA[0-9A-Z]{16}"
    "gh[pousr]_[A-Za-z0-9]{36,}"
    "github_pat_[A-Za-z0-9_]{22,}"
    "xox[baprs]-[A-Za-z0-9-]{10,}"
    "-----BEGIN [A-Z ]*PRIVATE KEY-----"
    "eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}"
    "AIza[0-9A-Za-z_-]{35}"
    "[a-z][a-z0-9+.-]*://[^/@[:space:]]+:[^/@[:space:]]+@"
    "(api[_-]?key|secret|token|password|passwd)[[:space:]]*[:=][[:space:]]*[\"'][^\"']{8,}[\"']"
)

secret_icase=(0 0 0 0 0 0 0 0 0 1)

# is_synthetic TEXT -> true (exit 0) if TEXT is obviously a fabricated
# secret value: a run of 8+ consecutive ascending letters or digits, any
# single character repeated 6+ times in a row, or one of the placeholder
# words fake/example/sample/dummy/placeholder/test/redacted (case
# insensitive). No regex backreferences; ascending runs are matched against
# a fixed list of 8-char windows so this stays bash 3.2 / BSD+GNU safe.
is_synthetic() {
    local text="$1"
    local upper
    upper="$(printf '%s' "$text" | tr '[:lower:]' '[:upper:]')"

    local alpha="ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    local alen=${#alpha}
    local i=0
    while (( i + 8 <= alen )); do
        local window="${alpha:$i:8}"
        case "$upper" in
            *"$window"*) return 0 ;;
        esac
        i=$((i + 1))
    done

    local digits="0123456789"
    local dlen=${#digits}
    i=0
    while (( i + 8 <= dlen )); do
        local window="${digits:$i:8}"
        case "$text" in
            *"$window"*) return 0 ;;
        esac
        i=$((i + 1))
    done

    local tlen=${#text}
    i=0
    while (( i < tlen )); do
        local c="${text:$i:1}"
        local run="${c}${c}${c}${c}${c}${c}"
        case "$text" in
            *"$run"*) return 0 ;;
        esac
        i=$((i + 1))
    done

    if printf '%s' "$text" | grep -qiE 'fake|example|sample|dummy|placeholder|test|redacted'; then
        return 0
    fi

    return 1
}

# is_test_path RELPATH -> true (exit 0) if the path looks like a test or
# fixture path, false (exit 1) otherwise.
is_test_path() {
    local relpath="$1"
    local test_pats=(
        '\.(test|spec)\.[A-Za-z0-9]+$'
        '(^|/)(tests?|__tests__|fixtures?|__fixtures__|__mocks__|testdata|spec)/'
        '_test\.(go|py|rb|sh)$'
        '(^|/)test_[^/]*\.py$'
    )
    local p
    for p in "${test_pats[@]}"; do
        [[ "$relpath" =~ $p ]] && return 0
    done
    return 1
}

# junk_reason_for PATH -> prints a reason string on stdout, or nothing.
junk_reason_for() {
    local relpath="$1"
    local base
    base="$(basename "$relpath")"

    if echo "$relpath" | grep -qE '(^|/)node_modules/'; then
        echo "node_modules"
    elif echo "$relpath" | grep -qE '(^|/)(Cache|GPUCache|CachedData|CachedProfilesData|DawnWebGPUCache|DawnGraphiteCache|Code Cache)/'; then
        echo "cache"
    elif echo "$relpath" | grep -qE '(^|/)\.claude/(projects|shell-snapshots|statsig|todos|debug)/'; then
        echo "claude-runtime"
    elif echo "$relpath" | grep -qE '\.log$'; then
        echo "log"
    elif echo "$relpath" | grep -qE '\.jsonl$'; then
        echo "transcript"
    elif echo "$relpath" | grep -qE '(^|/)(package-lock\.json|yarn\.lock|pnpm-lock\.yaml|bun\.lock|bun\.lockb)$'; then
        echo "lockfile"
    elif echo "$relpath" | grep -qE '(^|/)\.DS_Store$'; then
        echo "ds-store"
    elif echo "$relpath" | grep -qE '(^|/)\.install_status$'; then
        echo "install-state"
    elif echo "$relpath" | grep -qE '\.(sqlite|sqlite3|db|mdb|lmdb)$'; then
        echo "database"
    elif echo "$relpath" | grep -qE '(^|/)\.env(\..+)?$' && [[ "$base" != ".env.example" && "$base" != ".env.template" ]]; then
        echo "dotenv"
    elif echo "$relpath" | grep -qE '\.(pem|key|p12|pfx|jks|keystore)$'; then
        echo "key-material"
    elif echo "$relpath" | grep -qE '(^|/)id_(rsa|ed25519|ecdsa|dsa)$'; then
        echo "ssh-key"
    elif echo "$relpath" | grep -qE '\.(backup|bak|orig|swp)(\..*)?$'; then
        echo "backup"
    fi
}

process_path() {
    local relpath="$1"

    [[ -f "$relpath" ]] || return 0

    local file_findings=0
    local is_large=0

    local size
    size="$(wc -c <"$relpath" 2>/dev/null)"
    size="${size//[[:space:]]/}"
    [[ -n "$size" ]] || size=0

    local max_bytes=$((max_kb * 1024))

    if (( size > max_bytes )); then
        local kb=$((size / 1024))
        printf 'LARGE\t%sKB\t%s\n' "$kb" "$relpath"
        file_findings=$((file_findings + 1))
        high_findings=$((high_findings + 1))
        is_large=1
    fi

    local junk_reason
    junk_reason="$(junk_reason_for "$relpath")"
    if [[ -n "$junk_reason" ]]; then
        printf 'JUNK\t%s\t%s\n' "$junk_reason" "$relpath"
        file_findings=$((file_findings + 1))
        high_findings=$((high_findings + 1))
    fi

    local is_text=1
    grep -qI . "$relpath" 2>/dev/null || is_text=0

    local max_secret_bytes=$((5 * 1024 * 1024))

    if (( is_text == 1 )) && (( size <= max_secret_bytes )); then
        local i=0
        local count=${#secret_names[@]}
        while (( i < count )); do
            local name="${secret_names[$i]}"
            local pat="${secret_pats[$i]}"
            local icase="${secret_icase[$i]}"
            local grep_opts="-nE"
            (( icase == 1 )) && grep_opts="-nEi"

            case "$name" in
                generic-assignment)
                    local matches
                    matches="$(grep $grep_opts -e "$pat" -- "$relpath" 2>/dev/null)"
                    if [[ -n "$matches" ]]; then
                        local surv_lineno=""
                        local surv_matched=""
                        while IFS= read -r m; do
                            [[ -n "$m" ]] || continue
                            local mlineno="${m%%:*}"
                            local mcontent="${m#*:}"
                            local grep_o_opts="-oE"
                            (( icase == 1 )) && grep_o_opts="-oEi"
                            local matched_full
                            matched_full="$(printf '%s\n' "$mcontent" | grep $grep_o_opts -e "$pat" | head -n 1)"
                            local value
                            value="$(printf '%s' "$matched_full" | sed -E "s/^[^\"']*[\"']//; s/[\"']\$//")"

                            if printf '%s' "$value" | grep -qE '[$(){}<>%[:space:]]'; then
                                continue
                            fi
                            if printf '%s' "$value" | grep -qiE 'example|sample|dummy|fake|placeholder|changeme|replace|your|xxx|test|secret|password|token|redacted|hunter2|foo|bar|lorem|abc|123|null|none|todo'; then
                                continue
                            fi
                            local vlen=${#value}
                            if (( vlen < 12 )); then
                                continue
                            fi
                            local classes=0
                            printf '%s' "$value" | grep -q '[a-z]' && classes=$((classes + 1))
                            printf '%s' "$value" | grep -q '[A-Z]' && classes=$((classes + 1))
                            printf '%s' "$value" | grep -q '[0-9]' && classes=$((classes + 1))
                            printf '%s' "$value" | grep -qE '[^a-zA-Z0-9]' && classes=$((classes + 1))
                            if (( classes < 2 )); then
                                continue
                            fi

                            surv_lineno="$mlineno"
                            surv_matched="$matched_full"
                            break
                        done < <(printf '%s\n' "$matches")

                        if [[ -n "$surv_lineno" ]]; then
                            local kind="SECRET"
                            is_test_path "$relpath" && kind="SUSPECT"
                            is_synthetic "$surv_matched" && kind="SUSPECT"
                            printf '%s\t%s:%s\t%s\n' "$kind" "$name" "$surv_lineno" "$relpath"
                            file_findings=$((file_findings + 1))
                            [[ "$kind" == "SECRET" ]] && high_findings=$((high_findings + 1))
                        fi
                    fi
                    ;;
                jwt)
                    local lineno_content
                    lineno_content="$(grep $grep_opts -e "$pat" -- "$relpath" 2>/dev/null | head -n 1)"
                    if [[ -n "$lineno_content" ]]; then
                        local lineno="${lineno_content%%:*}"
                        local lcontent="${lineno_content#*:}"
                        local grep_o_opts="-oE"
                        (( icase == 1 )) && grep_o_opts="-oEi"
                        local matched_text
                        matched_text="$(printf '%s\n' "$lcontent" | grep $grep_o_opts -e "$pat" | head -n 1)"
                        local kind="SECRET"
                        is_test_path "$relpath" && kind="SUSPECT"
                        is_synthetic "$matched_text" && kind="SUSPECT"
                        printf '%s\t%s:%s\t%s\n' "$kind" "$name" "$lineno" "$relpath"
                        file_findings=$((file_findings + 1))
                        [[ "$kind" == "SECRET" ]] && high_findings=$((high_findings + 1))
                    fi
                    ;;
                private-key)
                    local lineno
                    lineno="$(grep $grep_opts -e "$pat" -- "$relpath" 2>/dev/null | head -n 1 | cut -d: -f1)"
                    if [[ -n "$lineno" ]]; then
                        local header_line next_line nl total_lines
                        header_line="$(sed -n "${lineno}p" "$relpath" 2>/dev/null)"
                        next_line=""
                        total_lines="$(wc -l <"$relpath" 2>/dev/null)"
                        total_lines="${total_lines//[[:space:]]/}"
                        [[ -n "$total_lines" ]] || total_lines=0
                        nl=$((lineno + 1))
                        while (( nl <= total_lines )); do
                            local candidate
                            candidate="$(sed -n "${nl}p" "$relpath" 2>/dev/null)"
                            if [[ -n "$candidate" ]]; then
                                next_line="$candidate"
                                break
                            fi
                            nl=$((nl + 1))
                        done
                        local matched_text="${header_line}"$'\n'"${next_line}"
                        local kind="SECRET"
                        is_test_path "$relpath" && kind="SUSPECT"
                        is_synthetic "$matched_text" && kind="SUSPECT"
                        printf '%s\t%s:%s\t%s\n' "$kind" "$name" "$lineno" "$relpath"
                        file_findings=$((file_findings + 1))
                        [[ "$kind" == "SECRET" ]] && high_findings=$((high_findings + 1))
                    fi
                    ;;
                *)
                    local lineno_content
                    lineno_content="$(grep $grep_opts -e "$pat" -- "$relpath" 2>/dev/null | head -n 1)"
                    if [[ -n "$lineno_content" ]]; then
                        local lineno="${lineno_content%%:*}"
                        local lcontent="${lineno_content#*:}"
                        local grep_o_opts="-oE"
                        (( icase == 1 )) && grep_o_opts="-oEi"
                        local matched_text
                        matched_text="$(printf '%s\n' "$lcontent" | grep $grep_o_opts -e "$pat" | head -n 1)"
                        local kind="SECRET"
                        is_synthetic "$matched_text" && kind="SUSPECT"
                        printf '%s\t%s:%s\t%s\n' "$kind" "$name" "$lineno" "$relpath"
                        file_findings=$((file_findings + 1))
                        [[ "$kind" == "SECRET" ]] && high_findings=$((high_findings + 1))
                    fi
                    ;;
            esac

            i=$((i + 1))
        done
    fi

    if (( is_text == 0 )) && (( is_large == 0 )) && (( size > 0 )); then
        printf 'BINARY\tnon-text\t%s\n' "$relpath"
        file_findings=$((file_findings + 1))
        high_findings=$((high_findings + 1))
    fi

    if (( file_findings > 0 )); then
        total_findings=$((total_findings + file_findings))
        files_with_findings=$((files_with_findings + 1))
    fi
}

# resolve_arg_to_relpath ARG -> prints repo-top-relative path on stdout, or
# nothing (and non-zero exit) if it cannot be resolved inside the repo.
resolve_arg_to_relpath() {
    local arg="$1"
    local abs
    if [[ "$arg" == /* ]]; then
        abs="$arg"
    else
        abs="$orig_pwd/$arg"
    fi

    local dir base absdir
    dir="$(dirname "$abs")"
    base="$(basename "$abs")"
    absdir="$(cd "$dir" 2>/dev/null && pwd -P)" || return 1
    abs="$absdir/$base"

    case "$abs" in
        "$repo_top"/*)
            echo "${abs#"$repo_top"/}"
            return 0
            ;;
        "$repo_top")
            echo "."
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

if [[ "${1:-}" == "--staged" ]]; then
    while IFS= read -r -d '' relpath; do
        process_path "$relpath"
    done < <(git diff --cached --name-only -z --diff-filter=ACMR)
elif [[ $# -gt 0 ]]; then
    for arg in "$@"; do
        relpath="$(resolve_arg_to_relpath "$arg")" || continue
        process_path "$relpath"
    done
else
    while IFS= read -r -d '' entry; do
        status="${entry:0:2}"
        relpath="${entry:3}"

        if [[ "$status" == *R* || "$status" == *C* ]]; then
            IFS= read -r -d '' _old_path || true
        fi

        if [[ "$status" == "D " || "$status" == " D" ]]; then
            continue
        fi

        process_path "$relpath"
    done < <(git status --porcelain=v1 -z --untracked-files=all)
fi

if (( total_findings > 0 )); then
    echo "preflight: $total_findings finding(s) in $files_with_findings file(s)" >&2
    if (( high_findings > 0 )); then
        exit 1
    else
        exit 3
    fi
else
    echo "preflight: clean" >&2
    exit 0
fi
