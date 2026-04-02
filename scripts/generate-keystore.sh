#!/bin/bash

# NagarSewa Android Keystore Generation Script
# This script generates a keystore for signing Android APKs

set -e

KEYSTORE_PATH="${1:-android/app/keystore.jks}"
KEYSTORE_PASSWORD="${2:-}"
KEY_ALIAS="${3:-nagar-sewa}"
KEY_PASSWORD="${4:-}"
VALIDITY_DAYS="${5:-10950}"  # 30 years

if [ -z "$KEYSTORE_PASSWORD" ] || [ -z "$KEY_PASSWORD" ]; then
    echo "Usage: $0 <keystore_path> <keystore_password> <key_alias> <key_password> [validity_days]"
    echo ""
    echo "Example:"
    echo "  $0 android/app/keystore.jks mykeystorepass nagar-sewa mykeyppass"
    echo ""
    echo "Store these passwords securely in GitHub Secrets:"
    echo "  - ANDROID_KEYSTORE_PASSWORD"
    echo "  - ANDROID_KEY_ALIAS"
    echo "  - ANDROID_KEY_PASSWORD"
    exit 1
fi

echo "Generating Android keystore..."
echo "Keystore path: $KEYSTORE_PATH"
echo "Key alias: $KEY_ALIAS"
echo "Validity: $VALIDITY_DAYS days"
echo ""

keytool -genkey -v \
    -keystore "$KEYSTORE_PATH" \
    -keyalg RSA \
    -keysize 2048 \
    -validity $VALIDITY_DAYS \
    -alias "$KEY_ALIAS" \
    -storepass "$KEYSTORE_PASSWORD" \
    -keypass "$KEY_PASSWORD" \
    -dname "CN=NagarSewa, OU=Development, O=NagarSewa, L=India, ST=India, C=IN"

echo ""
echo "✓ Keystore generated successfully!"
echo ""
echo "Next steps:"
echo "1. Encode the keystore in base64:"
echo "   cat $KEYSTORE_PATH | base64 -w 0 > keystore.b64"
echo ""
echo "2. Add to GitHub Secrets:"
echo "   - ANDROID_SIGNING_KEY_BASE64: (content of keystore.b64)"
echo "   - ANDROID_KEYSTORE_PASSWORD: $KEYSTORE_PASSWORD"
echo "   - ANDROID_KEY_ALIAS: $KEY_ALIAS"
echo "   - ANDROID_KEY_PASSWORD: $KEY_PASSWORD"
echo ""
echo "3. Add .gitignore entries:"
echo "   android/app/keystore.jks"
echo "   android/signing.properties"
echo "   keystore.b64"
