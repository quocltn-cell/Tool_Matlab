import sys
import unittest
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
from bump_version import next_version

class SemVerTests(unittest.TestCase):
    def test_patch(self):
        self.assertEqual(next_version('1.2.80', 'patch'), '1.2.81')

    def test_minor(self):
        self.assertEqual(next_version('1.2.80', 'minor'), '1.3.0')

    def test_major(self):
        self.assertEqual(next_version('1.2.80', 'major'), '2.0.0')

    def test_rollover(self):
        self.assertEqual(next_version('1.99.102', 'minor'), '1.100.0')
        self.assertEqual(next_version('9.9.9', 'major'), '10.0.0')

    def test_reject_invalid(self):
        for invalid in ('1.2', '01.2.3', '1.2.3.4', 'v1.2.3', '1.2.3-rc.1'):
            with self.assertRaises(ValueError):
                next_version(invalid, 'patch')

if __name__ == '__main__':
    unittest.main()
