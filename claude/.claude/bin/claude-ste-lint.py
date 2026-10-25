#!/usr/bin/env python3
"""claude-ste-lint.py -- Simplified Technical English (STE) linter.

Lints text (or the last assistant turn of a Claude Code transcript, or a
stored gate-result state file) against the rule set in plan section 4's
linter spec (ste/dict/linter-spec.txt): preprocessing P1-P6 normalises the
text, then a fixed table of checks (block-class and warn-class, driven by
ste/rules.tsv for class/scope/message/fix) runs over paragraphs/sentences
built from that normalised text. Exit codes: 0 clean, 1 warn-class only,
2 at least one block-class violation, 3 linter failure (missing dict, bad
args, exception). Formats: human, model (for hook/reminder consumption),
json (machine-readable, also used for --log). Python 3 stdlib only.
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

# FUNCTION WORDS AND AUXILIARIES (linter-spec.txt lines 27-34): the dictionary
# only lists base forms (be, have, do, can, will, must, not) plus articles,
# demonstratives and the D2 pronoun deviation (i, me, my) are already in
# glossary.txt. These are the inflections and extra closed-class words that
# must be treated as approved/function words in every form.
AUX_INFLECTIONS = {
    "am", "is", "are", "was", "were", "been", "being",
    "has", "had", "having",
    "does", "did",
}
ARTICLES = {"a", "an", "the"}
DEMONSTRATIVES = {"this", "that", "these", "those"}
EXTRA_PRONOUNS = {
    "i", "me", "my", "you", "your", "we", "us", "our",
    "it", "its", "they", "them", "their", "who", "which",
}
BASE_AUX = {"be", "have", "do", "can", "will", "must", "not"}
FUNCTION_WORDS = AUX_INFLECTIONS | ARTICLES | DEMONSTRATIVES | EXTRA_PRONOUNS | BASE_AUX

# STATE WORDS (linter-spec.txt lines 50-54): be + one of these participles
# describes a state, not an action, so PASSIVE/PASSIVE-BY must not fire.
# See tests/fixtures/lint/warn-fp-passive.md.
STATE_WORDS = {
    "closed", "open", "complete", "completed", "clean", "ready", "full",
    "empty", "correct", "incorrect", "present", "absent", "visible", "set",
    "done", "installed", "attached", "connected", "disconnected", "locked",
    "unlocked",
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
PROC_PREFIX_RE = re.compile(r'^(Do not|Always|Never|Then)\s+', re.IGNORECASE)

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
POSSESSIVE_RE = re.compile(r"\b(\w+)'s\b")
LATIN_RE = re.compile(
    # A blanket trailing \b (as the spec's regex sketch has it) never fires
    # after a literal "." (both the "." and the following space/end are
    # non-word, so there is no \w/\W transition for \b to match on) --
    # each alternative ends its own way instead.
    r"\be\.g\.|\bi\.e\.|\bet al\.|\bcf\.|\bn\.b\.|\betc\.|\betc\b|\bvs\.|\bvs\b|\bvia\b",
    re.IGNORECASE,
)
USING_RE = re.compile(r"\busing\b", re.IGNORECASE)
THIS_PRONOUN_RE = re.compile(
    r"^(?:This|It|That)\s+(?:is|was|means|allows|ensures|makes|gives|will|"
    r"can|lets|helps|prevents|causes|keeps|avoids)\b",
    re.IGNORECASE,
)
PERFECT_RE = re.compile(r"\b(?:have|has|had)\s+(?:not\s+)?(?:been\s+)?(\w+)\b", re.IGNORECASE)
PROGRESSIVE_RE = re.compile(
    r"\b(?:am|is|are|was|were|be|been|being)\s+(?:not\s+)?(\w+ing)\b", re.IGNORECASE
)
BEING_RE = re.compile(r"\bbeing\b", re.IGNORECASE)
PASSIVE_BY_RE = re.compile(
    r"\b(?:is|are|was|were|be|been)\s+(?:not\s+)?(\w+)\s+by\b", re.IGNORECASE
)
PASSIVE_RE = re.compile(
    r"\b(?:am|is|are|was|were|be|been)\s+(?:not\s+)?(\w+)\b(?!\s+by\b)", re.IGNORECASE
)
AND_VERB_RE = re.compile(r"\band\s+([A-Za-z]+)\b", re.IGNORECASE)
THEN_RE = re.compile(r"\bthen\b", re.IGNORECASE)
ING_PRECEDED_WORDS = {
    "by", "when", "while", "before", "after", "for", "without", "of", "in", "on",
}
POS_TARGET_WORDS = {"test", "check", "damage", "need", "fit", "insert", "follow", "press"}
POS_PRECEDING = {"to", "you", "i", "we"}

CHECK_ORDER = [
    "SENTENCE-LENGTH", "CONTRACTION", "COMPLEX-VERB", "USING", "PASSIVE-BY",
    "UNAPPROVED", "BANNED", "SEMICOLON", "LATIN",
    "PASSIVE", "ING-FORM", "NOUN-CLUSTER", "ONE-INSTRUCTION", "IMPERATIVE",
    "PARAGRAPH-LENGTH", "THIS-PRONOUN", "POSSESSIVE", "SAFETY", "UNKNOWN",
    "POS", "PROSE-WORDS", "ALSO-COUNT", "ALSO-LENGTH",
]

# ---------------------------------------------------------------------------
# Data loading
# ---------------------------------------------------------------------------


class Data:
    def __init__(self):
        self.glossary = {}
        self.glossary_phrases = {}
        self.approved = {}
        self.approved_phrases = {}
        self.banned = {}
        self.banned_phrases = {}
        self.unapproved = {}
        self.unapproved_phrases = {}
        self.british = {}
        self.form_to_base = {}
        self.participles = set()
        self.rules = {}
        self.max_phrase_words = 3


def _split_single_phrase(d, word, value):
    target = d[1] if ' ' in word else d[0]
    return target


def load_glossary_style(path):
    """word<TAB>pos per line, '#' comments, multi-word phrases allowed."""
    single, phrases = {}, {}
    if not os.path.isfile(path):
        return single, phrases
    with open(path, encoding='utf-8') as f:
        for line in f:
            line = line.rstrip('\n')
            if not line.strip() or line.lstrip().startswith('#'):
                continue
            parts = line.split('\t')
            if len(parts) < 2:
                continue
            word = parts[0].strip().lower()
            pos = parts[1].strip().lower()
            if not word or not pos:
                continue
            target = phrases if ' ' in word else single
            target.setdefault(word, set()).add(pos)
    return single, phrases


def load_banned(path):
    single, phrases = {}, {}
    if not os.path.isfile(path):
        return single, phrases
    with open(path, encoding='utf-8') as f:
        for line in f:
            line = line.rstrip('\n')
            if not line.strip() or line.lstrip().startswith('#'):
                continue
            parts = line.split('\t')
            word = parts[0].strip().lower()
            if not word:
                continue
            replacement = None
            if len(parts) > 1:
                cand = parts[1].strip()
                if cand and not cand.startswith('#'):
                    replacement = cand
            target = phrases if ' ' in word else single
            target[word] = replacement
    return single, phrases


def load_unapproved(path):
    single, phrases = {}, {}
    if not os.path.isfile(path):
        return single, phrases
    with open(path, encoding='utf-8') as f:
        for line in f:
            line = line.rstrip('\n')
            if not line.strip() or line.lstrip().startswith('#'):
                continue
            parts = line.split('\t')
            if len(parts) < 2:
                continue
            word = parts[0].strip().lower()
            pos = parts[1].strip().lower()
            alt = parts[2].strip() if len(parts) > 2 else ''
            if not word:
                continue
            target = phrases if ' ' in word else single
            target.setdefault(word, []).append((pos, alt))
    return single, phrases


def load_british(path):
    d = {}
    if not os.path.isfile(path):
        return d
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
            if len(parts) < 2:
                continue
            d[parts[0].strip().lower()] = parts[1].strip().lower()
    return d


def load_verb_forms(path):
    form_to_base = {}
    participles = set()
    if not os.path.isfile(path):
        return form_to_base, participles
    with open(path, encoding='utf-8') as f:
        for line in f:
            line = line.rstrip('\n')
            if not line.strip() or line.lstrip().startswith('#'):
                continue
            parts = line.split('\t')
            if len(parts) < 4:
                continue
            base, sform, past, part = (p.strip().lower() for p in parts[:4])
            for form in (sform, past, part):
                if form and form != base and form not in form_to_base:
                    form_to_base[form] = base
            if part:
                participles.add(part)
    return form_to_base, participles


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


def load_data():
    script_dir = os.path.dirname(os.path.realpath(__file__))
    data_dir = os.environ.get('STE_DATA_DIR') or os.path.join(script_dir, '..', 'ste')
    dict_dir = os.environ.get('STE_DICT_DIR') or os.path.join(data_dir, 'dict')

    approved_path = os.path.join(dict_dir, 'approved.tsv')
    if not os.path.isfile(approved_path):
        sys.stderr.write(
            "claude-ste-lint: dictionary not found: %s (set STE_DICT_DIR)\n" % approved_path
        )
        sys.exit(3)

    data = Data()
    try:
        data.glossary, data.glossary_phrases = load_glossary_style(
            os.path.join(data_dir, 'glossary.txt'))
        data.banned, data.banned_phrases = load_banned(os.path.join(data_dir, 'banned.txt'))
        data.british = load_british(os.path.join(data_dir, 'british.tsv'))
        data.rules = load_rules(os.path.join(data_dir, 'rules.tsv'))
        data.approved, data.approved_phrases = load_glossary_style(approved_path)
        data.unapproved, data.unapproved_phrases = load_unapproved(
            os.path.join(dict_dir, 'unapproved.tsv'))
        data.form_to_base, data.participles = load_verb_forms(
            os.path.join(dict_dir, 'verb-forms.tsv'))
    except Exception as exc:  # noqa: BLE001
        sys.stderr.write("claude-ste-lint: failed to load dictionary data: %s\n" % exc)
        sys.exit(3)
    return data


# ---------------------------------------------------------------------------
# P6 lookup normalisation
# ---------------------------------------------------------------------------


def _add_doubled_consonant_variants(add, w, suffix_len):
    stem = w[:-suffix_len]
    add(stem)
    add(stem + 'e')
    if len(stem) >= 3 and stem[-1] == stem[-2] and stem[-1] not in 'aeiou':
        add(stem[:-1])


def gen_candidates(data, w, include_verbal_suffix_strip=False):
    """P6 lookup normalisation candidates, in order, for word w.

    include_verbal_suffix_strip adds the generic "-ing/-ed with doubled
    consonant and e-restoration" step. It is deliberately NOT used by
    classify_for_dict_checks: an -ed/-ing word with no verb-forms.tsv row
    and no plain-noun/plural reading (e.g. "quoted") would otherwise land
    on an unrelated unapproved homonym (unapproved.tsv "quote v GIVE(v)")
    purely by accident of spelling -- see tests/fixtures/lint/
    warn-fp-unknown.md. is_known_any() still uses it (a broader, lower-risk
    "have we ever heard of this word" test used for UNKNOWN/proper nouns).
    """
    out = []
    seen = set()

    def add(c):
        if c and c not in seen:
            seen.add(c)
            out.append(c)

    add(w)
    if w in data.british:
        add(data.british[w])
    if w.endswith('ies') and len(w) > 4:
        add(w[:-3] + 'y')
    elif w.endswith('es') and len(w) > 3:
        add(w[:-2])
        add(w[:-1])
    elif w.endswith('s') and not w.endswith('ss') and len(w) > 2:
        add(w[:-1])
    base = data.form_to_base.get(w)
    if base:
        add(base)
    if include_verbal_suffix_strip:
        if w.endswith('ied') and len(w) > 4:
            add(w[:-3] + 'y')
        if w.endswith('ing') and len(w) > 4:
            _add_doubled_consonant_variants(add, w, 3)
        if w.endswith('ed') and len(w) > 3 and not w.endswith('ied'):
            _add_doubled_consonant_variants(add, w, 2)
    if w.endswith('est') and len(w) > 4:
        stem = w[:-3]
        add(stem)
        if len(stem) >= 3 and stem[-1] == stem[-2] and stem[-1] not in 'aeiou':
            add(stem[:-1])
    if w.endswith('er') and len(w) > 3:
        stem = w[:-2]
        add(stem)
        if len(stem) >= 3 and stem[-1] == stem[-2] and stem[-1] not in 'aeiou':
            add(stem[:-1])
    if w.endswith('ly') and len(w) > 3:
        add(w[:-2])
    return out


def strip_pos_tag(alt_token):
    m = re.match(r'^(.*?)\(\s*\w+\s*\)$', alt_token.strip())
    if m:
        return m.group(1).strip()
    return alt_token.strip()


def parse_alternatives(alt_str):
    if not alt_str:
        return []
    return [a.strip() for a in alt_str.split('|') if a.strip()]


def classify_for_dict_checks(data, word):
    """Resolve a single word for BANNED/UNAPPROVED purposes.

    Precedence is glossary > approved > banned > unapproved, searched across
    every P6-derived candidate (word-level, part-of-speech-agnostic), per the
    "key"/"complete" examples in linter-spec.txt: a word present in
    glossary.txt or approved.tsv under ANY part of speech is exempt from
    UNAPPROVED, even when unapproved.tsv also lists it under a different
    part of speech (e.g. "complete" approved as a verb, unapproved as an
    adjective: approved wins). NOTE: this also exempts "strip"/"stripped"
    (approved.tsv has "strip n") even though unapproved.tsv separately lists
    "strip v -> REMOVE(v)" -- see the REPORT for this as a documented
    disagreement with the brief's ACCEPTANCE case C, which the dictionary
    data and tests/fixtures/lint/{inflections,good-reply}.md contradict.
    """
    w = word.lower()
    # Exemption (glossary/approved) is checked across the broad candidate
    # set, including generic -ing/-ed stripping: a regular past tense of a
    # glossary/approved verb (e.g. "failed" -> "fail") must be recognised
    # even without a verb-forms.tsv row. Violation (banned/unapproved) is
    # checked only across the narrow candidate set, so an -ed/-ing word
    # that merely resembles an unrelated unapproved lemma by spelling (e.g.
    # "quoted" -> "quote") is not flagged purely by that accident -- see
    # tests/fixtures/lint/warn-fp-unknown.md.
    exempt_candidates = gen_candidates(data, w, include_verbal_suffix_strip=True)
    strict_candidates = gen_candidates(data, w, include_verbal_suffix_strip=False)

    for cand in exempt_candidates:
        if cand in data.glossary:
            pos = next(iter(data.glossary[cand]))
            return ('glossary', pos, None)

    for cand in exempt_candidates:
        if cand in data.approved:
            pos = next(iter(data.approved[cand]))
            return ('approved', pos, None)

    for cand in strict_candidates:
        if cand in data.banned:
            return ('banned', None, data.banned[cand])

    for cand in strict_candidates:
        if cand in data.unapproved:
            for (upos, altstr) in data.unapproved[cand]:
                alts = parse_alternatives(altstr)
                if alts:
                    return ('unapproved', upos, alts)

    return ('unknown', None, None)


def is_known_any(data, word):
    w = word.lower()
    if w in FUNCTION_WORDS or w in STATE_WORDS:
        return True
    for cand in gen_candidates(data, w, include_verbal_suffix_strip=True):
        if (cand in data.glossary or cand in data.approved
                or cand in data.banned or cand in data.unapproved):
            return True
    return False


def lookup_phrase(data, phrase):
    if phrase in data.glossary_phrases:
        pos = next(iter(data.glossary_phrases[phrase]))
        return ('glossary', pos, None)
    if phrase in data.approved_phrases:
        pos = next(iter(data.approved_phrases[phrase]))
        return ('approved', pos, None)
    if phrase in data.banned_phrases:
        return ('banned', None, data.banned_phrases[phrase])
    if phrase in data.unapproved_phrases:
        for (pos, altstr) in data.unapproved_phrases[phrase]:
            alts = parse_alternatives(altstr)
            if alts:
                return ('unapproved', pos, alts)
    return None


def is_participle_like(data, word):
    w = word.lower()
    if w in data.participles:
        return True
    if w.endswith('ed') or w.endswith('en'):
        if w in data.glossary and 'n' in data.glossary[w] and 'v' not in data.glossary[w]:
            return False
        return True
    return False


def is_approved_verb(data, text):
    cls, pos, _ = classify_for_dict_checks(data, text)
    if cls in ('glossary', 'approved') and pos == 'v':
        return True
    # test/check/damage/need/fit/insert/follow/press are approved only as
    # nouns (POS check's own domain) but are common, acceptable imperative
    # openers in practice -- don't also fire IMPERATIVE/ONE-INSTRUCTION/
    # SAFETY/NOUN-CLUSTER on them (tests/fixtures/good-reply.md step 2,
    # "Check the result.").
    if cls in ('glossary', 'approved') and text.lower() in POS_TARGET_WORDS:
        return True
    return False


def is_function_word(data, norm):
    if norm is None:
        return False
    if norm in FUNCTION_WORDS:
        return True
    poses = data.approved.get(norm, set()) | data.glossary.get(norm, set())
    return bool(poses & {'art', 'prep', 'conj', 'pron'})


# ---------------------------------------------------------------------------
# P1: code/url/path substitution, P2: line filtering
# ---------------------------------------------------------------------------


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
            # token for counting, never matched against the dictionaries --
            # CONTRACTION/POSSESSIVE already flag these via regex.
            return Token(raw, raw.lower(), 'word', False)
        if '-' in raw:
            return Token(raw, raw.lower(), 'hyphen', False)
        if '.' in raw or '_' in raw or ',' in raw:
            return Token(raw, raw.lower(), 'ident', True)
        return Token(raw, raw.lower(), 'word', False)
    if raw.isupper() and len(raw) >= 2:
        return Token(raw, raw.lower(), 'allcaps', True)
    if raw[0].isupper() and not is_first:
        lw = raw.lower()
        if not is_known_any(data, lw):
            return Token(raw, lw, 'proper', True)
        return Token(raw, lw, 'word', False)
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


def classify_procedural(data, is_list_item, content):
    if is_list_item:
        return True
    text = content.strip()
    m = PROC_PREFIX_RE.match(text)
    if m:
        text = text[m.end():]
    m2 = re.match(r'[A-Za-z]+', text)
    if not m2:
        return False
    return is_approved_verb(data, m2.group(0))


class Sentence:
    def __init__(self, index, paragraph_index, raw_text, tokens,
                 is_list_item, is_also_line, procedural):
        self.index = index
        self.paragraph_index = paragraph_index
        self.raw_text = raw_text
        self.scan_text = QUOTE_RE.sub('QUOTEDSPAN', raw_text)
        self.tokens = tokens
        self.is_list_item = is_list_item
        self.is_also_line = is_also_line
        self.procedural = procedural


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
            procedural = classify_procedural(data, is_list_item, content)
            sent = Sentence(sentence_index, para.index, content, tokens,
                             is_list_item, is_also_line, procedural)
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
    limit = 20 if sentence.procedural else 25
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


def check_complex_verb(data, sentence):
    out = []
    text = sentence.scan_text
    for m in PERFECT_RE.finditer(text):
        word = m.group(1)
        if is_participle_like(data, word):
            out.append(_mk(m.group(0)))
    for m in PROGRESSIVE_RE.finditer(text):
        out.append(_mk(m.group(0)))
    if BEING_RE.search(text) and not PROGRESSIVE_RE.search(text):
        out.append(_mk('being'))
    return out


def check_using(data, sentence):
    return [_mk(m.group(0)) for m in USING_RE.finditer(sentence.scan_text)]


def check_passive_by(data, sentence):
    out = []
    for m in PASSIVE_BY_RE.finditer(sentence.scan_text):
        word = m.group(1)
        if word.lower() in STATE_WORDS:
            continue
        # The trailing "by <agent>" is itself a strong passive-voice signal,
        # so also accept irregular verbs whose participle equals their base
        # form (run, put, cut, ...) and isn't in verb-forms.tsv.
        if is_participle_like(data, word) or is_approved_verb(data, word):
            out.append(_mk(m.group(0)))
    return out


def check_semicolon(data, sentence):
    if ';' in sentence.scan_text:
        return [_mk(sentence.raw_text[:80])]
    return []


def check_latin(data, sentence):
    return [_mk(m.group(0)) for m in LATIN_RE.finditer(sentence.scan_text)]


def check_passive(data, sentence):
    out = []
    for m in PASSIVE_RE.finditer(sentence.scan_text):
        word = m.group(1)
        if word.lower().endswith('ing'):
            continue
        if word.lower() in STATE_WORDS:
            continue
        if is_participle_like(data, word):
            out.append(_mk(m.group(0)))
    return out


def check_ing_form(data, sentence):
    out = []
    tokens = sentence.tokens
    for i, tok in enumerate(tokens):
        if tok.kind != 'word' or tok.norm is None:
            continue
        if not tok.norm.endswith('ing'):
            continue
        if tok.norm in data.glossary or tok.norm in data.approved:
            continue
        preceded = tokens[i - 1].norm if i > 0 else None
        if i == 0 or preceded in ING_PRECEDED_WORDS:
            out.append(_mk(tok.text))
    return out


def check_noun_cluster(data, sentence):
    out = []
    run = []

    def flush():
        if len(run) >= 4:
            out.append(_mk(' '.join(t.text for t in run)))

    for tok in sentence.tokens:
        excluded = False
        if tok.kind in ('proper', 'number', 'numunit', 'allcaps'):
            excluded = True
        elif tok.norm and tok.norm.endswith('ly'):
            excluded = True
        elif is_function_word(data, tok.norm):
            excluded = True
        elif tok.kind == 'word' and is_approved_verb(data, tok.text):
            excluded = True
        if excluded:
            flush()
            run = []
        else:
            run.append(tok)
    flush()
    return out


def check_one_instruction(data, sentence):
    if not sentence.procedural:
        return []
    if THEN_RE.search(sentence.scan_text):
        return [_mk(sentence.raw_text[:80])]
    for m in AND_VERB_RE.finditer(sentence.scan_text):
        if is_approved_verb(data, m.group(1)):
            return [_mk(m.group(0))]
    return []


def check_imperative(data, sentence):
    if not sentence.is_list_item:
        return []
    text = sentence.raw_text.strip()
    if re.match(r'^do\s+not\b', text, re.IGNORECASE):
        return []
    m = re.match(r'[A-Za-z]+', text)
    if m and is_approved_verb(data, m.group(0)):
        return []
    return [_mk(text[:80])]


def check_safety(data, sentence):
    text = sentence.raw_text.strip()
    m = re.match(r'^(WARNING|CAUTION):\s*(.*)$', text)
    if not m:
        return []
    rest = m.group(2).strip()
    if re.match(r'^do\s+not\b', rest, re.IGNORECASE):
        return []
    wm = re.match(r'[A-Za-z]+', rest)
    if wm:
        w = wm.group(0).lower()
        if w in ('if', 'when'):
            return []
        if is_approved_verb(data, w):
            return []
    return [_mk(text[:80])]


def check_this_pronoun(data, sentence):
    if THIS_PRONOUN_RE.match(sentence.scan_text.strip()):
        return [_mk(sentence.raw_text[:60])]
    return []


def check_possessive(data, sentence):
    out = []
    contraction_spans = {m.span() for m in CONTRACTION_RE.finditer(sentence.scan_text)}
    for m in POSSESSIVE_RE.finditer(sentence.scan_text):
        overlapped = any(m.start() >= s and m.end() <= e for (s, e) in contraction_spans)
        if overlapped:
            continue
        word = m.group(1).lower()
        if word in ('it', 'that', 'there', 'what', 'who', 'let', 'here'):
            continue
        out.append(_mk(m.group(0)))
    return out


def check_unknown(data, sentence, args):
    if not args.unknown:
        return []
    words = []
    for tok in sentence.tokens:
        if tok.exempt or tok.kind != 'word' or tok.norm is None:
            continue
        if not is_known_any(data, tok.text):
            words.append(tok.text)
    if words:
        return [_mk(', '.join(words), 'glossary or replace')]
    return []


def check_pos(data, sentence, args):
    if not args.pos:
        return []
    out = []
    tokens = sentence.tokens
    for i, tok in enumerate(tokens):
        if tok.kind != 'word' or tok.norm is None:
            continue
        if tok.norm not in POS_TARGET_WORDS:
            continue
        if i == 0 or (tokens[i - 1].norm in POS_PRECEDING):
            out.append(_mk(sentence.raw_text[:60]))
            break
    return out


def _ing_claimed_elsewhere(data, sentence, tokens, idx):
    """True if an -ing token is already reported by COMPLEX-VERB (be + ing,
    e.g. "is running") or ING-FORM (gerund at sentence start or after a
    preposition, e.g. "When running..."). Several -ing words are listed in
    unapproved.tsv under their adjective/noun sense (running, setting,
    following, ...); when the word is actually acting as a progressive
    verb or a bare gerund, that other check already names it, so UNAPPROVED
    should not also fire -- see tests/fixtures/lint/{complex-verb,
    warn-ing-form}.md.
    """
    tok = tokens[idx]
    if PROGRESSIVE_RE.search(sentence.scan_text):
        for m in PROGRESSIVE_RE.finditer(sentence.scan_text):
            if m.group(1).lower() == tok.text.lower():
                return True
    preceded = tokens[idx - 1].norm if idx > 0 else None
    if idx == 0 or preceded in ING_PRECEDED_WORDS:
        return True
    return False


def scan_dict_checks(data, sentence):
    out_banned = []
    out_unapproved = []
    tokens = sentence.tokens
    n = len(tokens)
    i = 0
    max_phrase = 3
    while i < n:
        tok = tokens[i]
        if tok.exempt or tok.kind != 'word' or tok.norm is None:
            i += 1
            continue
        if LATIN_RE.fullmatch(tok.norm):
            # LATIN already reports these (e.g. "via"); don't double-report
            # them as UNAPPROVED too (tests/fixtures/lint/latin.md).
            i += 1
            continue
        if tok.norm.endswith('ing') and _ing_claimed_elsewhere(data, sentence, tokens, i):
            i += 1
            continue
        matched_n = None
        matched_hit = None
        for span_n in range(max_phrase, 1, -1):
            if i + span_n > n:
                continue
            if not all(tokens[j].kind == 'word' and not tokens[j].exempt
                       and tokens[j].norm for j in range(i, i + span_n)):
                continue
            phrase = ' '.join(tokens[j].norm for j in range(i, i + span_n))
            hit = lookup_phrase(data, phrase)
            if hit:
                matched_n = span_n
                matched_hit = hit
                break
        if matched_n:
            text = ' '.join(tokens[j].text for j in range(i, i + matched_n))
            src, pos, extra = matched_hit
            i += matched_n
        else:
            text = tok.text
            src, pos, extra = classify_for_dict_checks(data, tok.text)
            i += 1
        if src == 'banned':
            out_banned.append(_mk(text, extra))
        elif src == 'unapproved' and extra:
            out_unapproved.append(_mk(text, ' / '.join(extra)))
    return out_banned, out_unapproved


PER_SENTENCE_CHECKS = {
    'SENTENCE-LENGTH': check_sentence_length,
    'CONTRACTION': check_contraction,
    'COMPLEX-VERB': check_complex_verb,
    'USING': check_using,
    'PASSIVE-BY': check_passive_by,
    'SEMICOLON': check_semicolon,
    'LATIN': check_latin,
    'PASSIVE': check_passive,
    'ING-FORM': check_ing_form,
    'NOUN-CLUSTER': check_noun_cluster,
    'ONE-INSTRUCTION': check_one_instruction,
    'IMPERATIVE': check_imperative,
    'THIS-PRONOUN': check_this_pronoun,
    'POSSESSIVE': check_possessive,
    'SAFETY': check_safety,
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
        for s in p.sentences:
            # BANNED / UNAPPROVED need phrase-aware scanning together.
            banned_rule = check_scope_ok('BANNED')
            unapproved_rule = check_scope_ok('UNAPPROVED')
            need_banned = banned_rule is not None
            need_unapproved = unapproved_rule is not None
            if need_banned or need_unapproved:
                banned_hits, unapproved_hits = scan_dict_checks(data, s)
                if need_banned:
                    for h in banned_hits:
                        violations.append({
                            'id': 'BANNED', 'cls': banned_rule['class'],
                            'text': h['text'],
                            'hint': h['hint'] or banned_rule['fix'],
                            'sentence_index': s.index,
                        })
                if need_unapproved:
                    for h in unapproved_hits:
                        violations.append({
                            'id': 'UNAPPROVED', 'cls': unapproved_rule['class'],
                            'text': h['text'],
                            'hint': h['hint'] or unapproved_rule['fix'],
                            'sentence_index': s.index,
                        })

            for rid, fn in PER_SENTENCE_CHECKS.items():
                rule = check_scope_ok(rid)
                if rule is None:
                    continue
                for h in fn(data, s):
                    violations.append({
                        'id': rid, 'cls': rule['class'],
                        'text': h['text'], 'hint': h['hint'] or rule['fix'],
                        'sentence_index': s.index,
                    })

            for rid, fn in (('UNKNOWN', check_unknown), ('POS', check_pos)):
                rule = check_scope_ok(rid)
                if rule is None:
                    continue
                for h in fn(data, s, args):
                    violations.append({
                        'id': rid, 'cls': rule['class'],
                        'text': h['text'], 'hint': h['hint'] or rule['fix'],
                        'sentence_index': s.index,
                    })

    # Paragraph/document-level checks.
    pl_rule = check_scope_ok('PARAGRAPH-LENGTH')
    if pl_rule is not None:
        for p in doc.paragraphs:
            n = len(p.sentences)
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
        if rc == 2:
            first = ("Reply is blocked by STE checks below. Send the corrected "
                     "reply in full, with no preamble and no explanation of "
                     "the corrections.")
        elif rc == 1:
            first = "Previous reply broke STE rules. Fix these in the next reply."
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
    parser.add_argument('--unknown', action='store_true')
    parser.add_argument('--pos', action='store_true')
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

        pre = p1_substitute(lint_text)
        pre = p2_filter(pre)
        doc = build_doc(data, pre)
        violations = run_checks(data, doc, args)
        rc = 2 if any(v['cls'] == 'block' for v in violations) else (
            1 if violations else 0)

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
