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
flutter test test/services/ai_service_test.dart

# Run with coverage
flutter test --coverage

# Run specific test by name
flutter test --name "should compress image"
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

## Testing AI Features

### Edge Functions
Test Edge Functions locally before deploying:

```bash
# Serve functions locally
supabase functions serve

# Test with curl
curl -X POST http://localhost:54321/functions/v1/analyze-image \
  -H "Authorization: Bearer <jwt>" \
  -H "Content-Type: application/json" \
  -d '{"imageBase64": "...", "locale": "en"}'
```

### Flutter AI Service
Mock the Supabase client for testing:
- Test image compression logic
- Test retry behavior
- Test error message mapping
- Test JSON parsing for analysis results

## Mocking

### Supabase
Use `MockSupabaseClient` or stub `SupabaseService` methods for testing without network calls.

### AI Service
Create mock implementations of `AiService` that return predefined responses for testing UI integration.

## Continuous Integration

Recommended CI pipeline:
1. `flutter pub get`
2. `flutter analyze`
3. `flutter test`
4. `flutter build apk` (Android)
5. `flutter build ios` (iOS, macOS runner only)
