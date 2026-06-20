#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA="${HOME}/Library/Developer/Xcode/DerivedData"
APP_NAME="Keel"
APP_PATH="${DERIVED_DATA}/Keel/Build/Products/Release/${APP_NAME}.app"

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode-beta.app/Contents/Developer}"

cd "${ROOT_DIR}"

pkill -x "${APP_NAME}" 2>/dev/null || true

xcodebuild \
  -project Keel.xcodeproj \
  -scheme Keel \
  -configuration Release \
  -destination 'platform=macOS' \
  -derivedDataPath "${DERIVED_DATA}/Keel" \
  build

/usr/bin/open -n "${APP_PATH}"

if [[ "${1:-}" == "--verify" ]]; then
  sleep 2
  pgrep -x "${APP_NAME}" >/dev/null
fi
