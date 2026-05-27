#!/usr/bin/env python3
"""Cross-check localization keys: source vs catalog."""
import json, re
from pathlib import Path
from collections import Counter

ROOT = Path(__file__).resolve().parent.parent / 'WiFiLens'

# Load catalog
with open(ROOT / 'Sources' / 'WiFiLens' / 'Resources' / 'Localizable.xcstrings') as f:
    cat = json.load(f)
catalog_keys = set(cat['strings'].keys())

# Extract from Swift source
pattern = re.compile(r'String\(localized:\s*"([^"]+)"')
source_keys = Counter()
for fpath in sorted((ROOT / 'Sources').rglob('*.swift')):
    content = fpath.read_text()
    for m in pattern.finditer(content):
        source_keys[m.group(1)] += 1

missing_from_catalog = set(source_keys.keys()) - catalog_keys
missing_from_source = catalog_keys - set(source_keys.keys())

print(f'Catalog keys: {len(catalog_keys)}')
print(f'Source keys (unique): {len(source_keys)}')
print(f'Source call sites: {sum(source_keys.values())}')
print(f'\nIn source but NOT in catalog: {len(missing_from_catalog)}')
for k in sorted(missing_from_catalog):
    print(f'  MISSING: {k!r} (used {source_keys[k]}x)')
print(f'\nIn catalog but NOT in source: {len(missing_from_source)}')
print('(these may be format strings referenced differently or stale entries)')
for k in sorted(missing_from_source)[:20]:
    entry = cat['strings'][k]
    state = entry.get('extractionState', '?')
    locs = entry.get('localizations', {})
    has_ja = 'ja' in locs
    has_zh = 'zh-Hans' in locs
    en_val = locs.get('en', {}).get('stringUnit', {}).get('value', k)
    print(f'  {k} -> en: {en_val!r}  (ja={has_ja}, zh={has_zh})')
