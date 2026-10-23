import tempfile
import unittest
from pathlib import Path

from check_coverage import above_minimum, report


class CoverageTest(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        (self.root / "lib").mkdir()
        (self.root / "lib/example.dart").write_text("void main() {}\n")
        self.lcov = self.root / "lcov.info"

    def read(self, text):
        self.lcov.write_text(text)
        return report(self.lcov, self.root)

    def test_duplicate_records_do_not_inflate_denominator(self):
        value = self.read("SF:lib/example.dart\nDA:1,0\nend_of_record\n"
                          "SF:lib/example.dart\nDA:1,2\nend_of_record\n")
        self.assertEqual((value["coveredLines"], value["executableLines"]), (1, 1))

    def test_exactly_forty_percent_does_not_pass(self):
        self.assertFalse(above_minimum({"coveredLines": 2, "executableLines": 5}, 40))
        self.assertTrue(above_minimum({"coveredLines": 3, "executableLines": 5}, 40))

    def test_unreported_files_are_visible(self):
        (self.root / "lib/unloaded.dart").write_text("const value = 1;\n")
        value = self.read("SF:lib/example.dart\nDA:1,1\nend_of_record\n")
        self.assertEqual(value["unreportedFiles"], ["lib/unloaded.dart"])

    def test_empty_truncated_negative_and_foreign_reports_fail(self):
        for text in ["", "SF:lib/example.dart\nDA:1,1\n", "DA:1,1\n",
                     "SF:lib/example.dart\nDA:1,-1\nend_of_record\n",
                     "SF:../../outside.dart\nDA:1,1\nend_of_record\n"]:
            with self.subTest(text=text), self.assertRaises(ValueError):
                self.read(text)


if __name__ == "__main__":
    unittest.main()
