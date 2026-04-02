# CI/CD Pipeline Setup Checklist

## ✓ Completed

- [x] Created `.github/workflows/build-release.yml` - Main CI/CD pipeline
- [x] Updated `android/app/build.gradle.kts` - Added signing config and ProGuard
- [x] Created `android/app/proguard-rules.pro` - Code shrinking rules
- [x] Created `scripts/generate-keystore.sh` - Keystore generation script
- [x] Created `scripts/build-apk.sh` - Local APK build script
- [x] Created `scripts/setup-github-secrets.sh` - Secrets setup script
- [x] Created `ANDROID_CI_CD_SETUP.md` - Complete setup guide

## 📋 Quick Start

### Step 1: Generate Android Signing Keystore

On Windows PowerShell, you need to use `keytool` directly:

```powershell
# First, ensure keytool is in your PATH (comes with Java)
# Navigate to your project directory, then:

keytool -genkey -v `
    -keystore android/app/keystore.jks `
    -keyalg RSA `
    -keysize 2048 `
    -validity 10950 `
    -alias nagar-sewa `
    -storepass "YourKeystorePassword" `
    -keypass "YourKeyPassword" `
    -dname "CN=NagarSewa, OU=Development, O=NagarSewa, L=India, ST=India, C=IN"
```

Or run the script on WSL/Git Bash:
```bash
bash scripts/generate-keystore.sh android/app/keystore.jks "your_password" nagar-sewa "your_key_password"
```

### Step 2: Encode Keystore for GitHub

```powershell
# Windows PowerShell
$content = [System.IO.File]::ReadAllBytes("android/app/keystore.jks")
$encoded = [System.Convert]::ToBase64String($content)
$encoded | Out-File -Encoding UTF8 -NoNewline keystore.b64
```

Or on WSL/Git Bash:
```bash
cat android/app/keystore.jks | base64 -w 0 > keystore.b64
```

### Step 3: Add GitHub Secrets

Go to: **Your Repo → Settings → Secrets and variables → Actions**

Click "New repository secret" and add:

| Secret Name | Value |
|---|---|
| `ANDROID_SIGNING_KEY_BASE64` | Content of `keystore.b64` file |
| `ANDROID_KEYSTORE_PASSWORD` | Password you set for keystore |
| `ANDROID_KEY_ALIAS` | `nagar-sewa` |
| `ANDROID_KEY_PASSWORD` | Password you set for key |
| `SUPABASE_URL` | Your Supabase URL |
| `SUPABASE_ANON_KEY` | Your Supabase anonymous key |
| `GOOGLE_MAPS_API_KEY` | Your Google Maps API key |
| `GOOGLE_CLOUD_API_KEY` | Your Google Cloud API key |
| `GEMINI_API_KEY` | Your Gemini API key |

Or use GitHub CLI:
```bash
bash scripts/setup-github-secrets.sh
```

### Step 4: Push to Main Branch

```bash
git add .github/workflows/ android/app/ scripts/ ANDROID_CI_CD_SETUP.md
git commit -m "Add Android CI/CD pipeline with APK signing and GitHub releases"
git push origin main
```

## 🚀 Pipeline Features

| Feature | Trigger | Output |
|---------|---------|--------|
| Code Analysis | All pushes & PRs | Artifacts with results |
| Unit Tests | All pushes & PRs | Coverage reports |
| Debug APK | All pushes & PRs | 7-day artifact storage |
| Release APK | Main branch only | 30-day artifact storage |
| App Bundle (AAB) | Main branch only | 30-day artifact storage |
| GitHub Release | Main branch only | Signed APK + AAB + changelog |

## 📦 Build Artifacts

After each successful build:

1. Navigate to your repo's **Actions** tab
2. Click the latest workflow run
3. Scroll to "Artifacts" section
4. Download APKs or AABs

## 🔐 Security

The `.gitignore` already includes:
- `*.jks` - Keystore files
- `*.keystore` - Keystore files
- `key.properties` - Key properties file

These files are NEVER committed to git.

## 📱 Install APK on Device

### From GitHub Releases

```powershell
adb install -r app-release.apk
```

### From Artifacts (Debug)

```powershell
adb install -r app-debug.apk
```

## 🎯 Next Steps

1. **Generate keystore** (see Step 1 above)
2. **Set GitHub secrets** (see Step 3 above)
3. **Push to main branch** (see Step 4 above)
4. **Monitor workflow** at `/actions` tab
5. **Download APK** from releases or artifacts

## 📖 Documentation

- Full setup guide: `ANDROID_CI_CD_SETUP.md`
- Workflow file: `.github/workflows/build-release.yml`
- Build config: `android/app/build.gradle.kts`
- ProGuard rules: `android/app/proguard-rules.pro`

## ⚠️ Important Notes

- Keep `android/app/keystore.jks` **PRIVATE** - never commit to git
- Store keystore passwords in **GitHub Secrets**, not in code
- GitHub releases are created only from `main` branch pushes
- AAB requires Google Play Console for distribution
- APK can be installed directly via `adb install`

## 🆘 Troubleshooting

**Q: Where do I find the APK after build?**
A: Go to Actions tab → Latest run → Artifacts section → Download APK

**Q: How do I get the signing keystore?**
A: Use the `generate-keystore.sh` script with keytool

**Q: Can I build locally?**
A: Yes, use `scripts/build-apk.sh` for local builds

**Q: What if signing fails?**
A: Verify `ANDROID_KEYSTORE_PASSWORD` matches your keystore password

