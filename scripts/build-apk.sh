#!/bin/bash

# Build local APK for testing
# Usage: ./scripts/build-apk.sh [debug|release]

set -e

BUILD_TYPE="${1:-debug}"

echo "Building APK ($BUILD_TYPE)..."

if [ "$BUILD_TYPE" = "release" ]; then
    if [ ! -f "android/signing.properties" ]; then
        echo "❌ Error: android/signing.properties not found"
        echo "Create a keystore first using: ./scripts/generate-keystore.sh"
        exit 1
    fi
fi

flutter pub get
flutter build apk --$BUILD_TYPE --verbose

APK_PATH=$(find build/app/outputs/flutter-apk -name "app-$BUILD_TYPE.apk" | head -1)
APK_SIZE=$(du -h "$APK_PATH" | cut -f1)

echo ""
echo "✓ APK built successfully!"
echo "  Path: $APK_PATH"
echo "  Size: $APK_SIZE"
echo ""
echo "To install on device:"
echo "  adb install -r $APK_PATH"
