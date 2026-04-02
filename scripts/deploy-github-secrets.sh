#!/usr/bin/env bash

# GitHub Secrets Setup - Run this after pushing to GitHub
# This script uses GitHub CLI to set all required secrets

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Colors for Windows PowerShell compatibility
if [[ "$OSTYPE" == "win32" || "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    NC=''
fi

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  GitHub Secrets Setup for NagarSewa CI/CD                  ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check GitHub CLI
if ! command -v gh &> /dev/null; then
    echo -e "${RED}❌ GitHub CLI (gh) not found${NC}"
    echo "   Install from: https://cli.github.com"
    exit 1
fi

# Get repository
REPO=$(gh repo view --json nameWithOwner -q 2>/dev/null)
if [ -z "$REPO" ]; then
    echo -e "${RED}❌ Not in a GitHub repository or gh not authenticated${NC}"
    echo "   Run: gh auth login"
    exit 1
fi

echo -e "${GREEN}✓ Repository: $REPO${NC}"
echo ""

# Android Signing Secrets
echo -e "${YELLOW}Setting Android Signing Secrets...${NC}"

if [ -f "keystore.b64" ]; then
    KEYSTORE_B64=$(cat keystore.b64)
    gh secret set ANDROID_SIGNING_KEY_BASE64 --body "$KEYSTORE_B64" 2>/dev/null
    echo -e "${GREEN}✓ ANDROID_SIGNING_KEY_BASE64${NC}"
else
    echo -e "${RED}✗ keystore.b64 not found - skipping${NC}"
fi

gh secret set ANDROID_KEYSTORE_PASSWORD --body "NgSewa@2024Release!" 2>/dev/null
echo -e "${GREEN}✓ ANDROID_KEYSTORE_PASSWORD${NC}"

gh secret set ANDROID_KEY_ALIAS --body "nagar-sewa" 2>/dev/null
echo -e "${GREEN}✓ ANDROID_KEY_ALIAS${NC}"

gh secret set ANDROID_KEY_PASSWORD --body "NgSewa@2024Release!" 2>/dev/null
echo -e "${GREEN}✓ ANDROID_KEY_PASSWORD${NC}"

echo ""
echo -e "${YELLOW}⚠️  API Keys Required (skipping - add manually or provide values):${NC}"
echo "   Required secrets for full functionality:"
echo ""
echo "   - SUPABASE_URL"
echo "   - SUPABASE_ANON_KEY"
echo "   - GOOGLE_MAPS_API_KEY"
echo "   - GOOGLE_CLOUD_API_KEY"
echo "   - GEMINI_API_KEY"
echo ""
echo "   Add them via GitHub UI or run this script with values:"
echo ""
echo "   export SUPABASE_URL='your_value'"
echo "   export SUPABASE_ANON_KEY='your_value'"
echo "   export GOOGLE_MAPS_API_KEY='your_value'"
echo "   export GOOGLE_CLOUD_API_KEY='your_value'"
echo "   export GEMINI_API_KEY='your_value'"
echo "   bash scripts/deploy-github-secrets.sh"
echo ""

# Check for environment variables
if [ ! -z "$SUPABASE_URL" ]; then
    gh secret set SUPABASE_URL --body "$SUPABASE_URL" 2>/dev/null
    echo -e "${GREEN}✓ SUPABASE_URL${NC}"
fi

if [ ! -z "$SUPABASE_ANON_KEY" ]; then
    gh secret set SUPABASE_ANON_KEY --body "$SUPABASE_ANON_KEY" 2>/dev/null
    echo -e "${GREEN}✓ SUPABASE_ANON_KEY${NC}"
fi

if [ ! -z "$GOOGLE_MAPS_API_KEY" ]; then
    gh secret set GOOGLE_MAPS_API_KEY --body "$GOOGLE_MAPS_API_KEY" 2>/dev/null
    echo -e "${GREEN}✓ GOOGLE_MAPS_API_KEY${NC}"
fi

if [ ! -z "$GOOGLE_CLOUD_API_KEY" ]; then
    gh secret set GOOGLE_CLOUD_API_KEY --body "$GOOGLE_CLOUD_API_KEY" 2>/dev/null
    echo -e "${GREEN}✓ GOOGLE_CLOUD_API_KEY${NC}"
fi

if [ ! -z "$GEMINI_API_KEY" ]; then
    gh secret set GEMINI_API_KEY --body "$GEMINI_API_KEY" 2>/dev/null
    echo -e "${GREEN}✓ GEMINI_API_KEY${NC}"
fi

echo ""
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✓ Android signing secrets configured!${NC}"
echo ""
echo "To verify secrets:"
echo "  gh secret list"
echo ""
echo "Next steps:"
echo "  1. Add remaining API key secrets via GitHub UI or environment variables"
echo "  2. Push code to main branch to trigger first build"
echo "  3. Monitor workflow: https://github.com/$REPO/actions"
echo ""
