---
name: i18n-completer
description: >
  Scan .xcstrings localization files for missing translations and auto-fill them.
  Use when the user asks to check, complete, fix, or fill missing i18n translations,
  or when adding new localized strings and needs to ensure all languages are covered.
  Supports glossary-based terminology enforcement.
---

# i18n Completer

## Core Principle

**LLM does not read or write .xcstrings directly.** All file operations go through scripts.
The LLM's role is only to generate translation pairs.

## Workflow

### 1. Scan for gaps

```bash
python3 .skills/i18n-completer/scripts/scan_i18n.py <xcstrings_path>
```

Options: `--glossary <path>`, `--source-lang <lang>`, `--json`

### 2. Read source strings

Get the English values for missing keys without loading the full file:

```bash
python3 -c "
import json
with open('<xcstrings_path>') as f:
    data = json.load(f)
keys = <list of missing keys from scan output>
for k in keys:
    en = data['strings'][k].get('localizations',{}).get('en',{}).get('stringUnit',{}).get('value','')
    print(f'{k} = {en}')
"
```

### 3. Load glossary (if exists)

Read `docs/LOCALIZATION_TERMS.md` or similar glossary file to follow project terminology.

### 4. Generate translations

Produce a JSON object mapping keys to language-code/value pairs:

```json
{
  "key.name": {
    "de": "German translation",
    "es": "Spanish translation"
  }
}
```

Translation rules:
- Follow glossary terms strictly
- Keep parameterized placeholders (`%@`, `%lld`, `%1$@`) exactly as in source
- Follow target language punctuation (`…` not `...` for ja/zh-Hans)
- Match existing tone and style in the target language

### 5. Write via script

Pipe the JSON to the apply script:

```bash
cat <<'EOF' | python3 .skills/i18n-completer/scripts/apply_i18n.py <xcstrings_path> --from -
{
  "key.name": {
    "de": "...",
    "es": "..."
  }
}
EOF
```

Or save to a temp file first:
```bash
python3 .skills/i18n-completer/scripts/apply_i18n.py <xcstrings_path> --from /tmp/translations.json
```

Single key shortcut:
```bash
python3 .skills/i18n-completer/scripts/apply_i18n.py <xcstrings_path> --set KEY --lang ja --value "翻訳"
```

Options: `--dry-run` to preview, `--source-lang <lang>`

### 6. Verify

Re-run scan to confirm no gaps remain.

## Glossary Format

Markdown table with at least two columns. See `docs/LOCALIZATION_TERMS.md`.

| English | Target Language Term |
|---------|---------------------|
| channel | 信道 |
| scan | 扫描 |
