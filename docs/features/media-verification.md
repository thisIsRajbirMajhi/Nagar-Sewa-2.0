# Media Verification

## Overview

Multi-layer media verification system that validates photo/video authenticity using EXIF data, GPS comparison, and timestamp analysis. Runs on both client and server.

## Architecture

```
┌─────────────┐     ┌──────────────┐     ┌─────────────┐
│  Capture    │────►│  EXIF/Video  │────►│  Location   │
│  Media      │     │  Extraction  │     │  Compare    │
└─────────────┘     └──────────────┘     └─────────────┘
                                               │
                     ┌──────────────┐          │
                     │  Timestamp   │◄─────────┘
                     │  Analysis    │
                     └──────────────┘
                            │
                     ┌──────┴──────┐
                     │  Verify-   │
                     │  Media RPC │
                     └──────┬──────┘
                            │
               ┌────────────┼────────────┐
               ▼            ▼            ▼
         ┌─────────┐  ┌───────────┐  ┌──────────┐
         │  High  │  │   Medium  │  │   Low    │
         │ ✓ Auto │  │ ✓ Auto    │  │ ⚠ Admin  │
         │ Verified│  │ Verified │  │ Review   │
         └─────────┘  └───────────┘  └──────────┘
```

## Client-Side Verification

### EXIF Extraction (`exif_service.dart`)
Extracts from JPEG photos:
- GPS coordinates (latitude, longitude)
- Capture timestamp
- Device model

### Video Metadata (`video_metadata_service.dart`)
Parses MP4 files:
- Creation time from mvhd atom
- GPS from udta location atom

### Location Verification (`location_verification_service.dart`)
Compares user GPS vs EXIF GPS:
- Distance > 2000m → low confidence
- Distance > 500m → medium confidence
- Distance ≤ 500m → high confidence

### Timestamp Analysis
Compares capture time vs submission time:
- Delay > 4 hours → suspicious
- Sets `isDelayedSubmission` flag

### Isolate Execution
Heavy verification runs in a compute isolate (`verification_service_isolate.dart`) to avoid blocking the UI thread.

## Server-Side Verification (`verify-media` Edge Function)

Receives:
- `issueId`, `exifGpsLat`, `exifGpsLng`, `exifTimestamp`
- `userGpsLat`, `userGpsLng`, `submissionTime`

Validates:
1. GPS distance between user and EXIF coordinates
2. Time difference between capture and submission
3. Updates `verification_confidence` and `verification_flags` on issue
4. If low confidence → adds to `verification_queue` table

## Confidence Levels

| Level | Criteria | Action |
|-------|----------|--------|
| High | GPS match ≤500m, timestamp ≤4h | Auto-verified |
| Medium | GPS match 500-2000m or timestamp 2-4h | Auto-verified, flagged |
| Low | GPS mismatch >2000m or timestamp >4h | Admin review queue |

## Verification Flags

| Flag | Meaning |
|------|---------|
| `server_gps_mismatch_high` | GPS distance > 2000m |
| `server_gps_mismatch` | GPS distance 500-2000m |
| `server_timestamp_suspicious` | Time difference > 4 hours |

## VerificationResult Model

```dart
VerificationResult {
  ConfidenceLevel confidence  // high, medium, low
  double score               // Overall score
  MediaScore? photoScore
  MediaScore? videoScore
  List<String> flags
  bool isDelayedSubmission
  Duration submissionDelay
  ExifMetadata? exifData
  String? failureReason
}
```

## Admin Review

Low-confidence issues appear in the `verification_queue`:
- Admins can approve (publish) or reject
- Queue accessible via `/admin/verification-queue`
