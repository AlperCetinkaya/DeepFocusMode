#!/bin/bash
set -euo pipefail

# Use an installed Apple Development identity so AX permission survives rebuilds.
# No certificate, private key, team identifier or account credentials are stored here.
configuration="${1:-Direct}"
action="${2:-build}"
case "$configuration" in Debug|Release|Direct) ;; *) echo "Use Debug, Release or Direct." >&2; exit 2;; esac
case "$action" in build|test) ;; *) echo "Use build or test." >&2; exit 2;; esac
project_root="$(cd "$(dirname "$0")/.." && pwd)"
identity_line="$(security find-identity -v -p codesigning | sed -n '/"Apple Development:/ {p;q;}')"
signing_hash="$(printf '%s' "$identity_line" | awk '{print $2}')"
signing_label="$(printf '%s' "$identity_line" | sed -n 's/.*"\(.*\)".*/\1/p')"
if [[ -z "$signing_hash" || -z "$signing_label" ]]; then
    echo "No valid Apple Development identity is available. Use Xcode Signing & Capabilities to set up local development signing." >&2
    exit 1
fi
team_identifier="$(security find-certificate -c "$signing_label" -p |
    openssl x509 -noout -subject -nameopt sep_multiline |
    sed -n 's/^[[:space:]]*OU[[:space:]]*=[[:space:]]*//p')"
if [[ -z "$team_identifier" ]]; then
    echo "Could not determine the development certificate's team." >&2
    exit 1
fi
scheme="DeepFocusMode"
derived_data="$project_root/build/DerivedData"
set --
if [[ "$action" == test ]]; then
    set -- ENABLE_TESTABILITY=YES SWIFT_OPTIMIZATION_LEVEL=-Onone
fi
if [[ "$configuration" == Direct ]]; then
    scheme="DeepFocusMode-Direct"
    derived_data="$project_root/build/Direct"
fi
exec xcodebuild -project "$project_root/DeepFocusMode.xcodeproj" -scheme "$scheme" \
    -configuration "$configuration" -derivedDataPath "$derived_data" -destination 'platform=macOS' \
    CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="$signing_hash" DEVELOPMENT_TEAM="$team_identifier" "$@" "$action"
