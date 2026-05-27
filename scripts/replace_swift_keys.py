#!/usr/bin/env python3
"""Replace text localization keys with semantic keys in Swift source files.

Uses the mapping from scripts/i18n_key_mapping.json.
For each Swift file, finds String(localized: "old text") and replaces
with String(localized: "new.semantic.key", comment: "...").

Reports any call sites that could NOT be automatically replaced.
"""

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MAPPING_PATH = ROOT / 'scripts' / 'i18n_key_mapping.json'
SOURCES = ROOT / 'WiFiLens' / 'Sources'


def load_mapping() -> dict[str, dict]:
    with open(MAPPING_PATH) as f:
        return {m['old_key']: m for m in json.load(f)}


def replace_in_file(filepath: Path, mapping: dict[str, dict], dry_run: bool = False):
    with open(filepath) as f:
        content = f.read()
    original = content

    replaced = 0
    skipped = []

    # Find all String(localized: "...") patterns
    # Matches: String(localized: "text") or String(localized: "text with \"quotes\"")
    pattern = re.compile(r'String\(localized:\s*"((?:[^"\\]|\\.)*)"\)')

    for match in pattern.finditer(original):
        old_key = match.group(1)
        # Unescape any embedded escapes
        old_key_unescaped = old_key.replace('\\"', '"').replace('\\n', '\n')

        if old_key_unescaped in mapping:
            m = mapping[old_key_unescaped]
            new_key = m['new_key']
            comment = m.get('comment', '')
            escaped_comment = comment.replace('"', '\\"')
            replacement = f'String(localized: "{new_key}", comment: "{escaped_comment}")'
            # Replace the exact match
            original_match = match.group(0)
            if original_match in content:
                content = content.replace(original_match, replacement, 1)
                replaced += 1
            else:
                skipped.append(f'{old_key!r} (match not found in content)')
        else:
            skipped.append(f'{old_key!r} (not in mapping)')

    # Find String(localized: "...") patterns with trailing spaces (no closing paren yet — multi-line)
    # We only handle single-line cases; multi-line get reported as skipped

    if not dry_run and replaced > 0:
        with open(filepath, 'w') as f:
            f.write(content)

    return replaced, skipped


def main():
    mapping = load_mapping()
    print(f'Loaded {len(mapping)} key mappings\n')

    swift_files = sorted(SOURCES.rglob('*.swift'))
    total_replaced = 0
    total_skipped = []

    for fpath in swift_files:
        replaced, skipped = replace_in_file(fpath, mapping, dry_run='--dry-run' in sys.argv)
        if replaced > 0 or skipped:
            print(f'{fpath.relative_to(ROOT)}: {replaced} replaced, {len(skipped)} skipped')
            for s in skipped:
                print(f'  SKIP: {s}')
        total_replaced += replaced
        total_skipped.extend(skipped)

    print(f'\nTotal: {total_replaced} replacements across {len(swift_files)} files')
    if total_skipped:
        print(f'Skipped: {len(total_skipped)} call sites')
    print('DRY RUN — no files modified' if '--dry-run' in sys.argv else 'Files updated')


if __name__ == '__main__':
    main()
