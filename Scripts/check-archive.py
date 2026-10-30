#!/usr/bin/env python3
"""Inspect a local archive or unpacked app, without uploading or asserting Store approval."""
import argparse
import json
import plistlib
import subprocess
from pathlib import Path


def inspect(archive: Path) -> dict:
    app = archive if archive.suffix == '.app' else archive / 'Products/Applications/DeepFocusMode.app'
    contents = app / 'Contents'
    info = plistlib.loads((contents / 'Info.plist').read_bytes())
    privacy = plistlib.loads((contents / 'Resources/PrivacyInfo.xcprivacy').read_bytes())
    signed = subprocess.run(['codesign', '--verify', '--deep', '--strict', str(app)],
                            capture_output=True, text=True)
    assert signed.returncode == 0, 'Code signature verification failed'
    entitlements = subprocess.check_output(['codesign', '-d', '--entitlements', ':-', str(app)],
                                          stderr=subprocess.DEVNULL)
    entitlements = plistlib.loads(entitlements)
    assert entitlements.get('com.apple.security.app-sandbox') is True, 'Sandbox must be enabled'
    assert not entitlements.get('com.apple.security.get-task-allow'), 'Debug access must be disabled'
    assert not entitlements.get('com.apple.security.network.client'), 'App needs no network entitlement'
    assert not any('temporary-exception' in key or '.private.' in key for key in entitlements), 'Unexpected exception entitlement'
    assert info['LSApplicationCategoryType'] == 'public.app-category.productivity'
    assert info['LSMinimumSystemVersion'] == '14.0'
    assert info.get('ITSAppUsesNonExemptEncryption') is False, 'Encryption declaration is missing'
    assert privacy['NSPrivacyTracking'] is False
    assert privacy['NSPrivacyCollectedDataTypes'] == []
    reasons = privacy['NSPrivacyAccessedAPITypes']
    assert any(item['NSPrivacyAccessedAPIType'] == 'NSPrivacyAccessedAPICategoryUserDefaults'
               and 'CA92.1' in item['NSPrivacyAccessedAPITypeReasons'] for item in reasons)
    for language in ['en', 'tr']:
        assert (contents / f'Resources/{language}.lproj/Localizable.strings').is_file()
    binary = contents / 'MacOS' / info['CFBundleExecutable']
    imports = subprocess.check_output(['nm', '-u', str(binary)], text=True)
    forbidden = ['_AXUIElement', '_AXIsProcessTrusted', '_CGRequestScreenCaptureAccess',
                 '_CGWindowListCreateImage', '_CGDisplayStreamCreate']
    assert not any(symbol in imports for symbol in forbidden), 'Unexpected permission/capture API'
    architecture = subprocess.check_output(['lipo', '-archs', str(binary)], text=True).strip()
    signing = subprocess.run(['codesign', '-dvv', str(app)], capture_output=True, text=True).stderr
    distribution = any(f'Authority={name}' in signing for name in ['Apple Distribution:', '3rd Party Mac Developer Application:'])
    return {
        'version': info['CFBundleShortVersionString'],
        'build': info['CFBundleVersion'],
        'architectures': architecture.split(),
        'sandbox': True,
        'privacyManifest': True,
        'nonExemptEncryption': False,
        'languages': ['en', 'tr'],
        'accessibilityOrScreenCaptureImports': False,
        'distributionSigned': distribution,
        'note': 'Structural checks passed. App Store signing/export, account metadata, screenshots and remaining device QA are separate gates.'
    }


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('archive', nargs='?', type=Path, default=Path('build/Archives/DeepFocusMode.xcarchive'))
    parser.add_argument('--require-distribution', action='store_true')
    args = parser.parse_args()
    report = inspect(args.archive)
    print(json.dumps(report, indent=2))
    if args.require_distribution and not report['distributionSigned']:
        parser.exit(1, 'App Store distribution signing is still required.\n')
