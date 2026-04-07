# Issue Reporting

## Overview

Issue reporting with photo/video capture, automatic location fetching, category selection, and draft support.

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
3. Select category from predefined list
    │
    ▼
4. Add description
    │
    ▼
5. Submit or save as draft
```

## Report Screen Components

### Media Capture
- Photo: Camera capture with 1024x1024 max, 70% quality
- Video: Camera recording, 30-second max duration

### Location
- Auto-fetched on screen load via `LocationService`
- Displayed as read-only address + coordinates
- Loading indicator while fetching

### Category Selection
- Dropdown-based selection with icons
- Categories: Pothole, Garbage, Streetlight, Sewage, Manhole, Waterlogging, Encroachment, Divider, Footpath, Debris, Dumping, Signal, Road Crack, Drainage, Other

### Description
- Multi-line text input
- User enters details manually

### Submission
- Submit: Creates issue with all fields
- Draft: Saves incomplete report for later

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
  bool isDraft
  DateTime createdAt
}
```
