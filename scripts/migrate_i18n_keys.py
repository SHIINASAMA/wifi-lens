#!/usr/bin/env python3
"""Migrate WiFiLens Localizable.xcstrings from text keys to semantic keys.

Reads the mapping from scripts/i18n_key_mapping.json and transforms
the xcstrings catalog in-place (or to a new file).
"""

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MAPPING_PATH = ROOT / 'scripts' / 'i18n_key_mapping.json'
XCSTRINGS_PATH = ROOT / 'WiFiLens' / 'Sources' / 'WiFiLens' / 'Resources' / 'Localizable.xcstrings'


def load_mapping() -> dict[str, dict]:
    with open(MAPPING_PATH) as f:
        raw = json.load(f)
    return {m['old_key']: m for m in raw}


def transform(mapping: dict[str, dict], dry_run: bool = False):
    with open(XCSTRINGS_PATH) as f:
        catalog = json.load(f)

    old_strings = catalog['strings']
    new_strings = {}
    skipped = []
    missing_en = 0

    for old_key, entry in old_strings.items():
        if old_key not in mapping:
            skipped.append(old_key)
            new_strings[old_key] = entry
            continue

        m = mapping[old_key]
        new_key = m['new_key']
        comment = m.get('comment', '')

        # Build new entry
        new_entry = dict(entry)
        new_entry['extractionState'] = 'manual'

        # If the old entry had no explicit 'en' localization, create one
        # with the old key text as the English value
        locs = new_entry.get('localizations', {})
        if 'en' not in locs:
            locs['en'] = {
                'stringUnit': {
                    'state': 'translated',
                    'value': old_key
                }
            }
            missing_en += 1
        else:
            # Update existing en entry state to 'translated'
            en_entry = locs['en']
            if 'stringUnit' in en_entry:
                en_entry['stringUnit']['state'] = 'translated'
            elif 'variations' in en_entry:
                pass  # leave plural variations alone
            else:
                en_entry['stringUnit'] = {
                    'state': 'translated',
                    'value': old_key
                }

        new_entry['localizations'] = locs

        # Add translator comment if provided
        if comment:
            new_entry['comment'] = comment

        new_strings[new_key] = new_entry

    new_catalog = {
        'sourceLanguage': catalog['sourceLanguage'],
        'strings': new_strings,
        'version': catalog['version'],
    }

    if dry_run:
        print(f'Would transform {len(mapping)} keys')
        print(f'Missing en localizations to create: {missing_en}')
        print(f'Skipped (not in mapping): {len(skipped)}')
        if skipped:
            for k in skipped[:5]:
                print(f'  - {k!r}')
        return

    # Write output
    output_path = XCSTRINGS_PATH if '--in-place' in sys.argv else XCSTRINGS_PATH.with_suffix('.xcstrings.new')
    with open(output_path, 'w') as f:
        json.dump(new_catalog, f, indent=2, ensure_ascii=False)
        f.write('\n')

    print(f'Transformed {len(mapping)} keys')
    print(f'Created {missing_en} explicit en localizations')
    print(f'Output: {output_path}')


if __name__ == '__main__':
    dry = '--dry-run' in sys.argv
    mapping = load_mapping()
    print(f'Loaded {len(mapping)} key mappings')
    transform(mapping, dry_run=dry)
