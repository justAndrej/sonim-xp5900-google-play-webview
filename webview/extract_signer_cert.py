#!/usr/bin/env python3
"""Extract the Android API-30 APK signer public X.509 certificate.

Input is stdout of a successful:
  apksigner verify --min-sdk-version 30 --max-sdk-version 30 --print-certs-pem APK

apksigner uses both `V3.0 Signer:`, `Signer #1`, and `Signer (minSdkVersion=X, maxSdkVersion=Y)`
labels depending on APK signing scheme and SDK range. Do not assume #1.

The PEM's *entire DER certificate* must match a SHA-256 digest from the
apksigner output. Otherwise fail closed; no certificate substitution.
"""
import base64
import binascii
import hashlib
import re
import sys
from pathlib import Path

# Recognize actual apksigner prefixes, including "V3.0 Signer:" on recent SDKs.
# Exclude "Source Stamp Signer:": a source stamp is NOT the app signing key.
SIGNER_DIGEST = re.compile(
    r'^(?:V[234](?:\.\d+)?\s+)?Signer(?:\s+(?:#\d+|\([^)]*\)))?:?'
    r'\s+certificate SHA-256 digest:\s*([0-9a-fA-F:]+)\s*$',
    re.IGNORECASE,
)
PEM = re.compile(
    r'-----BEGIN CERTIFICATE-----\s*(.*?)\s*-----END CERTIFICATE-----',
    re.DOTALL,
)


def extract(report: str) -> tuple[str, str]:
    hashes = set()
    for line in report.splitlines():
        m = SIGNER_DIGEST.match(line.strip())
        if m:
            digest = m.group(1).replace(':', '').lower()
            if re.fullmatch(r'[0-9a-f]{64}', digest):
                hashes.add(digest)

    if not hashes:
        candidate_lines = [
            line.strip() for line in report.splitlines()
            if 'certificate SHA-256 digest' in line
        ]
        detail = '; '.join(candidate_lines[:3]) if candidate_lines else '(none found)'
        raise ValueError(
            'apksigner did not print a recognized signer SHA-256 fingerprint. '
            'Found: ' + detail
        )

    certs = PEM.findall(report)
    if not certs:
        raise ValueError('No PEM certificate found in apksigner output; check --print-certs-pem')

    matches = {}
    for block in certs:
        encoded = ''.join(block.split())
        try:
            der = base64.b64decode(encoded, validate=True)
        except (binascii.Error, ValueError):
            raise ValueError('Malformed PEM certificate in apksigner output') from None
        digest = hashlib.sha256(der).hexdigest()
        if digest in hashes:
            matches[digest] = base64.b64encode(der).decode('ascii')

    if len(matches) != 1:
        found = [hashlib.sha256(base64.b64decode(''.join(x.split()))).hexdigest() for x in certs]
        raise ValueError(
            'Expected exactly one PEM certificate matching an apksigner SHA-256 fingerprint; '
            f'got {len(matches)} matches. Expected {sorted(hashes)}, found {found}'
        )

    digest, cert_b64 = next(iter(matches.items()))
    return digest, cert_b64


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit('Usage: extract_signer_cert.py apksigner-output.txt cert.b64')
    report_path, output_path = map(Path, sys.argv[1:])
    digest, cert_b64 = extract(report_path.read_text(encoding='utf-8'))
    output_path.write_text(cert_b64 + '\n', encoding='ascii')
    print(f'Validated Android API-30 signer SHA-256: {digest}')


if __name__ == '__main__':
    try:
        main()
    except Exception as exc:
        print('ERROR: ' + str(exc), file=sys.stderr)
        sys.exit(1)
