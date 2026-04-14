# NagarSewa v1.1.0 - Release Notes

**Release Date:** April 14, 2026  
**Platform:** Android (Primary), iOS, Web  
**License:** Apache 2.0

---

## Overview

NagarSewa is a civic accountability platform for Odisha, India that enables citizens to report infrastructure issues, track resolutions in real-time, and hold government accountable through live mapping and officer verification.

---

## What's New in v1.1.0

### Core Features

| Feature | Description |
|---------|-------------|
| **Issue Reporting** | Capture photos/videos of potholes, broken streetlights, water leaks, and more with automatic GPS location |
| **Live Map** | Interactive map (MapLibre GL + OpenFreeMap) showing all reported issues with real-time updates |
| **Status Tracking** | Follow each issue from report to resolution with full status history |
| **Offline Support** | Report issues without internet; sync automatically when reconnected |
| **Multilingual** | Full UI in English, Hindi, Odia, and Bangla with dynamic translation |
| **Officer Dashboard** | Government officials can verify, assign, and resolve issues with analytics |
| **Smart Notifications** | Real-time alerts grouped by issue with server-side batching |

### User Engagement

- **Upvote/Downvote System** - Community voting on issues
- **Comments & Threading** - Discussion on reported issues
- **Draft Saving** - Save incomplete reports for later completion
- **Profile Management** - View civic score and report history

### Technical Stack

| Layer | Technology |
|-------|-----------|
| **Frontend** | Flutter 3.41 + Riverpod 3.x |
| **Routing** | go_router 17.x |
| **Backend** | Supabase (PostgreSQL, Auth, Storage, Realtime) |
| **Maps** | MapLibre GL with OpenFreeMap tiles |
| **Local Storage** | Hive + SQLite |
| **State Management** | Riverpod 3.x |

---

## Installation

### Prerequisites

- Flutter SDK 3.11+
- Android Studio / VS Code with Flutter extensions
- Supabase project (or use provided credentials)

### Quick Start

```bash
# Clone repository
git clone https://github.com/thisIsRajbirMajhi/Nagar-Sewa-2.0.git
cd Nagar-Sewa-2.0

# Install dependencies
flutter pub get

# Configure environment
cp .env.example .env

# Run the app
flutter run
```

### Pre-built APK

Download the latest debug APK from GitHub Releases:
https://github.com/thisIsRajbirMajhi/Nagar-Sewa-2.0/releases/latest

---

## Documentation

| Doc | Link |
|----|------|
| Architecture | [docs/architecture/](docs/architecture/) |
| Feature Guides | [docs/features/](docs/features/) |
| Database Schema | [docs/database/schema.md](docs/database/schema.md) |
| Getting Started | [docs/development/getting-started.md](docs/development/getting-started.md) |
| Deployment | [docs/deployment/flutter-build.md](docs/deployment/flutter-build.md) |

---

## Known Issues

- **Build Environment:** Kotlin daemon caching issues on Windows - resolved by disabling daemon in `android/gradle.properties`
- **Map Tiles:** OpenFreeMap tiles require internet connection (offline maps coming soon)

---

## Roadmap

- [ ] Release APK with ProGuard obfuscation
- [ ] iOS build configuration
- [ ] Push notification support (FCM)
- [ ] Offline map tiles
- [ ] Anonymous reporting without login

---

## Credits

- [Supabase](https://supabase.com) - Backend infrastructure
- [OpenStreetMap](https://openstreetmap.org) - Mapping data
- [MapLibre](https://maplibre.org) - Open-source mapping
- Flutter and Dart community

---

## License

Licensed under the Apache License 2.0. See [LICENSE](LICENSE) file.

```
Copyright 2026 Rajbir Majhi

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0
```