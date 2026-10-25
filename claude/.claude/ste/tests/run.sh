#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
STE_DIR="$(cd "${SCRIPT_DIR}/.." >/dev/null 2>&1 && pwd)"

OVERALL_STATUS=0

# ---------------------------------------------------------------------------
# Section: extract-dict
# ---------------------------------------------------------------------------
section_extract_dict() {
    local extractor="${STE_DIR}/extract-dict.py"
    local fixture="${SCRIPT_DIR}/fixtures/dict-excerpt.txt"
    local expected_dir="${SCRIPT_DIR}/fixtures/expected"
    local tmp_dir
    local status=0

    if [[ ! -f "${extractor}" ]]; then
        echo "FAIL extract-dict: extractor script missing at ${extractor}"
        return 1
    fi

    tmp_dir="$(mktemp -d)"
    trap 'rm -rf "${tmp_dir}"' RETURN

    if ! python3 "${extractor}" "${fixture}" --out "${tmp_dir}"; then
        echo "FAIL extract-dict: extractor exited non-zero"
        return 1
    fi

    local name
    for name in approved unapproved verb-forms recurring-errors; do
        local actual="${tmp_dir}/${name}.tsv"
        local expected="${expected_dir}/${name}.tsv"

        if [[ ! -f "${actual}" ]]; then
            echo "FAIL extract-dict: missing output ${name}.tsv"
            status=1
            continue
        fi

        if ! diff -u "${expected}" "${actual}" > "${tmp_dir}/${name}.diff"; then
            echo "FAIL extract-dict: ${name}.tsv mismatch"
            cat "${tmp_dir}/${name}.diff"
            status=1
        fi
    done

    if [[ "${status}" -eq 0 ]]; then
        echo "PASS extract-dict"
        return 0
    else
        echo "FAIL extract-dict"
        return 1
    fi
}

if ! section_extract_dict; then
    OVERALL_STATUS=1
fi

# ---------------------------------------------------------------------------
# (later sections, e.g. linter fixtures, can be appended below this line)
# ---------------------------------------------------------------------------

if [[ "${OVERALL_STATUS}" -eq 0 ]]; then
    echo "SUMMARY: all sections passed"
else
    echo "SUMMARY: one or more sections failed"
fi

exit "${OVERALL_STATUS}"
