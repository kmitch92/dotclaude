#!/usr/bin/env python3
"""Extract word lists from an ASD-STE100 dictionary text file produced by
`pdftotext -layout`.

Usage:
    python3 extract-dict.py TEXTFILE [--out DIR]

Writes four tab-separated files to DIR (default: <script dir>/dict):
    approved.tsv          word<TAB>pos
    unapproved.tsv         word<TAB>pos<TAB>alternatives (pipe-joined, may be empty)
    verb-forms.tsv         base<TAB>s-form<TAB>past<TAB>participle
    recurring-errors.tsv   non_ste<TAB>ste

Prints five counts to stdout: approved entries, unapproved entries,
unapproved entries with >=1 alternative, verb-forms rows, recurring-errors
rows.
"""
import argparse
import os
import re
import sys

POS = r'(?:n|v|adj|adv|prep|conj|pron|art|TN)'

HEADER_LINE1_RE = re.compile(r'^Word\s+Approved meaning/\s*$')
HEADER_LINE2_RE = re.compile(
    r'^\(part of speech\)\s+ALTERNATIVES\s+STE EXAMPLE\s+Non-STE example\s*$'
)

HEADWORD_RE = re.compile(r'^(.+) \(' + POS + r'\)(,)?$')
BARE_POS_RE = re.compile(r'^\(' + POS + r'\)(,)?$')
FORM_RE = re.compile(r"^[A-Z][A-Z' \-]*(,)?$")
ALT_RE = re.compile(
    r"([A-Z][A-Z'\-]*(?: [A-Z][A-Z'\-]*)*) \((" + POS[3:-1] + r")\)"
)

RECURRING_HEADING_RE = re.compile(r'^List of recurring errors(?: \(continued\))?\s*$')
RECURRING_COLUMN_HEADER_RE = re.compile(r'^\s*Non-STE\s+STE\s*$')

BOILERPLATE_MARKERS = (
    'Part 2 - Dictionary',
    'Issue 9',
    'Simplified Technical English',
    'Highlights',
)
DATE_RE = re.compile(r'\d{4}-\d{2}-\d{2}')


def is_boilerplate(line):
    if DATE_RE.search(line):
        return True
    for marker in BOILERPLATE_MARKERS:
        if marker in line:
            return True
    return False


def find_header(lines):
    """Return (index_of_line1, col2, col3, col4) for the first strict
    two-line column header found in `lines`, or None."""
    for i in range(len(lines) - 1):
        l1, l2 = lines[i], lines[i + 1]
        if HEADER_LINE1_RE.match(l1) and HEADER_LINE2_RE.match(l2):
            col2 = l1.index('Approved meaning/')
            col3 = l2.index('STE EXAMPLE')
            col4 = l2.index('Non-STE example')
            return i, col2, col3, col4
    return None


def clean_body_lines(lines, start_index):
    """Lines after a header, with blanks and boilerplate removed."""
    out = []
    for line in lines[start_index:]:
        if line.strip() == '':
            continue
        if is_boilerplate(line):
            continue
        out.append(line)
    return out


def extract_recurring_errors(text):
    lines = text.replace('\x0c', '').split('\n')
    state = 'NONE'  # NONE -> WAITING_HEADER -> CAPTURING
    ste_col = None
    rows = {}
    for line in lines:
        if RECURRING_HEADING_RE.match(line):
            state = 'WAITING_HEADER'
            continue
        if RECURRING_COLUMN_HEADER_RE.match(line):
            if state == 'WAITING_HEADER':
                ste_col = line.rfind('STE')
                state = 'CAPTURING'
            continue
        if is_boilerplate(line):
            continue
        if line.strip() == '':
            continue
        if state == 'CAPTURING':
            non_ste = line[:ste_col].strip()
            ste = line[ste_col:].strip()
            if re.match(r'^\S.*\(' + POS + r'\)$', non_ste) and ste:
                rows[(non_ste, ste)] = True
            else:
                state = 'NONE'
        # WAITING_HEADER: ignore unmatched lines (intro prose, etc.)
    return sorted(rows.keys())


def finalize_entry(current, approved, unapproved, verb_forms):
    if current is None:
        return
    word = current['word'].strip()
    pos = current['pos']
    if current.get('collecting_forms'):
        approved[(word.lower(), pos)] = True
        forms = current['forms']
        if len(forms) >= 2:
            s_form = forms[0]
            past = forms[1]
            participle = forms[2] if len(forms) >= 3 else past
            verb_forms[word.lower()] = (
                word.lower(),
                s_form.lower(),
                past.lower(),
                participle.lower(),
            )
        return
    if current['approved']:
        approved[(word.lower(), pos)] = True
    else:
        key = (word.lower(), pos)
        if key not in unapproved:
            unapproved[key] = list(current['alts'])


def extract_dictionary_entries(pages):
    approved = {}
    unapproved = {}
    verb_forms = {}

    dict_start = None
    for p_idx, page in enumerate(pages):
        lines = page.split('\n')
        hdr = find_header(lines)
        if hdr is None:
            continue
        hdr_idx, col2, col3, col4 = hdr
        body = clean_body_lines(lines, hdr_idx + 2)
        if not body:
            continue
        first_col1 = body[0][:col2].strip()
        if first_col1.startswith('A (art)'):
            dict_start = p_idx
            break

    if dict_start is None:
        return approved, unapproved, verb_forms

    for page in pages[dict_start:]:
        lines = page.split('\n')
        hdr = find_header(lines)
        if hdr is None:
            continue
        hdr_idx, col2, col3, col4 = hdr
        body = clean_body_lines(lines, hdr_idx + 2)

        current = None
        i = 0
        n = len(body)
        while i < n:
            raw = body[i]
            col1 = raw[:col2].strip()
            col2_text = raw[col2:col3].strip() if len(raw) > col2 else ''

            if col1 == '':
                if current is not None and not current.get('collecting_forms'):
                    if not current['approved']:
                        for m in ALT_RE.finditer(col2_text):
                            current['alts'].append(f'{m.group(1)}({m.group(2)})')
                i += 1
                continue

            m = HEADWORD_RE.match(col1)
            if m:
                finalize_entry(current, approved, unapproved, verb_forms)
                pos_m2 = re.match(r'^(.+) \((' + POS[3:-1] + r')\)(,)?$', col1)
                pos_code = pos_m2.group(2)
                word_text = pos_m2.group(1)
                comma = pos_m2.group(3)
                approved_word = word_text.isupper()
                if comma:
                    current = {
                        'word': word_text,
                        'pos': pos_code,
                        'approved': approved_word,
                        'collecting_forms': True,
                        'forms': [],
                    }
                else:
                    current = {
                        'word': word_text,
                        'pos': pos_code,
                        'approved': approved_word,
                        'alts': [],
                    }
                    if not approved_word:
                        for am in ALT_RE.finditer(col2_text):
                            current['alts'].append(f'{am.group(1)}({am.group(2)})')
                i += 1
                continue

            if current is not None and current.get('collecting_forms') and FORM_RE.match(col1):
                current['forms'].append(col1.rstrip(','))
                i += 1
                continue

            if i + 1 < n:
                next_col1 = body[i + 1][:col2].strip()
                bm = BARE_POS_RE.match(next_col1)
                if bm:
                    combined = f'{col1} {next_col1}'
                    cm = re.match(r'^(.+) \((' + POS[3:-1] + r')\)(,)?$', combined)
                    if cm:
                        finalize_entry(current, approved, unapproved, verb_forms)
                        word_text = cm.group(1)
                        pos_code = cm.group(2)
                        comma = cm.group(3)
                        approved_word = word_text.isupper()
                        if comma:
                            current = {
                                'word': word_text,
                                'pos': pos_code,
                                'approved': approved_word,
                                'collecting_forms': True,
                                'forms': [],
                            }
                        else:
                            current = {
                                'word': word_text,
                                'pos': pos_code,
                                'approved': approved_word,
                                'alts': [],
                            }
                            if not approved_word:
                                wrap_col2 = col2_text
                                next_raw = body[i + 1]
                                next_col2_text = (
                                    next_raw[col2:col3].strip()
                                    if len(next_raw) > col2
                                    else ''
                                )
                                for am in ALT_RE.finditer(wrap_col2 + ' ' + next_col2_text):
                                    current['alts'].append(f'{am.group(1)}({am.group(2)})')
                        i += 2
                        continue

            if current is not None and current.get('collecting_forms'):
                finalize_entry(current, approved, unapproved, verb_forms)
                current = None
                continue

            finalize_entry(current, approved, unapproved, verb_forms)
            current = None
            i += 1

        finalize_entry(current, approved, unapproved, verb_forms)

    return approved, unapproved, verb_forms


def write_tsv(path, rows):
    with open(path, 'w', encoding='utf-8') as f:
        for row in rows:
            f.write('\t'.join(row) + '\n')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('textfile')
    parser.add_argument('--out', default=None)
    args = parser.parse_args()

    script_dir = os.path.dirname(os.path.abspath(__file__))
    out_dir = args.out if args.out else os.path.join(script_dir, 'dict')
    os.makedirs(out_dir, exist_ok=True)

    with open(args.textfile, encoding='utf-8') as f:
        text = f.read()

    pages = text.split('\x0c')

    approved, unapproved, verb_forms = extract_dictionary_entries(pages)
    recurring = extract_recurring_errors(text)

    approved_rows = sorted(approved.keys())
    unapproved_rows = [
        (word, pos, '|'.join(alts)) for (word, pos), alts in unapproved.items()
    ]
    unapproved_rows.sort()
    verb_forms_rows = sorted(verb_forms.values())

    write_tsv(os.path.join(out_dir, 'approved.tsv'), approved_rows)
    write_tsv(os.path.join(out_dir, 'unapproved.tsv'), unapproved_rows)
    write_tsv(os.path.join(out_dir, 'verb-forms.tsv'), verb_forms_rows)
    write_tsv(os.path.join(out_dir, 'recurring-errors.tsv'), recurring)

    unapproved_with_alt = sum(1 for r in unapproved_rows if r[2])

    print(f'approved entries: {len(approved_rows)}')
    print(f'unapproved entries: {len(unapproved_rows)}')
    print(f'unapproved with alternative: {unapproved_with_alt}')
    print(f'verb-forms rows: {len(verb_forms_rows)}')
    print(f'recurring-errors rows: {len(recurring)}')


if __name__ == '__main__':
    main()
