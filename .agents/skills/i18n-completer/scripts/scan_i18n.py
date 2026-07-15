#!/usr/bin/env python3
"""Scan .xcstrings for missing translations.

Usage:
    python3 scan_i18n.py <path_to_xcstrings> [--glossary <path>] [--source-lang en]
    python3 scan_i18n.py <path_to_xcstrings> --json
"""

import json
import sys
import argparse


def load_xcstrings(path: str) -> dict:
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def get_languages(data: dict) -> list[str]:
    languages = set()
    for key, entry in data.get("strings", {}).items():
        if entry.get("shouldTranslate") is False:
            continue
        for lang in entry.get("localizations", {}):
            languages.add(lang)
    return sorted(languages)


def find_missing(data: dict, source_lang: str = "en") -> dict:
    all_languages = get_languages(data)
    missing = {lang: [] for lang in all_languages}

    for key, entry in data.get("strings", {}).items():
        if entry.get("shouldTranslate") is False:
            continue
        localizations = entry.get("localizations", {})
        for lang in all_languages:
            if lang == source_lang:
                continue
            if lang not in localizations:
                missing[lang].append(key)
            else:
                unit = localizations[lang].get("stringUnit", {})
                if unit.get("state") != "translated":
                    missing[lang].append(key)

    return {k: v for k, v in missing.items() if v}


def load_glossary(path: str) -> dict:
    glossary = {}
    try:
        with open(path, "r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if not line.startswith("|"):
                    continue
                cells = [c.strip() for c in line.split("|") if c.strip()]
                if len(cells) >= 2 and cells[0] not in ("English", "---", "Use", "Do NOT use"):
                    glossary[cells[0]] = cells[1]
    except Exception as e:
        print(f"WARN: Could not load glossary: {e}", file=sys.stderr)
    return glossary


def print_report(missing: dict):
    total = sum(len(keys) for keys in missing.values())
    if total == 0:
        print("✅ All translations complete!")
        return False

    print(f"🔍 Found {total} missing translation(s) across {len(missing)} language(s):\n")
    for lang, keys in sorted(missing.items()):
        print(f"  [{lang}] {len(keys)} missing:")
        for key in keys:
            print(f"    - {key}")
        print()
    return True


def main():
    parser = argparse.ArgumentParser(description="Scan .xcstrings for missing translations")
    parser.add_argument("xcstrings", help="Path to .xcstrings file")
    parser.add_argument("--glossary", help="Path to glossary file (markdown table)")
    parser.add_argument("--source-lang", default="en", help="Source language (default: en)")
    parser.add_argument("--json", action="store_true", help="Output as JSON")
    args = parser.parse_args()

    data = load_xcstrings(args.xcstrings)

    if args.glossary:
        glossary = load_glossary(args.glossary)
        if glossary:
            print(f"📖 Loaded {len(glossary)} glossary terms\n")

    missing = find_missing(data, args.source_lang)

    if args.json:
        print(json.dumps(missing, indent=2, ensure_ascii=False))
    else:
        has_missing = print_report(missing)

    sys.exit(0 if not missing else 1)


if __name__ == "__main__":
    main()
