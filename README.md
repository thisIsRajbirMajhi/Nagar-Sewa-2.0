# Nagar Sewa

> *"Small reports. Big change."*

[![License: Apache 2.0](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.11+-0175C2?logo=dart)](https://dart.dev)
[![Supabase](https://img.shields.io/badge/Supabase-Backend-3ECF8E?logo=supabase)](https://supabase.com)
[![CI](https://github.com/thisIsRajbirMajhi/Nagar-Sewa-2.0/actions/workflows/ci.yml/badge.svg)](https://github.com/thisIsRajbirMajhi/Nagar-Sewa-2.0/actions/workflows/ci.yml)

A civic accountability platform for **Odisha, India**. Citizens report infrastructure issues, track resolutions in real-time, and hold government accountable through **live mapping** and **officer verification**.

---

## Features

- **Report Issues** — Capture photos/videos of potholes, broken streetlights, water leaks, and more
- **Live Map** — See all reported issues on an interactive map with real-time updates using **MapLibre GL**
- **Track Resolution** — Follow each issue from report to resolution with status tracking
- **Offline Support** — Report issues without internet; sync automatically when reconnected
- **Multilingual** — Supports English, Hindi, Odia, and Bangla with auto-translation of user content
- **Officer Dashboard** — Advanced interface for officials with quick actions, analytics, and comment threads
- **Smart Notifications** — Real-time alerts grouped by issue with server-side batching to prevent fatigue


## Tech Stack

| Layer | Technology |
|-------|-----------|
| **Frontend** | [Flutter 3.x](https://flutter.dev) with [Riverpod](https://riverpod.dev) |
| **Routing** | [go_router](https://pub.dev/packages/go_router) |
| **Backend** | [Supabase](https://supabase.com) (PostgreSQL, Auth, Storage) |
| **Logic** | Server-side validation and manual officer verification |
| **Maps** | [MapLibre GL](https://maplibre.org) with [OpenFreeMap](https://openfreemap.org) tiles (No API key required) |
| **Local Storage** | [Hive](https://pub.dev/packages/hive) + [SQLite](https://pub.dev/packages/sqflite) |
| **State Management** | [Riverpod 3.x](https://riverpod.dev) |

## Quick Start

### Prerequisites

- [Flutter SDK](https://flutter.dev/docs/get-started/install) 3.11+
- [Dart SDK](https://dart.dev/get-dart) 3.11+
- Android Studio / VS Code with Flutter extensions
- Git

### Setup

```bash
# 1. Clone the repository
git clone https://github.com/thisIsRajbirMajhi/Nagar-Sewa-2.0.git
cd Nagar-Sewa-2.0

# 2. Install dependencies
flutter pub get

# 3. Configure environment
cp .env.example .env
# Edit .env with your Supabase credentials and API keys

# 4. Run the app
flutter run
```

For detailed setup instructions, see [Getting Started](docs/development/getting-started.md).

## Documentation

| | |
|---|---|
| [Architecture](docs/architecture/system-architecture.md) | System design, data flow, and patterns |
| [Features](docs/README.md) | Authentication, reporting, offline sync |
| [Database](docs/database/schema.md) | Schema, migrations, RLS policies |
| [API Reference](docs/api/edge-functions.md) | Edge Function request/response specs |
| [Deployment](docs/deployment/flutter-build.md) | Build and release instructions |
| [Coding Standards](docs/development/coding-standards.md) | Conventions and best practices |
| [Testing](docs/development/testing.md) | Test strategy and how to run tests |

## Contributing

We welcome contributions! Please read our [Contributing Guide](CONTRIBUTING.md) to get started.

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'feat: add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

Please read our [Code of Conduct](CODE_OF_CONDUCT.md) before contributing.

## Security

If you discover a security vulnerability, please read our [Security Policy](SECURITY.md) and report it responsibly. Do **not** open a public issue.

## License

This project is licensed under the [Apache License 2.0](LICENSE).

```
Copyright 2026 Rajbir Majhi

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0
```

## Acknowledgments

- [Supabase](https://supabase.com) for the backend infrastructure
- [OpenStreetMap contributors](https://www.openstreetmap.org) for mapping data
- [MapLibre](https://maplibre.org) for open-source mapping
- The Flutter and Dart community
