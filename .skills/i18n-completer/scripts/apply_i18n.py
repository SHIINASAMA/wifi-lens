#!/usr/bin/env python3
"""Apply translations to .xcstrings from a JSON input.

Usage:
    # Apply from JSON file
    python3 apply_i18n.py <xcstrings_path> --from <json_file>

    # Apply inline (single key)
    python3 apply_i18n.py <xcstrings_path> --set KEY --lang ja --value "翻訳"

    # Apply from stdin (pipe JSON)
    cat translations.json | python3 apply_i18n.py <xcstrings_path> --from -

JSON input format:
    {
      "key.name": {
        "de": "German value",
        "es": "Spanish value"
      },
      "another.key": {
        "ja": "Japanese value"
      }
    }

Options:
    --dry-run       Show what would be changed without writing
    --source-lang   Source language for new keys (default: en)
"""

import json
import sys
import argparse


def load_xcstrings(path: str) -> dict:
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def save_xcstrings(path: str, data: dict):
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
        f.write("\n")


def apply_translations(data: dict, translations: dict, source_lang: str = "en") -> list[str]:
    """Apply translations dict to xcstrings data. Returns list of changes."""
    changes = []
    for key, langs in translations.items():
        if key not in data.get("strings", {}):
            data["strings"][key] = {
                "extractionState": "manual",
                "localizations": {}
            }

        entry = data["strings"][key]
        if "localizations" not in entry:
            entry["localizations"] = {}

        for lang, value in langs.items():
            old = entry["localizations"].get(lang, {}).get("stringUnit", {}).get("value")
            entry["localizations"][lang] = {
                "stringUnit": {
                    "state": "translated",
                    "value": value
                }
            }
            if old and old != value:
                changes.append(f"UPDATE {key} [{lang}]: \"{old}\" -> \"{value}\"")
            elif not old:
                changes.append(f"ADD    {key} [{lang}]: \"{value}\"")

    return changes


def main():
    parser = argparse.ArgumentParser(description="Apply translations to .xcstrings")
    parser.add_argument("xcstrings", help="Path to .xcstrings file")
    parser.add_argument("--from", dest="from_file", help="JSON file with translations (- for stdin)")
    parser.add_argument("--set", dest="set_key", help="Single key to set")
    parser.add_argument("--lang", help="Language code for --set")
    parser.add_argument("--value", help="Translation value for --set")
    parser.add_argument("--dry-run", action="store_true", help="Show changes without writing")
    parser.add_argument("--source-lang", default="en", help="Source language (default: en)")
    args = parser.parse_args()

    data = load_xcstrings(args.xcstrings)

    if args.set_key:
        if not args.lang or not args.value:
            print("ERROR: --set requires --lang and --value", file=sys.stderr)
            sys.exit(1)
        translations = {args.set_key: {args.lang: args.value}}
    elif args.from_file:
        if args.from_file == "-":
            translations = json.load(sys.stdin)
        else:
            with open(args.from_file, "r", encoding="utf-8") as f:
                translations = json.load(f)
    else:
        print("ERROR: Provide --from or --set", file=sys.stderr)
        sys.exit(1)

    changes = apply_translations(data, translations, args.source_lang)

    if not changes:
        print("No changes needed.")
        return

    if args.dry_run:
        print(f"Dry run — {len(changes)} change(s):")
        for c in changes:
            print(f"  {c}")
    else:
        save_xcstrings(args.xcstrings, data)
        print(f"Applied {len(changes)} change(s):")
        for c in changes:
            print(f"  {c}")


if __name__ == "__main__":
    main()
