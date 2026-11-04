"""Regression tests for Android SDK apksigner formats seen on XP5900."""
import base64
import hashlib
import importlib.util
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location(
    'extract_signer_cert', ROOT / 'webview/extract_signer_cert.py'
)
MOD = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MOD)

# The extractor verifies SHA-256 over the full DER-encoded certificate. A
# tiny dummy DER-like byte sequence suffices to regression-test parsing and
# matching, without using or distributing Google's real signing certificate.
CERT_DER = bytes.fromhex('30820100abcdef1234567890aabbcc')
STAMP_DER = bytes.fromhex('30820100abcdef5555ff001122')
CERT_SHA = hashlib.sha256(CERT_DER).hexdigest()
STAMP_SHA = hashlib.sha256(STAMP_DER).hexdigest()


def pem(der):
    return '-----BEGIN CERTIFICATE-----\n' + base64.b64encode(der).decode() + \
        '\n-----END CERTIFICATE-----'


class TestSignerFormats(unittest.TestCase):
    def test_exact_xp5900_v3_plus_source_stamp(self):
        report = (f'Verified using v3 scheme (APK Signature Scheme v3): true\n'
                  f'V3.0 Signer: certificate SHA-256 digest: {CERT_SHA}\n'
                  f'Source Stamp Signer: certificate SHA-256 digest: {STAMP_SHA}\n'
                  f'{pem(CERT_DER)}\n{pem(STAMP_DER)}\n')
        got_sha, got_cert = MOD.extract(report)
        self.assertEqual(got_sha, CERT_SHA)
        self.assertEqual(base64.b64decode(got_cert), CERT_DER)

    def test_legacy_signer_number(self):
        report = f'Signer #1 certificate SHA-256 digest: {CERT_SHA}\n{pem(CERT_DER)}'
        self.assertEqual(MOD.extract(report)[0], CERT_SHA)

    def test_sdk_interval_signer(self):
        report = (f'Signer (minSdkVersion=28, maxSdkVersion=32) '
                  f'certificate SHA-256 digest: {CERT_SHA}\n{pem(CERT_DER)}')
        self.assertEqual(MOD.extract(report)[0], CERT_SHA)

    def test_old_v2_signer(self):
        report = f'V2 Signer: certificate SHA-256 digest: {CERT_SHA}\n{pem(CERT_DER)}'
        self.assertEqual(MOD.extract(report)[0], CERT_SHA)

    def test_stamp_only_not_accepted(self):
        report = (f'Source Stamp Signer: certificate SHA-256 digest: {STAMP_SHA}\n'
                  f'{pem(STAMP_DER)}')
        with self.assertRaisesRegex(ValueError, 'recognized signer'):
            MOD.extract(report)

    def test_certificate_hash_must_match(self):
        report = f'V3.0 Signer: certificate SHA-256 digest: {STAMP_SHA}\n{pem(CERT_DER)}'
        with self.assertRaisesRegex(ValueError, 'Expected exactly one'):
            MOD.extract(report)

    def test_does_not_accept_two_different_apk_signers(self):
        report = (f'V3.0 Signer: certificate SHA-256 digest: {CERT_SHA}\n'
                  f'V3.0 Signer: certificate SHA-256 digest: {STAMP_SHA}\n'
                  f'{pem(CERT_DER)}\n{pem(STAMP_DER)}')
        with self.assertRaisesRegex(ValueError, 'Expected exactly one'):
            MOD.extract(report)

    def test_cli_writes_exact_base64_without_source_stamp(self):
        report = (f'V3.0 Signer: certificate SHA-256 digest: {CERT_SHA}\n'
                  f'Source Stamp Signer: certificate SHA-256 digest: {STAMP_SHA}\n'
                  f'{pem(CERT_DER)}\n{pem(STAMP_DER)}')
        with tempfile.TemporaryDirectory() as td:
            src, dst = Path(td)/'report.txt', Path(td)/'cert.b64'
            src.write_text(report, encoding='utf-8')
            proc = subprocess.run([
                sys.executable, str(ROOT/'webview/extract_signer_cert.py'),
                str(src), str(dst)
            ], capture_output=True, text=True)
            self.assertEqual(proc.returncode, 0, proc.stderr)
            self.assertEqual(base64.b64decode(dst.read_text().strip()), CERT_DER)


if __name__ == '__main__':
    unittest.main()
