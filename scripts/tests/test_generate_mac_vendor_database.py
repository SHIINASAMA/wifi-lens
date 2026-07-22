import io
import unittest

from scripts.generate_mac_vendor_database import (
    RegistrySpec,
    build_database,
    parse_registry,
)


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
            sources=["https://example.invalid/source.csv"],
        )

        self.assertEqual(
            [
                (entry["prefixLength"], entry["prefix"])
                for entry in database["entries"]
            ],
            [(36, "001122334"), (28, "0011223"), (24, "001122")],
        )

    def test_identical_duplicate_prefix_is_deduplicated(self):
        database = build_database(
            entries=[
                {"prefix": "001122", "prefixLength": 24, "organization": "One"},
                {"prefix": "001122", "prefixLength": 24, "organization": "One"},
            ],
            retrieved_at="2026-07-22",
            sources=[],
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
            sources=[],
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
