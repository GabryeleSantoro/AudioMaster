#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# .noindex suffix excludes build products from Spotlight (no duplicate app instances).
BUILD_DIR="${BUILD_DIR:-$ROOT/build.noindex}"

echo "Running AudioMaster test suite..."

xcodebuild test \
  -project "$ROOT/AudioMaster.xcodeproj" \
  -scheme AudioMaster \
  -destination "platform=macOS" \
  -derivedDataPath "$BUILD_DIR/TestDerivedData" \
  CODE_SIGN_IDENTITY="${CODE_SIGN_IDENTITY:--}" \
  CODE_SIGNING_REQUIRED="${CODE_SIGNING_REQUIRED:-NO}" \
  CODE_SIGNING_ALLOWED="${CODE_SIGNING_ALLOWED:-NO}"

echo "All tests passed."
