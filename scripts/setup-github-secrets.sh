#!/bin/bash

# Setup GitHub repository secrets for CI/CD
# This script helps you set up the required secrets

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}GitHub Actions Secrets Setup${NC}"
echo "=============================="
echo ""
echo "This script will guide you through setting up secrets for Android APK building."
echo ""

# Check if gh CLI is installed
if ! command -v gh &> /dev/null; then
    echo -e "${RED}Error: GitHub CLI (gh) is not installed${NC}"
    echo "Install it from: https://cli.github.com"
    exit 1
fi

# Check authentication
if ! gh auth status &> /dev/null; then
    echo "Authenticating with GitHub..."
    gh auth login
fi

REPO=$(gh repo view --json nameWithOwner -q)
echo "Repository: $REPO"
echo ""

echo -e "${YELLOW}Required Secrets:${NC}"
echo "1. ANDROID_SIGNING_KEY_BASE64"
echo "2. ANDROID_KEYSTORE_PASSWORD"
echo "3. ANDROID_KEY_ALIAS"
echo "4. ANDROID_KEY_PASSWORD"
echo "5. SUPABASE_URL"
echo "6. SUPABASE_ANON_KEY"
echo "7. GOOGLE_MAPS_API_KEY"
echo "8. GOOGLE_CLOUD_API_KEY"
echo "9. GEMINI_API_KEY"
echo ""

read -p "Do you want to set up secrets now? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 0
fi

echo ""
echo -e "${YELLOW}Setting up Android signing secrets...${NC}"

if [ -f "keystore.b64" ]; then
    KEYSTORE_B64=$(cat keystore.b64)
    gh secret set ANDROID_SIGNING_KEY_BASE64 --body "$KEYSTORE_B64"
    echo -e "${GREEN}✓ ANDROID_SIGNING_KEY_BASE64${NC}"
else
    echo -e "${RED}✗ keystore.b64 not found${NC}"
    echo "Generate it with: cat android/app/keystore.jks | base64 -w 0 > keystore.b64"
fi

read -sp "ANDROID_KEYSTORE_PASSWORD: " KEYSTORE_PASSWORD
echo
gh secret set ANDROID_KEYSTORE_PASSWORD --body "$KEYSTORE_PASSWORD"
echo -e "${GREEN}✓ ANDROID_KEYSTORE_PASSWORD${NC}"

read -p "ANDROID_KEY_ALIAS (default: nagar-sewa): " KEY_ALIAS
KEY_ALIAS=${KEY_ALIAS:-nagar-sewa}
gh secret set ANDROID_KEY_ALIAS --body "$KEY_ALIAS"
echo -e "${GREEN}✓ ANDROID_KEY_ALIAS${NC}"

read -sp "ANDROID_KEY_PASSWORD: " KEY_PASSWORD
echo
gh secret set ANDROID_KEY_PASSWORD --body "$KEY_PASSWORD"
echo -e "${GREEN}✓ ANDROID_KEY_PASSWORD${NC}"

echo ""
echo -e "${YELLOW}Setting up Supabase secrets...${NC}"

read -p "SUPABASE_URL: " SUPABASE_URL
gh secret set SUPABASE_URL --body "$SUPABASE_URL"
echo -e "${GREEN}✓ SUPABASE_URL${NC}"

read -sp "SUPABASE_ANON_KEY: " SUPABASE_KEY
echo
gh secret set SUPABASE_ANON_KEY --body "$SUPABASE_KEY"
echo -e "${GREEN}✓ SUPABASE_ANON_KEY${NC}"

echo ""
echo -e "${YELLOW}Setting up API Keys...${NC}"

read -sp "GOOGLE_MAPS_API_KEY: " MAPS_KEY
echo
gh secret set GOOGLE_MAPS_API_KEY --body "$MAPS_KEY"
echo -e "${GREEN}✓ GOOGLE_MAPS_API_KEY${NC}"

read -sp "GOOGLE_CLOUD_API_KEY: " CLOUD_KEY
echo
gh secret set GOOGLE_CLOUD_API_KEY --body "$CLOUD_KEY"
echo -e "${GREEN}✓ GOOGLE_CLOUD_API_KEY${NC}"

read -sp "GEMINI_API_KEY: " GEMINI_KEY
echo
gh secret set GEMINI_API_KEY --body "$GEMINI_KEY"
echo -e "${GREEN}✓ GEMINI_API_KEY${NC}"

echo ""
echo -e "${GREEN}✓ All secrets configured successfully!${NC}"
echo ""
echo "To verify secrets:"
echo "  gh secret list"
