# Issue Reporting

## Overview

Multi-step issue reporting with photo/video capture, automatic location fetching, AI-powered auto-categorization, and draft support.

## Flow

```
Report Screen
    │
    ▼
1. Capture photo/video (camera only)
    │
    ▼
2. Auto-fetch GPS location
    │
    ▼
3. AI analyzes image (optional)
    │
    ├── Auto-fills: title, description, category
    └── User can edit or skip
    │
    ▼
4. Select category (manual or AI-suggested)
    │
    ▼
5. Add description (manual or AI-generated)
    │
    ▼
6. Submit or save as draft
```

## Report Screen Components

### Media Capture
- Photo: Camera capture with 1024x1024 max, 70% quality
- Video: Camera recording, 30-second max duration
- Media verification runs automatically after capture

### Location
- Auto-fetched on screen load via `LocationService`
- Displayed as read-only address + coordinates
- Loading indicator while fetching

### Category Selection
- Chip-based selection with icons
- Categories: Pothole, Garbage, Streetlight, Sewage, Manhole, Waterlogging, Encroachment, Road, Water, Electricity, Sanitation, Other
- AI can auto-select based on image analysis

### Description
- Multi-line text input
- Voice input placeholder (future)
- AI can auto-fill from image analysis

### AI Image Analysis
- "Analyze with AI" button appears after photo capture
- Sends compressed image to Edge Function
- Returns structured JSON with title, description, category, severity, department
- Results shown in bottom sheet with Apply/Cancel
- Low confidence warning displayed
- Minimum 300ms shimmer during analysis

### Submission
- Submit: Creates issue with all fields
- Draft: Saves incomplete report for later
- Verification warning shown if media confidence is low
- Low confidence triggers confirmation dialog

## Data Model

```dart
IssueModel {
  String id
  String reporterId
  String? departmentId
  String title
  String? description
  String category
  String severity
  String status
  double latitude, longitude
  String? address
  List<String> photoUrls
  String? videoUrl
  int upvoteCount, downvoteCount
  String verificationConfidence
  List<String> verificationFlags
  bool isDraft
  DateTime createdAt
}
```

## Verification Integration

After media capture, `VerificationService.verifyMedia()` runs:
1. EXIF extraction (GPS, timestamp, device)
2. Location comparison (user GPS vs EXIF GPS)
3. Timestamp analysis (capture vs submission time)
4. Server-side verification via Edge Function
5. Result determines auto-verify or admin review queue
