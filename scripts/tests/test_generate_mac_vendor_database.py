import io
import unittest
import warnings
from unittest.mock import patch

from scripts.generate_mac_vendor_database import (
    RegistrySpec,
    build_database,
    normalize_iso_override,
    parse_last_modified,
    parse_registry,
    utc_now_iso,
)


def test_snapshot_date_requires_iso_calendar_shape():
    assert normalize_iso_override("2026-07-30", "--retrieved-at") == "2026-07-30T00:00:00Z"
    with unittest.TestCase().assertRaises(ValueError):
        normalize_iso_override("2026/07/30", "--retrieved-at")


class FakeResponse:
    def __init__(self, body: bytes, last_modified: str | None):
        self.body = body
        self.headers = {"Last-Modified": last_modified} if last_modified else {}

    def __enter__(self):
        return self

    def __exit__(self, *_):
        return False

    def read(self):
        return self.body


class MACVendorDatabaseGeneratorTests(unittest.TestCase):
    def test_parses_each_registry_width(self):
        cases = [
            (RegistrySpec("MA-L", 24), "001122", 24),
            (RegistrySpec("MA-M", 28), "0011223", 28),
            (RegistrySpec("MA-S", 36), "001122334", 36),
            (RegistrySpec("IAB", 36), "001122335", 36),
        ]

        for spec, assignment, expected_length in cases:
            csv_text = (
                "Registry,Assignment,Organization Name,Organization Address\n"
                f"{spec.registry},{assignment}, Example   Networks ,Somewhere\n"
            )

            entries = parse_registry(io.StringIO(csv_text), spec)

            self.assertEqual(entries[0]["prefix"], assignment)
            self.assertEqual(entries[0]["prefixLength"], expected_length)
            self.assertEqual(entries[0]["organization"], "Example Networks")

    def test_private_entries_are_omitted(self):
        csv_text = (
            "Registry,Assignment,Organization Name,Organization Address\n"
            "MA-L,AABBCC,Private,Somewhere\n"
        )

        entries = parse_registry(io.StringIO(csv_text), RegistrySpec("MA-L", 24))

        self.assertEqual(entries, [])

    def test_organization_names_decode_html_entities(self):
        csv_text = (
            "Registry,Assignment,Organization Name,Organization Address\n"
            "MA-L,AABBCC,Research &amp; Development,Somewhere\n"
        )

        entries = parse_registry(io.StringIO(csv_text), RegistrySpec("MA-L", 24))

        self.assertEqual(entries[0]["organization"], "Research & Development")

    def test_output_is_deterministic_and_most_specific_first(self):
        database = build_database(
            entries=[
                {"prefix": "001122", "prefixLength": 24, "organization": "Large"},
                {"prefix": "001122334", "prefixLength": 36, "organization": "Small"},
                {"prefix": "0011223", "prefixLength": 28, "organization": "Medium"},
            ],
            retrieved_at="2026-07-22",
            sources=[{"url": "https://example.invalid/source.csv", "lastModifiedAt": "2026-07-22T00:00:00Z"}],
        )

        self.assertEqual(
            [
                (entry["prefixLength"], entry["prefix"])
                for entry in database["entries"]
            ],
            [(36, "001122334"), (28, "0011223"), (24, "001122")],
        )
        self.assertEqual(database["retrievedAt"], "2026-07-22")
        self.assertEqual(database["sourceUpdatedAt"], "2026-07-22T00:00:00Z")

    def test_last_modified_is_converted_to_utc_iso8601(self):
        self.assertEqual(
            parse_last_modified("Thu, 30 Jul 2026 08:01:30 +0800"),
            "2026-07-30T00:01:30Z",
        )
        self.assertIsNone(parse_last_modified(None))

    def test_download_reads_last_modified_from_same_response(self):
        response = FakeResponse(
            b"Registry,Assignment,Organization Name\nMA-L,001122,Example\n",
            "Thu, 30 Jul 2026 08:01:30 GMT",
        )
        with patch("scripts.generate_mac_vendor_database.urllib.request.urlopen", return_value=response):
            stream, last_modified = __import__(
                "scripts.generate_mac_vendor_database", fromlist=["download_text"]
            ).download_text("https://example.invalid/source.csv")
        self.assertEqual(stream.read(), "Registry,Assignment,Organization Name\nMA-L,001122,Example\n")
        self.assertEqual(last_modified, "2026-07-30T08:01:30Z")

    def test_source_updated_at_uses_latest_available_source(self):
        sources = [
            {"url": "https://example.invalid/a", "lastModifiedAt": "2026-07-30T08:01:30Z"},
            {"url": "https://example.invalid/b", "lastModifiedAt": "2026-07-31T08:01:30Z"},
        ]
        database = build_database([], "2026-08-01T00:00:00Z", sources)
        self.assertEqual(database["sourceUpdatedAt"], "2026-07-31T08:01:30Z")

    def test_source_updated_override_wins(self):
        sources = [{"url": "https://example.invalid/a", "lastModifiedAt": "2026-07-31T08:01:30Z"}]
        database = build_database([], "2026-08-01T00:00:00Z", sources, "2026-07-01T00:00:00Z")
        self.assertEqual(database["sourceUpdatedAt"], "2026-07-01T00:00:00Z")

    def test_all_missing_last_modified_fails_without_override(self):
        sources = [{"url": "https://example.invalid/a", "lastModifiedAt": None}]
        with self.assertRaisesRegex(ValueError, "missing Last-Modified"):
            build_database([], "2026-08-01T00:00:00Z", sources)

    def test_partial_last_modified_warns_and_generates(self):
        sources = [
            {"url": "https://example.invalid/a", "lastModifiedAt": "2026-07-31T08:01:30Z"},
            {"url": "https://example.invalid/b", "lastModifiedAt": None},
        ]
        with warnings.catch_warnings(record=True) as caught:
            warnings.simplefilter("always")
            database = build_database([], "2026-08-01T00:00:00Z", sources)
        self.assertEqual(database["sourceUpdatedAt"], "2026-07-31T08:01:30Z")
        self.assertTrue(any("missing Last-Modified" in str(w.message) for w in caught))

    def test_retrieved_at_auto_value_is_utc_iso8601(self):
        retrieved_at = utc_now_iso()
        self.assertRegex(retrieved_at, r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$")

    def test_identical_duplicate_prefix_is_deduplicated(self):
        database = build_database(
            entries=[
                {"prefix": "001122", "prefixLength": 24, "organization": "One"},
                {"prefix": "001122", "prefixLength": 24, "organization": "One"},
            ],
            retrieved_at="2026-07-22",
            sources=[{"url": "https://example.invalid/source.csv", "lastModifiedAt": "2026-07-22T00:00:00Z"}],
        )

        self.assertEqual(len(database["entries"]), 1)

    def test_conflicting_duplicate_prefix_is_omitted_as_ambiguous(self):
        database = build_database(
            entries=[
                {"prefix": "001122", "prefixLength": 24, "organization": "One"},
                {"prefix": "001122", "prefixLength": 24, "organization": "Two"},
                {"prefix": "AABBCC", "prefixLength": 24, "organization": "Unique"},
            ],
            retrieved_at="2026-07-22",
            sources=[{"url": "https://example.invalid/source.csv", "lastModifiedAt": "2026-07-22T00:00:00Z"}],
        )

        self.assertEqual(database["ambiguousPrefixCount"], 1)
        self.assertEqual(
            database["entries"],
            [{"prefix": "AABBCC", "prefixLength": 24, "organization": "Unique"}],
        )

    def test_rejects_unexpected_registry_and_assignment_width(self):
        wrong_registry = (
            "Registry,Assignment,Organization Name,Organization Address\n"
            "MA-M,0011223,Example Networks,Somewhere\n"
        )
        wrong_width = (
            "Registry,Assignment,Organization Name,Organization Address\n"
            "MA-L,0011223,Example Networks,Somewhere\n"
        )

        with self.assertRaisesRegex(ValueError, "unexpected registry"):
            parse_registry(io.StringIO(wrong_registry), RegistrySpec("MA-L", 24))
        with self.assertRaisesRegex(ValueError, "invalid MA-L assignment"):
            parse_registry(io.StringIO(wrong_width), RegistrySpec("MA-L", 24))


if __name__ == "__main__":
    unittest.main()
