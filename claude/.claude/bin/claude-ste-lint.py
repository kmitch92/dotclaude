#!/usr/bin/env python3
"""claude-ste-lint.py -- Simplified Technical English (STE) linter.

Lints text (or the last assistant turn of a Claude Code transcript, or a
stored gate-result state file) against a fixed table of 13 warn-class
checks: ste/rules.tsv carries each check's class, scope, message and fix
text, and ste/phrases.tsv carries the NARRATION, FILLER-OPEN and SLOP
phrase lists. There is no dictionary; the linter runs with none present.
Exit codes: 0 clean, 1 one or more warnings, 3 linter failure (bad args,
missing rule/phrase file, exception). Formats: human, model (for
hook/reminder consumption), json (machine-readable, also used for --log).
Python 3 stdlib only.
"""

import argparse
import json
import os
import re
import sys
from datetime import datetime, timezone

# ---------------------------------------------------------------------------
# Module-level constants
# ---------------------------------------------------------------------------

# STATE WORDS: the verb "be" followed by one of these participles describes
# a state, not an action, so PASSIVE-BY must not fire.
# See tests/fixtures/lint/warn-fp-passive.md.
STATE_WORDS = {
    "closed", "open", "complete", "completed", "clean", "ready", "full",
    "empty", "correct", "incorrect", "present", "absent", "visible", "set",
    "done", "installed", "attached", "connected", "disconnected", "locked",
    "unlocked",
}

# Irregular participles whose base/participle form does not end in -ed/-en
# (run, put, cut, ...). PASSIVE-BY's trailing "by <agent>" is itself a
# strong passive-voice signal, so these are accepted alongside any word
# ending in -ed/-en.
IRREGULAR_PARTICIPLES = {
    "run", "put", "cut", "set", "sent", "built", "made", "held", "found",
    "written", "given", "taken", "done", "kept", "read", "left", "lost",
    "met", "paid", "said", "told", "won", "brought", "caught", "thought",
    "bought",
}

UNITS = {
    "knots", "kt", "kts", "kb", "mb", "gb", "tb", "ms", "s", "sec", "secs",
    "seconds", "min", "mins", "minutes", "hr", "hrs", "hours", "km", "m",
    "cm", "mm", "ft", "in", "lb", "lbs", "kg", "g", "hz", "khz", "mhz",
    "ghz", "v", "a", "w", "px", "pt",
}

BOX_CHARS = set("─│┌┐└┘├┤┬┴┼═║╔╗╚╝╠╣╦╩╬▀▄█▌▐░▒▓")

ABBREV_SET = ("e.g.", "i.e.", "etc.", "vs.", "cf.", "n.b.", "et al.")

LIST_ITEM_RE = re.compile(r'^(?:[-*•]\s+|\d+[.)]\s+)')
ALSO_RE = re.compile(r'^Also:\s*')

FENCE_RE = re.compile(r'```.*?```', re.DOTALL)
INLINE_CODE_RE = re.compile(r'`([^`\n]+)`')
URL_RE = re.compile(r'\b(?:https?://|www\.)\S+')
HOME_PATH_RE = re.compile(r'~(?:/[\w.\-]+)+')
WIN_PATH_RE = re.compile(r'\b[A-Za-z]:\\[\w\\.\-]*')
ABS_PATH_RE = re.compile(r'(?<![\w/])(?:/[\w.\-]+){2,}')

QUOTE_RE = re.compile(r'"[^"]*"|“[^”]*”')
GENERIC_TOKEN_RE = re.compile(
    r"\"[^\"]*\"|“[^”]*”|[A-Za-z0-9_]+(?:['.,\-][A-Za-z0-9_]+)*%?"
)

CONTRACTION_RE = re.compile(
    r"\b\w+n't\b|\b(?:it|that|there|what|who|let|here)'s\b|\b\w+'(?:re|ll|ve|d|m)\b",
    re.IGNORECASE,
)
LATIN_RE = re.compile(
    # A blanket trailing \b (as the spec's regex sketch has it) never fires
    # after a literal "." (both the "." and the following space/end are
    # non-word, so there is no \w/\W transition for \b to match on) --
    # each alternative ends its own way instead.
    r"\be\.g\.|\bi\.e\.|\bet al\.|\bcf\.|\bn\.b\.|\betc\.|\betc\b|\bvs\.|\bvs\b|\bvia\b",
    re.IGNORECASE,
)
THIS_PRONOUN_RE = re.compile(
    r"^(?:This|It|That)\s+(?:is|was|means|allows|ensures|makes|gives|will|"
    r"can|lets|helps|prevents|causes|keeps|avoids)\b",
    re.IGNORECASE,
)
PASSIVE_BY_RE = re.compile(
    r"\b(?:is|are|was|were|be|been)\s+(?:not\s+)?(\w+)\s+by\b", re.IGNORECASE
)

# ---------------------------------------------------------------------------
# Data loading
# ---------------------------------------------------------------------------


class Data:
    def __init__(self):
        self.rules = {}
        self.phrases = {}
        self.phrase_res = {}


def load_rules(path):
    rules = {}
    if not os.path.isfile(path):
        return rules
    with open(path, encoding='utf-8') as f:
        first = True
        for line in f:
            line = line.rstrip('\n')
            if first:
                first = False
                continue
            if not line.strip() or line.lstrip().startswith('#'):
                continue
            parts = line.split('\t')
            if len(parts) < 6:
                continue
            rid, ste_rule, cls, scope, message, fix = parts[:6]
            rules[rid] = {
                'ste_rule': ste_rule, 'class': cls, 'scope': scope,
                'message': message, 'fix': fix,
            }
    return rules


def load_phrases(path):
    """phrase<TAB>check<TAB>fix per line, '#' comments, blank lines and the
    header row skipped. check is one of NARRATION, FILLER-OPEN, SLOP."""
    phrases = {'NARRATION': {}, 'FILLER-OPEN': {}, 'SLOP': {}}
    if not os.path.isfile(path):
        return phrases
    header_skipped = False
    with open(path, encoding='utf-8') as f:
        for line in f:
            line = line.rstrip('\n')
            if not line.strip() or line.lstrip().startswith('#'):
                continue
            if not header_skipped:
                header_skipped = True
                continue
            parts = line.split('\t')
            if len(parts) < 3:
                continue
            phrase = parts[0].strip().lower()
            check = parts[1].strip()
            fix = parts[2].strip()
            if not phrase or check not in phrases:
                continue
            phrases[check][phrase] = fix
    return phrases


def compile_phrase_regex(phrase_map):
    """One word-boundary alternation regex for a phrase->fix map, longest
    phrase first (then alphabetical) so matching never depends on dict or
    set iteration order."""
    if not phrase_map:
        return None
    ordered = sorted(phrase_map.keys(), key=lambda p: (-len(p), p))
    pattern = r'\b(?:%s)\b' % '|'.join(re.escape(p) for p in ordered)
    return re.compile(pattern, re.IGNORECASE)


def load_data():
    script_dir = os.path.dirname(os.path.realpath(__file__))
    data_dir = os.environ.get('STE_DATA_DIR') or os.path.join(script_dir, '..', 'ste')

    data = Data()
    try:
        data.rules = load_rules(os.path.join(data_dir, 'rules.tsv'))
        data.phrases = load_phrases(os.path.join(data_dir, 'phrases.tsv'))
        data.phrase_res = {
            cid: compile_phrase_regex(pmap) for cid, pmap in data.phrases.items()
        }
    except Exception as exc:  # noqa: BLE001
        sys.stderr.write("claude-ste-lint: failed to load rule/phrase data: %s\n" % exc)
        sys.exit(3)
    return data


# ---------------------------------------------------------------------------
# P1: code/url/path substitution, P2: line filtering
# ---------------------------------------------------------------------------

FRONTMATTER_DESC_RE = re.compile(r'^\s*description:\s*(.*)$')


def strip_frontmatter(text):
    """Drop YAML frontmatter (a line of three dashes, key/value lines, a
    second line of three dashes) when it opens the file, next to P2's rule
    for dropping a heading or a table row (_is_dropped_line). A config
    value is not prose, so every key/value line is blanked out here before
    P1/P2 run -- except the value after "description:", which Claude Code
    shows to a model, so it stays prose and keeps going through the normal
    checks. Detection only counts the very start of the file: leading blank
    lines and whole-line HTML comments (the fixture contract's own
    "<!-- expect: ... -->" header) are skipped first, then the next line
    must be exactly "---". A "---" later in the file is a horizontal rule,
    already dropped by _is_dropped_line -- see tests/fixtures/lint/
    warn-fp-frontmatter.md.
    """
    lines = text.split('\n')
    n = len(lines)
    i = 0
    while i < n:
        stripped = lines[i].strip()
        if not stripped:
            i += 1
            continue
        if stripped.startswith('<!--') and stripped.endswith('-->'):
            i += 1
            continue
        break
    if i >= n or lines[i].strip() != '---':
        return text
    open_idx = i
    close_idx = None
    for j in range(open_idx + 1, n):
        if lines[j].strip() == '---':
            close_idx = j
            break
    if close_idx is None:
        return text
    for k in range(open_idx + 1, close_idx):
        m = FRONTMATTER_DESC_RE.match(lines[k])
        lines[k] = m.group(1) if m else ''
    return '\n'.join(lines)


def p1_substitute(text):
    text = FENCE_RE.sub(' ', text)
    text = INLINE_CODE_RE.sub('CODE', text)
    text = URL_RE.sub('PATH', text)
    text = HOME_PATH_RE.sub('PATH', text)
    text = WIN_PATH_RE.sub('PATH', text)
    text = ABS_PATH_RE.sub('PATH', text)
    return text


def _is_dropped_line(stripped):
    if not stripped:
        return False
    if any(c in BOX_CHARS for c in stripped):
        return True
    non_space = [c for c in stripped if not c.isspace()]
    if non_space:
        punct = sum(1 for c in non_space if not c.isalnum())
        if punct / len(non_space) > 0.4:
            return True
    if stripped.startswith('|'):
        return True
    if stripped.startswith('#'):
        return True
    if re.fullmatch(r'[-=_*]{3,}', stripped):
        return True
    if stripped.startswith('<!--') and stripped.endswith('-->'):
        return True
    return False


def p2_filter(text):
    out_lines = []
    for line in text.split('\n'):
        stripped = line.strip()
        if stripped and _is_dropped_line(stripped):
            continue
        out_lines.append(line)
    return '\n'.join(out_lines)


# ---------------------------------------------------------------------------
# Tokeniser (P3) and sentence/paragraph building (P4, P5)
# ---------------------------------------------------------------------------


class Token:
    __slots__ = ('text', 'norm', 'kind', 'exempt')

    def __init__(self, text, norm, kind, exempt):
        self.text = text
        self.norm = norm
        self.kind = kind
        self.exempt = exempt


def classify_raw(data, raw, is_first):
    if raw.startswith('"') or raw.startswith('“'):
        return Token(raw, None, 'quote', True)
    core = raw.rstrip('%')
    if re.fullmatch(r'\d+(?:,\d{3})*(?:\.\d+)?', core):
        return Token(raw, raw.lower(), 'number', True)
    letters_only = bool(re.fullmatch(r'[A-Za-z]+', raw))
    if not letters_only:
        has_digit = any(ch.isdigit() for ch in raw)
        if has_digit:
            return Token(raw, raw.lower(), 'ident', True)
        if "'" in raw:
            # Contraction/possessive (don't, it's, we'll): kept as one word
            # token for counting, never matched against a dictionary --
            # CONTRACTION already flags these via regex.
            return Token(raw, raw.lower(), 'word', False)
        if '-' in raw:
            return Token(raw, raw.lower(), 'hyphen', False)
        if '.' in raw or '_' in raw or ',' in raw:
            return Token(raw, raw.lower(), 'ident', True)
        return Token(raw, raw.lower(), 'word', False)
    if raw.isupper() and len(raw) >= 2:
        return Token(raw, raw.lower(), 'allcaps', True)
    if raw[0].isupper() and not is_first:
        return Token(raw, raw.lower(), 'proper', True)
    return Token(raw, raw.lower(), 'word', False)


def tokenize(data, content):
    raws = GENERIC_TOKEN_RE.findall(content)
    tokens = []
    for idx, raw in enumerate(raws):
        tokens.append(classify_raw(data, raw, idx == 0))
    merged = []
    i = 0
    while i < len(tokens):
        tok = tokens[i]
        if (tok.kind == 'number' and i + 1 < len(tokens)
                and tokens[i + 1].kind in ('word', 'allcaps')
                and tokens[i + 1].norm in UNITS):
            nxt = tokens[i + 1]
            merged.append(Token(tok.text + ' ' + nxt.text, None, 'numunit', True))
            i += 2
            continue
        merged.append(tok)
        i += 1
    return merged


def split_into_sentences(text):
    sentences = []
    depth = 0
    in_quote = False
    start = 0
    n = len(text)
    i = 0
    while i < n:
        c = text[i]
        if c in '"“”':
            in_quote = not in_quote
        elif c == '(':
            depth += 1
        elif c == ')':
            depth = max(0, depth - 1)
        elif c in '.!?' and depth == 0 and not in_quote:
            preceding = text[max(0, i - 6):i + 1].lower()
            is_abbrev = any(preceding.endswith(a) for a in ABBREV_SET)
            end_of_text = (i == n - 1)
            next_is_space = (i + 1 < n and text[i + 1].isspace())
            if not is_abbrev and (end_of_text or next_is_space):
                sentence = text[start:i + 1].strip()
                if sentence:
                    sentences.append(sentence)
                start = i + 1
        i += 1
    tail = text[start:].strip()
    if tail:
        sentences.append(tail)
    return sentences


def build_sentence_specs(lines):
    specs = []
    buf = []

    def flush():
        if buf:
            text = ' '.join(buf)
            for s in split_into_sentences(text):
                specs.append(('plain', s))
            buf.clear()

    for line in lines:
        stripped = line.strip()
        if not stripped:
            continue
        m_list = LIST_ITEM_RE.match(stripped)
        if m_list:
            flush()
            specs.append(('list', stripped[m_list.end():].strip()))
            continue
        if ALSO_RE.match(stripped):
            flush()
            specs.append(('also', ALSO_RE.sub('', stripped).strip()))
            continue
        buf.append(stripped)
        if stripped.endswith(':'):
            flush()
    flush()
    return specs


class Sentence:
    def __init__(self, index, paragraph_index, raw_text, tokens,
                 is_list_item, is_also_line):
        self.index = index
        self.paragraph_index = paragraph_index
        self.raw_text = raw_text
        self.scan_text = QUOTE_RE.sub('QUOTEDSPAN', raw_text)
        self.tokens = tokens
        self.is_list_item = is_list_item
        self.is_also_line = is_also_line


class Paragraph:
    def __init__(self, index):
        self.index = index
        self.sentences = []


class Doc:
    def __init__(self):
        self.paragraphs = []
        self.prose_words = 0


def build_doc(data, text):
    doc = Doc()
    sentence_index = 0
    for block in re.split(r'\n\s*\n', text):
        lines = [ln for ln in block.split('\n') if ln.strip()]
        if not lines:
            continue
        specs = build_sentence_specs(lines)
        if not specs:
            continue
        para = Paragraph(len(doc.paragraphs))
        for kind, content in specs:
            is_list_item = (kind == 'list')
            is_also_line = (kind == 'also')
            tokens = tokenize(data, content)
            sent = Sentence(sentence_index, para.index, content, tokens,
                             is_list_item, is_also_line)
            para.sentences.append(sent)
            doc.prose_words += len(tokens)
            sentence_index += 1
        doc.paragraphs.append(para)
    return doc


# ---------------------------------------------------------------------------
# Checks
# ---------------------------------------------------------------------------


def _mk(text, hint=None):
    return {'text': text, 'hint': hint}


def check_sentence_length(data, sentence):
    limit = 25
    n = len(sentence.tokens)
    if n > limit:
        excerpt = sentence.raw_text[:80]
        return [_mk(excerpt, "%d>%d" % (n, limit))]
    return []


def check_contraction(data, sentence):
    out = []
    for m in CONTRACTION_RE.finditer(sentence.scan_text):
        out.append(_mk(m.group(0)))
    return out


def check_passive_by(data, sentence):
    out = []
    for m in PASSIVE_BY_RE.finditer(sentence.scan_text):
        word = m.group(1)
        wl = word.lower()
        if wl in STATE_WORDS:
            continue
        # The trailing "by <agent>" is itself a strong passive-voice signal,
        # so accept any -ed/-en word, plus the small set of irregular
        # participles whose form doesn't end that way (run, put, cut, ...).
        if wl.endswith('ed') or wl.endswith('en') or wl in IRREGULAR_PARTICIPLES:
            out.append(_mk(m.group(0)))
    return out


def check_semicolon(data, sentence):
    if ';' in sentence.scan_text:
        return [_mk(sentence.raw_text[:80])]
    return []


def check_latin(data, sentence):
    return [_mk(m.group(0)) for m in LATIN_RE.finditer(sentence.scan_text)]


def check_this_pronoun(data, sentence):
    if THIS_PRONOUN_RE.match(sentence.scan_text.strip()):
        return [_mk(sentence.raw_text[:60])]
    return []


def check_narration(data, sentence):
    rx = data.phrase_res.get('NARRATION')
    if rx is None:
        return []
    out = []
    for m in rx.finditer(sentence.scan_text):
        fix = data.phrases['NARRATION'].get(m.group(0).lower())
        out.append(_mk(m.group(0), fix))
    return out


def check_filler_open(data, sentence):
    """Fires only when the sentence (already known to be the first of its
    paragraph -- see run_checks) starts with a FILLER-OPEN phrase."""
    rx = data.phrase_res.get('FILLER-OPEN')
    if rx is None:
        return []
    text = sentence.scan_text.lstrip()
    m = rx.match(text)
    if not m:
        return []
    fix = data.phrases['FILLER-OPEN'].get(m.group(0).lower())
    return [_mk(m.group(0), fix)]


def check_slop(data, sentence):
    rx = data.phrase_res.get('SLOP')
    if rx is None:
        return []
    out = []
    for m in rx.finditer(sentence.scan_text):
        fix = data.phrases['SLOP'].get(m.group(0).lower())
        out.append(_mk(m.group(0), fix))
    return out


PER_SENTENCE_CHECKS = {
    'SENTENCE-LENGTH': check_sentence_length,
    'CONTRACTION': check_contraction,
    'SEMICOLON': check_semicolon,
    'LATIN': check_latin,
    'PASSIVE-BY': check_passive_by,
    'THIS-PRONOUN': check_this_pronoun,
    'NARRATION': check_narration,
    'FILLER-OPEN': check_filler_open,
    'SLOP': check_slop,
}


def run_checks(data, doc, args):
    violations = []
    warned_ids = set()

    def check_scope_ok(rid):
        rule = data.rules.get(rid)
        if rule is None:
            if rid not in warned_ids:
                warned_ids.add(rid)
                sys.stderr.write(
                    "claude-ste-lint: check %s has no rules.tsv entry, skipped\n" % rid
                )
            return None
        if rule['scope'] == 'main' and args.scope == 'sub':
            return None
        return rule

    for p in doc.paragraphs:
        for idx, s in enumerate(p.sentences):
            for rid, fn in PER_SENTENCE_CHECKS.items():
                rule = check_scope_ok(rid)
                if rule is None:
                    continue
                if rid == 'FILLER-OPEN' and idx != 0:
                    continue
                for h in fn(data, s):
                    violations.append({
                        'id': rid, 'cls': rule['class'],
                        'text': h['text'], 'hint': h['hint'] or rule['fix'],
                        'sentence_index': s.index,
                    })

    # Paragraph/document-level checks.
    pl_rule = check_scope_ok('PARAGRAPH-LENGTH')
    if pl_rule is not None:
        for p in doc.paragraphs:
            n = sum(1 for s in p.sentences if not s.is_list_item)
            if n > 6:
                violations.append({
                    'id': 'PARAGRAPH-LENGTH', 'cls': pl_rule['class'],
                    'text': '', 'hint': "%d>6" % n,
                    'sentence_index': p.sentences[0].index if p.sentences else 0,
                })

    pw_rule = check_scope_ok('PROSE-WORDS')
    if pw_rule is not None:
        if doc.prose_words > args.budget:
            violations.append({
                'id': 'PROSE-WORDS', 'cls': pw_rule['class'], 'text': '',
                'hint': "%d>%d" % (doc.prose_words, args.budget),
                'sentence_index': 0,
            })

    also_sentences = [s for p in doc.paragraphs for s in p.sentences if s.is_also_line]

    ac_rule = check_scope_ok('ALSO-COUNT')
    if ac_rule is not None and len(also_sentences) > 3:
        violations.append({
            'id': 'ALSO-COUNT', 'cls': ac_rule['class'], 'text': '',
            'hint': "%d>3" % len(also_sentences),
            'sentence_index': also_sentences[0].index,
        })

    al_rule = check_scope_ok('ALSO-LENGTH')
    if al_rule is not None:
        for s in also_sentences:
            n = len(s.tokens)
            if n > 20:
                violations.append({
                    'id': 'ALSO-LENGTH', 'cls': al_rule['class'],
                    'text': s.raw_text[:60], 'hint': "%d>20" % n,
                    'sentence_index': s.index,
                })

    return violations


# ---------------------------------------------------------------------------
# Scope-sub extraction
# ---------------------------------------------------------------------------

SCOUT_LINE_RE = re.compile(r'^/\S+:\d+\s+—\s+(.*)$', re.MULTILINE)
WORKER_LABEL_RE = re.compile(
    r'(?:result per check|result|bail reason):\s*', re.IGNORECASE
)


def extract_scope_sub(text):
    scout_matches = SCOUT_LINE_RE.findall(text)
    if scout_matches:
        return '\n'.join(scout_matches)
    matches = list(WORKER_LABEL_RE.finditer(text))
    if matches:
        parts = []
        for idx, m in enumerate(matches):
            start = m.end()
            end = matches[idx + 1].start() if idx + 1 < len(matches) else len(text)
            seg = text[start:end].strip()
            if seg:
                parts.append(seg)
        if parts:
            return '\n'.join(parts)
    return text


# ---------------------------------------------------------------------------
# Rendering
# ---------------------------------------------------------------------------


def render_line(v):
    text = v['text']
    hint = v['hint']
    if text and hint:
        return '%s "%s" -> %s' % (v['id'], text, hint)
    if hint:
        return '%s %s' % (v['id'], hint)
    if text:
        return '%s "%s"' % (v['id'], text)
    return v['id']


def sort_key(v):
    return (0 if v['cls'] == 'block' else 1, v['sentence_index'])


def render(violations, fmt, prose_words, rc, args):
    ordered = sorted(violations, key=sort_key)
    block_n = sum(1 for v in violations if v['cls'] == 'block')
    warn_n = sum(1 for v in violations if v['cls'] == 'warn')

    if fmt == 'json':
        counts = {}
        for v in violations:
            counts[v['id']] = counts.get(v['id'], 0) + 1
        obj = {
            'ts': datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'),
            'session': args.session if args.session else None,
            'event': 'lint',
            'scope': args.scope,
            'prose_words': prose_words,
            'rc': rc,
            'block': [{'id': v['id'], 'text': v['text'], 'hint': v['hint']}
                      for v in ordered if v['cls'] == 'block'],
            'warn': [{'id': v['id'], 'text': v['text'], 'hint': v['hint']}
                     for v in ordered if v['cls'] == 'warn'],
            'counts': counts,
        }
        return json.dumps(obj), obj

    if fmt == 'model':
        if rc == 1:
            first = "Your last reply broke these STE rules. Write the next reply without them."
        else:
            return "STE: clean (%d prose words)." % prose_words, None
        lines = [first]
        for v in ordered[:25]:
            lines.append(render_line(v))
        if len(ordered) > 25:
            lines.append('+%d more' % (len(ordered) - 25))
        return '\n'.join(lines), None

    # human
    lines = ["STE: %d block, %d warn, %d prose words" % (block_n, warn_n, prose_words)]
    for v in ordered:
        lines.append(render_line(v))
    return '\n'.join(lines), None


def build_json_obj(violations, prose_words, rc, args):
    counts = {}
    for v in violations:
        counts[v['id']] = counts.get(v['id'], 0) + 1
    ordered = sorted(violations, key=sort_key)
    return {
        'ts': datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'),
        'session': args.session if args.session else None,
        'event': 'lint',
        'scope': args.scope,
        'prose_words': prose_words,
        'rc': rc,
        'block': [{'id': v['id'], 'text': v['text'], 'hint': v['hint']}
                  for v in ordered if v['cls'] == 'block'],
        'warn': [{'id': v['id'], 'text': v['text'], 'hint': v['hint']}
                 for v in ordered if v['cls'] == 'warn'],
        'counts': counts,
    }


def write_log(violations, prose_words, rc, args):
    log_path = os.environ.get('STE_LOG') or os.path.join(
        os.path.expanduser('~'), '.claude', 'ste', 'lint.log.jsonl')
    obj = build_json_obj(violations, prose_words, rc, args)
    try:
        os.makedirs(os.path.dirname(log_path), exist_ok=True)
        with open(log_path, 'a', encoding='utf-8') as f:
            f.write(json.dumps(obj) + '\n')
    except OSError:
        pass


# ---------------------------------------------------------------------------
# --state and --transcript handling
# ---------------------------------------------------------------------------


def handle_state(path):
    output = ''
    rc = 0
    try:
        with open(path, encoding='utf-8') as f:
            obj = json.load(f)
        output = obj.get('output', '') or ''
        rc_val = obj.get('rc', 0)
        rc = rc_val if isinstance(rc_val, int) else 0
    except Exception:  # noqa: BLE001
        output = ''
        rc = 0
    if output:
        sys.stdout.write(output)
        if not output.endswith('\n'):
            sys.stdout.write('\n')
    sys.exit(rc)


def _iter_jsonl_records(path):
    records = []
    with open(path, encoding='utf-8') as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                records.append(json.loads(line))
            except Exception:  # noqa: BLE001
                continue
    return records


def _is_genuine_user_prompt(rec):
    if rec.get('type') != 'user':
        return False
    message = rec.get('message')
    if not isinstance(message, dict):
        return False
    content = message.get('content')
    if isinstance(content, str):
        return True
    if isinstance(content, list):
        return not any(
            isinstance(c, dict) and c.get('type') == 'tool_result' for c in content
        )
    return False


def extract_transcript_text(path):
    try:
        records = _iter_jsonl_records(path)
    except OSError:
        return ''

    last_prompt_idx = None
    for idx, rec in enumerate(records):
        if _is_genuine_user_prompt(rec):
            last_prompt_idx = idx
    if last_prompt_idx is None:
        return ''

    assistant_records = [
        rec for rec in records[last_prompt_idx + 1:] if rec.get('type') == 'assistant'
    ]
    if not assistant_records:
        return ''

    last_message_id = None
    for rec in assistant_records:
        mid = (rec.get('message') or {}).get('id')
        if mid:
            last_message_id = mid
    if last_message_id is None:
        return ''

    texts = []
    for rec in assistant_records:
        message = rec.get('message') or {}
        if message.get('id') != last_message_id:
            continue
        for block in message.get('content') or []:
            if isinstance(block, dict) and block.get('type') == 'text':
                texts.append(block.get('text', ''))
    return '\n\n'.join(texts)


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------


def build_arg_parser():
    parser = argparse.ArgumentParser(prog='claude-ste-lint.py', add_help=True)
    parser.add_argument('--text')
    parser.add_argument('--state')
    parser.add_argument('--transcript')
    parser.add_argument('--last-assistant', action='store_true')
    parser.add_argument('--format', choices=['human', 'model', 'json'], default='human')
    parser.add_argument('--scope', choices=['main', 'sub'], default='main')
    parser.add_argument('--budget', type=int, default=120)
    parser.add_argument('--log', action='store_true')
    parser.add_argument('--session')
    return parser


def read_text_source(spec):
    if spec == '-':
        return sys.stdin.read()
    with open(spec, encoding='utf-8') as f:
        return f.read()


def main(argv=None):
    parser = build_arg_parser()
    try:
        args = parser.parse_args(argv)
    except SystemExit as exc:
        sys.exit(3 if exc.code not in (0,) else 0)

    if args.state:
        handle_state(args.state)
        return

    try:
        if args.transcript:
            text = extract_transcript_text(args.transcript)
        elif args.text is not None:
            text = read_text_source(args.text)
        else:
            sys.stderr.write(
                "claude-ste-lint: one of --text, --state, --transcript is required\n"
            )
            sys.exit(3)

        data = load_data()

        lint_text = text
        if args.scope == 'sub':
            lint_text = extract_scope_sub(text)

        pre = strip_frontmatter(lint_text)
        pre = p1_substitute(pre)
        pre = p2_filter(pre)
        doc = build_doc(data, pre)
        violations = run_checks(data, doc, args)
        rc = 1 if violations else 0

        out_str, _ = render(violations, args.format, doc.prose_words, rc, args)
        print(out_str)

        if args.log:
            write_log(violations, doc.prose_words, rc, args)

        sys.exit(rc)
    except SystemExit:
        raise
    except Exception as exc:  # noqa: BLE001
        sys.stderr.write("claude-ste-lint: unexpected failure: %s\n" % exc)
        sys.exit(3)


if __name__ == '__main__':
    main()
