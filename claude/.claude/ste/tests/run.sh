#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
STE_DIR="$(cd "${SCRIPT_DIR}/.." >/dev/null 2>&1 && pwd)"

OVERALL_STATUS=0

# ---------------------------------------------------------------------------
# Shared linter location
# ---------------------------------------------------------------------------
BIN_DIR="$(cd "${STE_DIR}/.." >/dev/null 2>&1 && pwd)/bin"
LINTER="${BIN_DIR}/claude-ste-lint.py"

# ---------------------------------------------------------------------------
# Section: lint-fixtures
# ---------------------------------------------------------------------------
section_lint_fixtures() {
    local fixtures_dir="${SCRIPT_DIR}/fixtures"
    local status=0
    local f

    if [[ ! -f "${LINTER}" ]]; then
        for f in "${fixtures_dir}/lint"/*.md "${fixtures_dir}/good-reply.md"; do
            [[ -f "${f}" ]] || continue
            echo "FAIL lint-fixtures: linter missing at ${LINTER} (${f})"
        done
        return 1
    fi

    for f in "${fixtures_dir}/lint"/*.md "${fixtures_dir}/good-reply.md"; do
        [[ -f "${f}" ]] || continue

        local expect_line args_line expected_ids args_str
        expect_line="$(sed -n '1p' "${f}")"
        args_line="$(sed -n '2p' "${f}")"

        expected_ids="none"
        if [[ "${expect_line}" =~ \<!--[[:space:]]*expect:[[:space:]]*(.*)[[:space:]]*--\> ]]; then
            expected_ids="${BASH_REMATCH[1]}"
        fi

        args_str=""
        if [[ "${args_line}" =~ \<!--[[:space:]]*args:[[:space:]]*(.*)[[:space:]]*--\> ]]; then
            args_str="${BASH_REMATCH[1]}"
        fi

        local -a extra_args=()
        if [[ -n "${args_str}" ]]; then
            # shellcheck disable=SC2206
            extra_args=(${args_str})
        fi

        local out rc stderr_file
        stderr_file="$(mktemp)"
        set +e
        out="$(python3 "${LINTER}" --text "${f}" --format json "${extra_args[@]}" 2>"${stderr_file}")"
        rc=$?
        set -e
        rm -f "${stderr_file}"

        local result
        result="$(ACTUAL_JSON="${out}" EXPECTED_IDS="${expected_ids}" ACTUAL_RC="${rc}" python3 <<'PYEOF'
import json, os, sys

expected_raw = os.environ["EXPECTED_IDS"].split()
expected = set() if (not expected_raw or expected_raw == ["none"]) else set(expected_raw)

expected_rc = 0 if not expected else 1

actual_json = os.environ["ACTUAL_JSON"]
actual_rc = int(os.environ["ACTUAL_RC"])

try:
    d = json.loads(actual_json)
    actual_ids = sorted(set([x["id"] for x in d.get("block", [])] + [x["id"] for x in d.get("warn", [])]))
except Exception as e:
    print(f"PARSE_ERROR {e}")
    sys.exit(0)

ok = (set(actual_ids) == expected) and (actual_rc == expected_rc)
if ok:
    print("OK")
else:
    print(f"MISMATCH expected_ids={sorted(expected)} got_ids={actual_ids} expected_rc={expected_rc} got_rc={actual_rc}")
PYEOF
)"

        if [[ "${result}" == "OK" ]]; then
            echo "PASS lint-fixtures: $(basename "${f}")"
        else
            echo "FAIL lint-fixtures: $(basename "${f}"): ${result}"
            status=1
        fi
    done

    if [[ "${status}" -eq 0 ]]; then
        echo "PASS lint-fixtures"
        return 0
    else
        echo "FAIL lint-fixtures"
        return 1
    fi
}

if ! section_lint_fixtures; then
    OVERALL_STATUS=1
fi

# ---------------------------------------------------------------------------
# Section: lint-transcript
# ---------------------------------------------------------------------------
section_lint_transcript() {
    local fixture="${SCRIPT_DIR}/fixtures/transcript.sample.jsonl"

    if [[ ! -f "${LINTER}" ]]; then
        echo "FAIL lint-transcript: linter missing at ${LINTER}"
        return 1
    fi

    if [[ ! -f "${fixture}" ]]; then
        echo "FAIL lint-transcript: fixture missing at ${fixture}"
        return 1
    fi

    local out rc
    set +e
    out="$(python3 "${LINTER}" --transcript "${fixture}" --last-assistant --format json 2>/dev/null)"
    rc=$?
    set -e

    local result
    result="$(ACTUAL_JSON="${out}" ACTUAL_RC="${rc}" python3 <<'PYEOF'
import json, os, sys
try:
    d = json.loads(os.environ["ACTUAL_JSON"])
except Exception as e:
    print(f"PARSE_ERROR {e}")
    sys.exit(0)
rc = int(os.environ["ACTUAL_RC"])
if d.get("prose_words") == 6 and rc == 0:
    print("OK")
else:
    print(f"MISMATCH prose_words={d.get('prose_words')} rc={rc}")
PYEOF
)"

    if [[ "${result}" == "OK" ]]; then
        echo "PASS lint-transcript"
        return 0
    else
        echo "FAIL lint-transcript: ${result}"
        return 1
    fi
}

if ! section_lint_transcript; then
    OVERALL_STATUS=1
fi

# ---------------------------------------------------------------------------
# Section: lint-state
# ---------------------------------------------------------------------------
section_lint_state() {
    if [[ ! -f "${LINTER}" ]]; then
        echo "FAIL lint-state: linter missing at ${LINTER}"
        return 1
    fi

    local state_file
    state_file="$(mktemp)"
    printf '%s' '{"rc":1,"gated":true,"output":"LINE1\nLINE2","ts":"x","scope":"main"}' > "${state_file}"

    local out rc
    set +e
    out="$(python3 "${LINTER}" --state "${state_file}" --format model 2>/dev/null)"
    rc=$?
    set -e
    rm -f "${state_file}"

    if [[ "${out}" == $'LINE1\nLINE2' && "${rc}" -eq 1 ]]; then
        echo "PASS lint-state"
        return 0
    else
        echo "FAIL lint-state: got output=$(printf '%q' "${out}") rc=${rc}"
        return 1
    fi
}

if ! section_lint_state; then
    OVERALL_STATUS=1
fi

# ---------------------------------------------------------------------------
# Section: lint-perf
# ---------------------------------------------------------------------------
section_lint_perf() {
    local fixture="${SCRIPT_DIR}/fixtures/good-reply.md"
    local limit_ms="${STE_PERF_MS:-150}"

    if [[ ! -f "${LINTER}" ]]; then
        echo "FAIL lint-perf: linter missing at ${LINTER}"
        return 1
    fi

    local status=0
    local i start_ns end_ns elapsed_ms
    for i in 1 2 3; do
        start_ns="$(date +%s%N)"
        python3 "${LINTER}" --text "${fixture}" --format json >/dev/null 2>&1 || true
        end_ns="$(date +%s%N)"
        elapsed_ms=$(( (end_ns - start_ns) / 1000000 ))
        echo "lint-perf run ${i}: ${elapsed_ms} ms (limit ${limit_ms} ms)"
        if (( elapsed_ms > limit_ms )); then
            status=1
        fi
    done

    if [[ "${status}" -eq 0 ]]; then
        echo "PASS lint-perf"
        return 0
    else
        echo "FAIL lint-perf"
        return 1
    fi
}

if ! section_lint_perf; then
    OVERALL_STATUS=1
fi

# ---------------------------------------------------------------------------
# Section: lint-resilience
# ---------------------------------------------------------------------------
section_lint_resilience() {
    local fixture="${SCRIPT_DIR}/fixtures/nonexistent-input.md"

    if [[ ! -f "${LINTER}" ]]; then
        echo "FAIL lint-resilience: linter missing at ${LINTER}"
        return 1
    fi

    local out err rc
    local err_file
    err_file="$(mktemp)"
    set +e
    out="$(python3 "${LINTER}" --text "${fixture}" 2>"${err_file}")"
    rc=$?
    set -e
    err="$(cat "${err_file}")"
    rm -f "${err_file}"

    if [[ "${rc}" -eq 3 && -n "${err}" && -z "${out}" ]]; then
        echo "PASS lint-resilience"
        return 0
    else
        echo "FAIL lint-resilience: rc=${rc} stderr_empty=$([[ -z "${err}" ]] && echo yes || echo no) stdout=$(printf '%q' "${out}")"
        return 1
    fi
}

if ! section_lint_resilience; then
    OVERALL_STATUS=1
fi

# ---------------------------------------------------------------------------
# Section: lint-determinism
# ---------------------------------------------------------------------------
section_lint_determinism() {
    local -a files=(
        "/home/kiel/dotclaude/README.md"
        "/home/kiel/dotclaude/claude/.claude/CLAUDE.md"
        "/home/kiel/dotclaude/claude/.claude/skills/commit/SKILL.md"
    )
    local -a seeds=(0 1 7 42 1000)

    if [[ ! -f "${LINTER}" ]]; then
        echo "FAIL lint-determinism: linter missing at ${LINTER}"
        return 1
    fi

    local status=0
    local f seed first_seed first_out out

    for f in "${files[@]}"; do
        if [[ ! -f "${f}" ]]; then
            echo "FAIL lint-determinism: file missing at ${f}"
            status=1
            continue
        fi

        first_seed=""
        first_out=""
        for seed in "${seeds[@]}"; do
            set +e
            out="$(PYTHONHASHSEED="${seed}" python3 "${LINTER}" --text "${f}" --budget 100000 --format json 2>/dev/null | python3 -c '
import json, sys
d = json.load(sys.stdin)
items = sorted(
    "%s:%s" % (x["id"], x["text"])
    for x in d.get("block", []) + d.get("warn", [])
)
for i in items:
    print(i)
')"
            set -e

            if [[ -z "${first_seed}" ]]; then
                first_seed="${seed}"
                first_out="${out}"
                continue
            fi
            if [[ "${out}" != "${first_out}" ]]; then
                echo "FAIL lint-determinism: ${f} differs between seed ${first_seed} and seed ${seed}"
                diff <(printf '%s\n' "${first_out}") <(printf '%s\n' "${out}") || true
                status=1
            fi
        done
    done

    if [[ "${status}" -eq 0 ]]; then
        echo "PASS lint-determinism"
        return 0
    else
        echo "FAIL lint-determinism"
        return 1
    fi
}

if ! section_lint_determinism; then
    OVERALL_STATUS=1
fi

# ---------------------------------------------------------------------------
# (later sections can be appended below this line)
# ---------------------------------------------------------------------------

if [[ "${OVERALL_STATUS}" -eq 0 ]]; then
    echo "SUMMARY: all sections passed"
else
    echo "SUMMARY: one or more sections failed"
fi

exit "${OVERALL_STATUS}"
