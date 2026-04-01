# Flutter Build

## Overview

Build configurations for Android, iOS, and Web platforms.

## Version

Current version: `1.1.0+2`

Defined in `pubspec.yaml`:
```yaml
version: 1.1.0+2
```

## Android

### Configuration

- **Package:** `com.nagarsewa.nagar_sewa`
- **Min SDK:** 21
- **Build System:** Gradle (Kotlin DSL)
- **Launch Icon:** `assets/images/logo.png`

### Build Commands

```bash
# Debug APK
flutter build apk --debug

# Release APK
flutter build apk --release

# Release App Bundle (for Play Store)
flutter build appbundle --release
```

### Signing

Release signing configured in `android/app/build.gradle.kts`. Keystore file not committed to repository.

### Permissions

- `ACCESS_FINE_LOCATION` — GPS location for issue reporting
- `ACCESS_COARSE_LOCATION` — Fallback location
- `CAMERA` — Photo/video capture
- `INTERNET` — Network access
- `READ_EXTERNAL_STORAGE` — Media selection

## iOS

### Configuration

- **Bundle ID:** `com.nagarsewa.nagarSewa`
- **Deployment Target:** iOS 14+
- **Launch Icon:** `assets/images/logo.png`

### Build Commands

```bash
# Build for iOS
flutter build ios --release

# Build IPA for App Store
flutter build ipa --release
```

## Web

### Configuration

- **Deep Linking:** Custom scheme `io.supabase.nagarsewa`
- **Assets:** Favicon, manifest, icons configured in `web/`

### Build Commands

```bash
# Build for web
flutter build web --release
```

## Environment Configuration

### Mobile (Release)
Supabase credentials hardcoded in `SupabaseService`:
```dart
const supabaseUrl = 'https://gipfcndtddodeyveexjx.supabase.co';
const supabaseAnonKey = '...';
```

### Web
Credentials via `fromEnvironment()` with defaults:
```dart
const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
```

### Development (.env)
```
SUPABASE_URL=https://gipfcndtddodeyveexjx.supabase.co
SUPABASE_ANON_KEY=...
```

**Never commit `.env` to repository.**

## Launcher Icon

Generated via `flutter_launcher_icons`:
```yaml
flutter_launcher_icons:
  android: true
  ios: true
  web:
    generate: true
    image_path: "assets/images/logo.png"
  image_path: "assets/images/logo.png"
  min_sdk_android: 21
  adaptive_icon_background: "#FFFFFF"
  adaptive_icon_foreground: "assets/images/logo.png"
```

Regenerate icons:
```bash
dart run flutter_launcher_icons
```

## Performance Optimizations

1. **Icon tree-shaking** — 99.2% reduction in icon bundle size
2. **Image compression** — Client-side before upload
3. **Lazy loading** — Maps load only visible markers
4. **Compute isolates** — Heavy verification off main thread
