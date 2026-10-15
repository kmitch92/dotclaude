#!/usr/bin/env bash
# preflight.sh — pre-commit sanity check: large files, junk paths, secrets, binaries.
# macOS (bash 3.2, BSD tools) and Linux (bash 5, GNU tools) compatible.
#
# Usage:
#   preflight.sh                 check every pending path (git status --porcelain)
#   preflight.sh --staged        check only staged paths (git diff --cached)
#   preflight.sh <path>...       check exactly those paths
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
        is_large=1
    fi

    local junk_reason
    junk_reason="$(junk_reason_for "$relpath")"
    if [[ -n "$junk_reason" ]]; then
        printf 'JUNK\t%s\t%s\n' "$junk_reason" "$relpath"
        file_findings=$((file_findings + 1))
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
            local lineno
            lineno="$(grep $grep_opts -e "$pat" -- "$relpath" 2>/dev/null | head -n 1 | cut -d: -f1)"
            if [[ -n "$lineno" ]]; then
                printf 'SECRET\t%s:%s\t%s\n' "$name" "$lineno" "$relpath"
                file_findings=$((file_findings + 1))
            fi
            i=$((i + 1))
        done
    fi

    if (( is_text == 0 )) && (( is_large == 0 )) && (( size > 0 )); then
        printf 'BINARY\tnon-text\t%s\n' "$relpath"
        file_findings=$((file_findings + 1))
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
    exit 1
else
    echo "preflight: clean" >&2
    exit 0
fi
