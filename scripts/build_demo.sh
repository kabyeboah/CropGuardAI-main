#!/usr/bin/env bash
set -e

# Ensure we are in the project root
cd "$(dirname "${BASH_SOURCE[0]}")/.."

# Clean previous builds
flutter clean
flutter pub get

# Build the release APK using the demo flavour (if defined). If no demo flavour, use default release.
if flutter flavors | grep -q demo; then
  flutter build apk --flavor demo --release
else
  flutter build apk --release
fi

# Optionally, build iOS (requires macOS)
# flutter build ios --release

echo "Demo build completed. APK is located in build/app/outputs/flutter-apk/"
