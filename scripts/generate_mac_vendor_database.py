#!/usr/bin/env python3
"""Generate WiFi Lens's compact MAC-prefix-to-organization mapping."""

from __future__ import annotations

import argparse
import csv
import html
import io
import json
import re
import urllib.request
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable, TextIO


@dataclass(frozen=True)
class RegistrySpec:
    registry: str
    prefix_length: int


REGISTRIES = {
    "https://standards-oui.ieee.org/oui/oui.csv": RegistrySpec("MA-L", 24),
    "https://standards-oui.ieee.org/oui28/mam.csv": RegistrySpec("MA-M", 28),
    "https://standards-oui.ieee.org/oui36/oui36.csv": RegistrySpec("MA-S", 36),
    "https://standards-oui.ieee.org/iab/iab.csv": RegistrySpec("IAB", 36),
}


def normalize_organization(value: str) -> str:
    return " ".join(html.unescape(value).split())


def parse_registry(stream: TextIO, spec: RegistrySpec) -> list[dict[str, object]]:
    reader = csv.DictReader(stream)
    required_columns = {"Registry", "Assignment", "Organization Name"}
    if not required_columns.issubset(reader.fieldnames or []):
        raise ValueError(f"missing required columns for {spec.registry}")

    expected_hex_count = spec.prefix_length // 4
    entries: list[dict[str, object]] = []
    for row in reader:
        if row.get("Registry", "").strip() != spec.registry:
            raise ValueError(f"unexpected registry: {row.get('Registry')!r}")

        prefix = re.sub(r"[^0-9A-Fa-f]", "", row.get("Assignment", "")).upper()
        if len(prefix) != expected_hex_count or not re.fullmatch(r"[0-9A-F]+", prefix):
            raise ValueError(f"invalid {spec.registry} assignment: {prefix!r}")

        organization = normalize_organization(row.get("Organization Name", ""))
        if not organization or organization.casefold() == "private":
            continue

        entries.append(
            {
                "prefix": prefix,
                "prefixLength": spec.prefix_length,
                "organization": organization,
            }
        )
    return entries


def build_database(
    entries: Iterable[dict[str, object]],
    retrieved_at: str,
    sources: list[str],
) -> dict[str, object]:
    unique: dict[tuple[int, str], dict[str, object]] = {}
    ambiguous: set[tuple[int, str]] = set()
    for entry in entries:
        key = (int(entry["prefixLength"]), str(entry["prefix"]))
        if key in ambiguous:
            continue
        existing = unique.get(key)
        if existing is not None and existing["organization"] != entry["organization"]:
            unique.pop(key)
            ambiguous.add(key)
            continue
        unique[key] = entry

    ordered = sorted(
        unique.values(),
        key=lambda entry: (-int(entry["prefixLength"]), str(entry["prefix"])),
    )
    return {
        "schemaVersion": 1,
        "retrievedAt": retrieved_at,
        "sources": sorted(sources),
        "ambiguousPrefixCount": len(ambiguous),
        "notice": (
            "Derived from IEEE Registration Authority public listings. "
            "Organizations are address-block registrants and may differ from device brands."
        ),
        "entries": ordered,
    }


def download_text(url: str) -> TextIO:
    request = urllib.request.Request(
        url,
        headers={
            "User-Agent": (
                "WiFiLens-MACVendorDatabaseGenerator/1.0 "
                "(+https://github.com/SHIINASAMA/wifi-lens)"
            )
        },
    )
    with urllib.request.urlopen(request, timeout=180) as response:
        return io.StringIO(response.read().decode("utf-8-sig"))


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--retrieved-at", required=True, help="Snapshot date in YYYY-MM-DD")
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    all_entries: list[dict[str, object]] = []
    for url, spec in REGISTRIES.items():
        with download_text(url) as stream:
            all_entries.extend(parse_registry(stream, spec))

    database = build_database(all_entries, args.retrieved_at, list(REGISTRIES))
    args.output.write_text(
        json.dumps(
            database,
            ensure_ascii=False,
            sort_keys=True,
            separators=(",", ":"),
        )
        + "\n",
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()
