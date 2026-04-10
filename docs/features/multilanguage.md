# Multilanguage Support

## Overview

NagarSewa is designed for inclusivity across Odisha and wider India, supporting English, Hindi, Odia, and Bangla. The system handles both static UI localization and dynamic translation of user-generated content.

## Implementation Layers

### 1. Static UI Localization
- **Framework**: Built using Flutter's `gen-l10n` tool and the `intl` package.
- **Resource Files**: Located in `lib/l10n/` as `.arb` (Application Resource Bundle) files.
- **Supported Locales**:
  - `en`: English (Source)
  - `hi`: Hindi
  - `or`: Odia
  - `bn`: Bangla

### 2. User-Generated Content Translation
- **Edge Function**: A dedicated `translate-text` Supabase Edge Function integrates with the Google Cloud Translation API.
- **Caching**:
    - **Server-side**: A `translation_cache` table stores results to reduce latency and API costs.
    - **Client-side**: In-memory LRU caching in the `TranslationService` prevents redundant network calls during a session.
- **UI Interaction**: Users can toggle between translated text and the original source text with a single tap.

## State Management

- **Locale Provider**: A Riverpod notifier manages the current application locale.
- **Persistence**: The user's preferred language is persisted locally using **Hive**, ensuring it stays consistent across app restarts.
