# Design: Remove AI Pipeline, Image/Video Verification, and Supabase Edge Functions

**Date:** 2026-04-07
**Status:** Approved for implementation

## Summary

Remove all AI pipeline code, image/video verification pipeline, and Supabase edge functions from the NagarSewa Flutter app while preserving basic photo/video capture, upload, and display functionality.

## Scope

### What Gets Removed

1. **AI Pipeline**
   - `ai_service.dart` (stubbed AI service)
   - `ai_authenticity_service.dart` (on-device AI image detection)
   - `confidence_tier.dart` (AI confidence scoring model)
   - `confidence_badge.dart` (UI widget for AI confidence)
   - AI-related environment variables

2. **Image/Video Verification Pipeline**
   - `exif_service.dart` (EXIF metadata extraction)
   - `video_metadata_service.dart` (MP4/MOV binary parsing)
   - `image_compression_service.dart` (image resizing/compression)
   - `verification_result.dart` (verification data models)
   - `verification_queue_screen.dart` (admin review UI)
   - Verification constants and scoring weights

3. **Supabase Edge Functions**
   - `verify-media/index.ts` (server-side media verification)
   - `_shared/auth.ts`, `_shared/cors.ts`, `_shared/rate_limit.ts`
   - `edge_functions_config.sql`

4. **Database Migrations**
   - `20260331_verification_layer.sql` (verification columns, queue table)
   - `20260401120000_model_metrics.sql` (ML training results table)
   - `20260401_create_ai_rate_limits.sql` (AI rate limiting)
   - `20260402_create_ai_rate_limits.sql` (duplicate migration)
   - `20260405_ai_orchestration_columns.sql` (AI orchestration columns)

### What Stays

- Photo/video capture via `image_picker`
- Direct upload to Supabase storage (no compression)
- Photo/video display in issue detail screens
- Basic issue reporting workflow
- Officer resolution workflow with photo capture

## Implementation Plan

### Phase 1: Delete standalone files (13 files)
- All AI services, verification services, models, UI widgets
- All edge function files and shared modules

### Phase 2: Delete directories
- `supabase/functions/verify-media/`
- `supabase/functions/_shared/`

### Phase 3: Delete migrations (5 files)
- All AI/verification-related SQL migrations
- Edge functions config SQL

### Phase 4: Edit mixed-concern files (10 files)
- `pubspec.yaml` — remove `image`, `exif`, `flutter_image_compress` dependencies
- `app_constants.dart` — remove `VerificationConstants`, `ImageConstants`
- `issue_model.dart` — remove verification fields
- `supabase_service.dart` — remove compression/verification calls, keep raw upload
- `report_screen.dart` — remove verification flow, keep capture/upload
- `issue_detail_screen.dart` — remove verification display
- `officer_issue_detail_screen.dart` — remove verification
- `officer_history_screen.dart` — remove verification refs
- `router.dart` — remove verification_queue route
- `.env.example` — remove AI env vars

### Phase 5: Cleanup
- Remove unused imports from edited files
- Verify no broken references remain

## Dependencies to Remove from pubspec.yaml

- `image` (used only for compression)
- `exif` (used only for EXIF extraction)
- `flutter_image_compress` (if present, used only for compression)

## Risk Assessment

- **Low risk**: Deleting standalone files — no downstream impact
- **Medium risk**: Editing mixed-concern files — must carefully remove only AI/verification code while preserving media upload/display
- **Mitigation**: Each edited file will be reviewed for broken imports and references after changes
