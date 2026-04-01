# Getting Started

## Prerequisites

- Flutter SDK 3.11+
- Dart SDK 3.11+
- Android Studio / VS Code with Flutter extensions
- Git

## Setup

### 1. Clone the Repository

```bash
git clone https://github.com/thisIsRajbirMajhi/Nagar-Sewa-2.0.git
cd NagarSewa
```

### 2. Install Dependencies

```bash
flutter pub get
```

### 3. Configure Environment

Create `.env` file in project root (development only):

```
SUPABASE_URL=https://gipfcndtddodeyveexjx.supabase.co
SUPABASE_ANON_KEY=<your-anon-key>
```

**Note:** For mobile release builds, credentials are hardcoded in `SupabaseService`. The `.env` file is only for web development.

### 4. Run the App

```bash
# Android
flutter run

# iOS
flutter run -d ios

# Web
flutter run -d chrome
```

## Project Structure

```
lib/
├── app/           # App configuration (router, theme)
├── core/          # Shared utilities, constants, widgets
├── features/      # Feature modules (auth, dashboard, report, etc.)
├── models/        # Data models
├── providers/     # Riverpod state management
└── services/      # Business logic services
```

## Key Dependencies

| Package | Purpose |
|---------|---------|
| `flutter_riverpod` | State management |
| `go_router` | Navigation |
| `supabase_flutter` | Backend integration |
| `hive_flutter` | Local storage |
| `maplibre_gl` | Map rendering |
| `flutter_image_compress` | Image compression for AI |
| `google_fonts` | Typography |
| `flutter_animate` | Animations |

## Useful Commands

```bash
# Analyze code
flutter analyze

# Format code
dart format .

# Run tests
flutter test

# Build release APK
flutter build apk --release

# Clean build artifacts
flutter clean
flutter pub get
```

## Supabase CLI

For database and Edge Function management:

```bash
# Install Supabase CLI
# See https://supabase.com/docs/guides/cli

# Apply migrations
supabase db push

# Deploy Edge Functions
supabase functions deploy

# Set secrets
supabase secrets set GROQ_API_KEY=your_key
```
