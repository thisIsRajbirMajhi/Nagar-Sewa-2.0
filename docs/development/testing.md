# Testing

## Test Strategy

NagarSewa follows a pragmatic testing approach focused on critical paths and business logic.

## Test Categories

### Unit Tests
- Service layer logic
- Data model serialization
- Utility functions
- Provider state mutations

### Widget Tests
- Form validation
- UI component rendering
- Navigation flows

### Integration Tests
- End-to-end user flows
- Supabase API interactions
- Offline sync behavior

## Running Tests

```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/services/supabase_service_test.dart

# Run with coverage
flutter test --coverage

# Run specific test by name
flutter test --name "should fetch issues"
```

## Test File Location

```
test/
├── models/
├── services/
├── providers/
├── features/
└── widgets/
```

Mirror the `lib/` structure.

## Mocking

### Supabase
Use `MockSupabaseClient` or stub `SupabaseService` methods for testing without network calls.

## Continuous Integration

Recommended CI pipeline:
1. `flutter pub get`
2. `flutter analyze`
3. `flutter test`
4. `flutter build apk` (Android)
5. `flutter build ios` (iOS, macOS runner only)
