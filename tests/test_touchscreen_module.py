"""Smoke-test generated Magisk module layout and feature declarations."""
from pathlib import Path
import subprocess
import tempfile
import unittest
from zipfile import ZipFile
from xml.etree import ElementTree

ROOT = Path(__file__).resolve().parents[1]


class TestTouchscreenZip(unittest.TestCase):
    def test_module_files_and_features(self):
        with tempfile.TemporaryDirectory() as td:
            dest = Path(td) / 'touchscreen.zip'
            p = subprocess.run(['bash', str(ROOT/'scripts/build-touchscreen-module.sh'),
                                str(dest)], capture_output=True, text=True)
            self.assertEqual(p.returncode, 0, p.stderr)
            with ZipFile(dest) as z:
                names = set(z.namelist())
                self.assertIn('module.prop', names)
                feat = 'system/etc/permissions/sonim-touchscreen-test.xml'
                self.assertIn(feat, names)
                xml = ElementTree.fromstring(z.read(feat))
                self.assertEqual({x.attrib['name'] for x in xml.findall('feature')},
                                 {'android.hardware.touchscreen', 'android.hardware.faketouch'})
                self.assertIn('id=sonim_touchscreen_test', z.read('module.prop').decode())


if __name__ == '__main__':
    unittest.main()
