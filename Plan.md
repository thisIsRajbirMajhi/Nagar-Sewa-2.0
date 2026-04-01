# NagarSewa — Product & Technical Blueprint

> **Tagline:** *"Small reports. Big change."*
>
> A civic accountability platform that transforms how Indian citizens report infrastructure issues, how departments resolve them, and how the public holds government accountable — powered by AI, built on trust.

---

## Table of Contents

1. [The Problem](#1-the-problem)
2. [Product Vision](#2-product-vision)
3. [The Resolution Loop](#3-the-resolution-loop)
4. [User Personas](#4-user-personas)
5. [Screen Flows & UI Design](#5-screen-flows--ui-design)
6. [Feature Modules](#6-feature-modules)
7. [AI & ML Architecture](#7-ai--ml-architecture)
8. [Tech Stack](#8-tech-stack)
9. [Phased Implementation Roadmap](#9-phased-implementation-roadmap)

---

## 1. The Problem

India's civic infrastructure suffers not from a lack of reporting, but a **lack of closed-loop accountability**. Citizens report issues informally (WhatsApp groups, social media), but nothing moves because there's:

- No structured handoff to the right authority
- No tracking or deadlines
- No consequence for inaction

**NagarSewa is a trust machine** — one that makes government accountability visible, measurable, and undeniable.

---

## 2. Product Vision

> *"A citizen reports a pothole in 30 seconds. AI verifies it, routes it to PWD automatically, the department gets a deadline, the citizen watches it get fixed in real-time, and rates the outcome. Every unresolved issue becomes public data."*

### Core Principles
- **Effortless reporting** — 30 seconds, photo-first, zero manual categorization.
- **AI-verified trust** — No fake reports, no duplicates, no gaming.
- **Automatic routing** — The right department gets it without human intervention.
- **Public accountability** — Unresolved issues are visible to everyone.
- **Citizen closure** — The loop isn't closed until the citizen confirms.

---

## 3. The Resolution Loop

Every feature must serve this loop. If it doesn't, it's a distraction.

```
REPORT → VERIFY → ASSIGN → ACKNOWLEDGE → RESOLVE → CONFIRM → RATE → PUBLISH
```

### Issue Lifecycle States
```
Submitted → AI Verified → Assigned → Acknowledged → In Progress → Resolved → Citizen Confirmed → Closed
```
Every state change is timestamped and publicly visible.

---

## 4. User Personas

| Persona | Role | Key Actions |
|---------|------|-------------|
| **Citizen** | Reports issues, tracks progress | Capture photo → review AI description → submit → track status → confirm/reject resolution → rate quality |
| **Department Official** | Receives and resolves issues | View assigned queue → acknowledge → dispatch field workers → upload resolution proof → close |
| **Government Admin / Supervisor** | Monitors city-wide performance | View dashboards → monitor SLA compliance → escalate stalled issues → access analytics & reports |

---

## 5. Screen Flows & UI Design

Design mockups are in the `resources/` directory. The app uses a **dark navy (#1B2A4A) + green (#4CAF50)** primary palette on a clean white background.

### 5.1 Onboarding Flow

| Screen | File | Description |
|--------|------|-------------|
| Splash | `Splash Screen.png` | Brand logo with tagline, online status indicator, loading spinner |
| Login | `Login Screen.png` | Email + password login, "Forgot password?" link |
| Register | `Registration Screen.png` | Full name, email, password, confirm password. Links to login |
| OTP Verification | `Mobile Verification.png` | Phone number input with "Send OTP", 6-digit OTP entry, verify button |

**Flow:** Splash → Login ↔ Register → Mobile Verification → Dashboard

### 5.2 Main App (Post-Login)

| Screen | File | Description |
|--------|------|-------------|
| Citizen Dashboard | `Citizen Dashboard.png` | Overview cards (Resolved, Urgent, Reported, Community), recent activity feed, FABs for new report + AI chatbot |
| Report Issue | `Report Screen.png` | Photo/video capture, auto-fetched GPS location (read-only), description (with voice input), embedded live map, submit/draft actions |
| Live Map | `Live Map.png` | Full-screen interactive map with issue pins, location markers |

### 5.3 Bottom Navigation (4 tabs from design)
1. **Dashboard** (grid icon) — Overview & recent activity
2. **History** (clock icon) — Past issues timeline
3. **Map** (pin/chart icon) — Live issue map
4. **Chat/Support** (chat icon) — AI assistant & help

### 5.4 Screens Still Needed (Not Yet Designed)

- [ ] Issue Detail / Tracking Timeline
- [ ] Department Dashboard (for officials)
- [ ] Admin Analytics Dashboard
- [ ] Profile / Settings
- [ ] Notifications Center
- [ ] Community Upvoting View
- [ ] Resolution Confirmation Screen

---

## 6. Feature Modules

### Module 1 — AI-Powered Reporting Engine
*The entry point and first trust signal. Must feel effortless.*

| Feature | Description | AI Component |
|---------|-------------|-------------|
| Photo Capture + GPS | Location auto-filled, timestamp locked, metadata tamper-proof | None (native APIs) |
| AI Issue Classifier | Identifies issue type (pothole, garbage, broken streetlight, etc.) from photo. Citizens don't categorize manually | On-device TFLite model |
| AI Authenticity Verifier | Detects duplicates, AI-generated/edited images, confirms genuine civic problem | ELA + EXIF analysis |
| Severity Scoring | Assigns Low / Medium / High / Critical based on visual analysis + location context (school zone, hospital = elevated) | Custom regression model |
| Voice-to-Text | Citizen can describe in native language (Hindi, Odia, etc.). AI translates and standardizes | Sarvam AI |
| Auto-Department Routing | Based on issue type + geo-zone, auto-assigns correct department (PWD, Municipal Corp, Water Board, etc.) | Rule-based engine |

---

### Module 2 — Verification & Trust Layer
*What separates NagarSewa from a complaint box.*

| Feature | Description |
|---------|-------------|
| Community Upvoting | Citizens in the same area upvote issues → increases severity & urgency. Crowd-verified issues are harder to ignore |
| AI Duplicate Detection | Reports of the same issue are merged into one consolidated issue with multiple affected citizens |
| Fraud Prevention | GPS spoofing detection, image forensics (ELA), rate-limiting (>5 reports in 10 min = flag) |
| Issue Lifecycle | Every state change (Submitted → Closed) is timestamped and visible to all stakeholders |

---

### Module 3 — Department & Government Interface
*Where accountability lives. Clean, functional dashboard — not a bloated portal.*

| Feature | Description |
|---------|-------------|
| Department Dashboard | Assigned issues, priority queue, deadline tracking, field worker assignment, status updates |
| Deadline Engine (SLA) | Each issue type has a Service Level Agreement. e.g., Pothole = 7 days, Garbage overflow = 24 hours |
| Auto-Escalation | Unacknowledged in 24h → notify supervisor. Past SLA → escalate to district. Repeated breaches → public report |
| Resolution Proof | Officials upload before/after photos from same GPS location. AI cross-verifies location & visual improvement |
| Field Worker App | Lightweight companion for ground workers: receive tasks, update progress, upload proof on the field |

---

### Module 4 — Citizen Tracking & Notifications
*What makes citizens trust the system enough to keep using it.*

| Feature | Description |
|---------|-------------|
| Real-Time Timeline | WhatsApp-like timeline showing every status change with timestamps |
| Push Notifications | Notified at every stage: assigned, work started, marked resolved |
| Citizen Confirmation | Loop isn't closed until citizen confirms. Rejection with reason/photo auto-reopens & escalates |
| Estimated Resolution | AI predicts resolution time based on issue type, department workload, and historical data |

---

### Module 5 — Analytics & Public Accountability Dashboard
*The most powerful long-term feature. Turns data into political and social pressure.*

| Feature | Description |
|---------|-------------|
| City Heat Map | Live map of all open issues by zone. Clusters of unresolved issues are visually obvious. Publicly accessible |
| Department Scorecards | Resolution rate, avg resolution time, SLA compliance, escalation frequency — all public |
| Spending Accountability | Cross-reference issues with government budget allocation by zone (e.g., ₹50L for roads vs. 200 open potholes) |
| Trend Reports | AI-generated weekly/monthly reports: common issues, fastest/slowest departments, recurring problem zones |
| Citizen Satisfaction Index | Aggregated resolution quality ratings per department and ward. Annual public score |

---

### Module 6 — Trust, Engagement & Gamification
*Keeping citizens engaged requires intrinsic motivation beyond frustration.*

| Feature | Description |
|---------|-------------|
| Civic Score | Points for reporting verified issues, confirming resolutions, upvoting. Top scorers = "Civic Champions" |
| Ward Leaderboard | Which neighbourhoods are most active? Which have the cleanest resolution rates? |
| Anonymous Reporting | For sensitive issues or fear of retaliation. Still receive updates via tracking ID |
| Multilingual Support | Full UI in Hindi, Odia, Telugu, Tamil, Bengali, etc. Voice input in regional languages |

---

## 7. AI & ML Architecture

### 7.1 AI Layers Overview

```
┌─────────────────────────────────────────────────────────┐
│                   LAYER 1: CLOUD AI                     │
│              (Language & Description Only)               │
├─────────────────────────────────────────────────────────┤
│  Google Gemini Vision    →  Generate English description │
│  Sarvam AI               →  Translate to regional lang  │
│                              + TTS notifications         │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│              LAYER 2: LOCAL / SELF-HOSTED               │
│         (No API cost, full data ownership,               │
│          works in low-connectivity zones)                 │
├─────────────────────────────────────────────────────────┤
│  Model 1: Issue Classifier       (On-device TFLite)     │
│  Model 2: Severity Scorer        (Backend server)       │
│  Model 3: Duplicate Detector     (CLIP + Vector DB)     │
│  Model 4: Resolution Verifier    (Siamese Network)      │
│  Model 5: Fraud Detector         (Rule-based + ELA)     │
└─────────────────────────────────────────────────────────┘
```

### 7.2 Model Details

#### Model 1 — Issue Classifier ⭐ (Most Critical)

| Attribute | Detail |
|-----------|--------|
| **Input** | Image |
| **Output** | `{ category: "pothole", confidence: 0.94 }` |
| **Categories** | pothole, garbage_overflow, broken_streetlight, sewage_leak, encroachment, damaged_road_divider, broken_footpath, open_manhole, waterlogging, construction_debris (~15–20 total) |
| **Base Model** | MobileNetV3 or EfficientNet-Lite |
| **Training Data** | Scraped Twitter/X civic complaints, Swachh Bharat app, Google Street View India, manual collection. Target: 500–1000 images per class |
| **Deployment** | TFLite (on-device via Flutter), ONNX (backend server) |

#### Model 2 — Severity Scorer

| Attribute | Detail |
|-----------|--------|
| **Input** | Image + category + GPS context (school zone? highway?) |
| **Output** | `{ severity: "HIGH", score: 0.82, reason: "Large pothole on main road" }` |
| **Approach** | Fine-tune classifier with additional regression head. Severity labels (1–5) based on: issue size in frame, proximity to high-risk zones, visible safety hazard |
| **GPS Context** | Rule-based booster on top of model score (not ML) — simpler and more controllable |

#### Model 3 — Duplicate / Same-Issue Detector

| Attribute | Detail |
|-----------|--------|
| **Input** | New report (image embedding + GPS coordinates) vs. vector DB of open issues in same geo-radius |
| **Output** | `{ is_duplicate: true, matched_issue_id: "ISSUE_2847" }` |
| **Approach** | CLIP-style image embedding (512-dim vectors), stored in Qdrant or Weaviate (self-hosted). Duplicate = cosine similarity > 0.85 AND GPS distance < 50m |

#### Model 4 — Resolution Verifier

| Attribute | Detail |
|-----------|--------|
| **Input** | Before image (report) + After image (official's proof) |
| **Output** | `{ resolved: true, confidence: 0.91 }` or `{ resolved: false, reason: "Pothole still visible" }` |
| **Approach** | Siamese Network / contrastive learning on before/after civic repair pairs. GPS must match within 20m (hard constraint). If confidence < 0.75 → flag for human review |

#### Model 5 — Fraud / Fake Report Detector

| Attribute | Detail |
|-----------|--------|
| **Input** | Image metadata + GPS trace + account behaviour |
| **Output** | `{ fraud_probability: 0.12, flags: ["no_exif_data", "stock_photo_match"] }` |
| **Approach** | ELA for AI-generated/edited images (rule-based). GPS vs IP geolocation cross-check. Behavioural: >5 reports in 10 min from same account = flag |

### 7.3 Unified AI Pipeline

```
[Citizen captures photo]
        ↓
[On-device: Issue Classifier (TFLite)]        ← runs offline
        ↓
[On-device: Fraud pre-check (ELA + EXIF)]
        ↓
[Upload to backend server]
        ↓
[Server: Duplicate Detector (CLIP + Vector DB)]
        ↓
[Server: Severity Scorer]
        ↓
[Gemini Vision: Generate English description]  ← cloud call
        ↓
[Sarvam: Translate to citizen's language]      ← cloud call
        ↓
[Citizen reviews AI description → confirms & submits]
        ↓
[Auto-routing to department]
        ↓
              ... issue lifecycle ...
        ↓
[Official uploads resolution proof]
        ↓
[Server: Resolution Verifier (Siamese Network)]
        ↓
[Sarvam TTS: Notify citizen in local language]
```

---

## 8. Tech Stack

| Layer | Technology | Rationale |
|-------|-----------|-----------|
| **Mobile App** | Flutter (Dart) | Cross-platform (iOS + Android), native performance, strong India dev community |
| **Backend** | Supabase (Postgres + Auth + Storage + Realtime) | Managed infra, real-time subscriptions, built-in auth, row-level security |
| **Cloud AI** | Google Gemini Vision, Gemini Flash | Photo → description generation (only cloud AI call) |
| **Language AI** | Sarvam AI | Purpose-built for Indian languages. Translation, TTS, STT |
| **On-Device ML** | TFLite (via Flutter) | Offline issue classification, fraud pre-check |
| **Vector DB** | Qdrant or Weaviate (self-hosted) | Duplicate detection via image embeddings |
| **Backend ML** | ONNX Runtime / Python (FastAPI) | Severity scoring, resolution verification |
| **Maps** | Google Maps / OpenStreetMap | Live issue heat map, GPS tagging |
| **Notifications** | Firebase Cloud Messaging (FCM) | Push notifications at every lifecycle stage |
| **Analytics** | Custom + Supabase views | Public dashboards, department scorecards |

---

## 9. Phased Implementation Roadmap

### Phase 1 — Foundation (Completed)
*Get the app skeleton running with auth and basic reporting.*

- [x] **Flutter project setup** — folder structure, routing, state management (Riverpod/BLoC)
- [x] **Supabase project** — database schema, auth config, storage buckets, RLS policies
- [x] **Onboarding flow** — Splash → Login → Register
- [x] **Citizen Dashboard** — Overview cards, recent activity feed
- [x] **Report Issue screen** — Photo capture, GPS auto-fetch, description input, map preview
- [x] **Basic issue CRUD** — Submit, view, list issues
- [x] **Database schema** — Users, Issues, Departments, Issue_History, Upvotes

### Phase 2 — Core Features & Maps (Completed ✅)
*Implement mapping, location filtering, and community engagement.*

- [x] **Live Map screen** — Interactive map with issue pins, location markers using Google Maps
- [x] **Community Upvoting/Downvoting** — Upvote system for issues with realtime updates
- [x] **Media Carousels** — Professional layout for issue detail views with image galleries
- [x] **Location Filtering** — Strict 5km radius filter for nearby issues
- [x] **Performance Optimization** — Caching, parallel media uploads, atomic RPC functions
- [x] **Modern Profile & Theme System** — Light/Dark mode support, profile editing with avatar upload, and auto-ward detection.
- [x] **Deep Link Implementation (Auth Callback)** — Added `io.supabase.nagarsewa` support for seamless email verification redirections on Android/iOS.


### Phase 3 — AI Core (To Be Done)
*Add the intelligence layer that makes reporting effortless.*

- [ ] **Issue Classifier model** — Train MobileNetV3/EfficientNet on civic issue dataset, export to TFLite
- [ ] **On-device classification** — Integrate TFLite in Flutter, auto-categorize from photo
- [ ] **Gemini Vision integration** — Generate English description from photo
- [ ] **Sarvam AI integration** — Translate description to regional language, voice input
- [ ] **Severity Scorer** — Train regression model, deploy on backend
- [ ] **Auto-routing engine** — Rule-based department assignment from category + geo-zone

### Phase 4 — Trust & Verification (To Be Done)
*Prevent abuse, detect duplicates, build the trust layer.*

- [ ] **Duplicate Detector** — CLIP embeddings + Vector DB setup, cosine similarity matching
- [ ] **Fraud Detection** — ELA image analysis, EXIF validation, GPS cross-check, rate limiting
- [ ] **Issue Lifecycle engine** — Full state machine with timestamped transitions

### Phase 5 — Department Side (To Be Done)
*Build the accountability interface for government officials.*

- [ ] **Department Dashboard** — Assigned issues queue, priority sorting, deadline tracking
- [ ] **SLA / Deadline Engine** — Auto-deadlines by issue type, escalation triggers
- [ ] **Resolution Proof** — Before/after photo upload with GPS verification
- [ ] **Resolution Verifier** — Siamese network for visual verification of fixes
- [ ] **Auto-Escalation** — Notification chain: official → supervisor → district → public report
- [ ] **Field Worker companion** — Lightweight task view + proof upload

### Phase 6 — Citizen Experience (To Be Done)
*Close the trust loop with tracking, notifications, and confirmation.*

- [ ] **Issue Detail Timeline** — WhatsApp-style status history per issue
- [ ] **Push Notifications** — FCM integration, notify at every lifecycle stage
- [ ] **Citizen Confirmation** — Accept/reject resolution with reason & photo
- [ ] **Estimated Resolution Time** — AI prediction based on historical data
- [ ] **History tab** — Full past issues with filters and search

### Phase 7 — Public Accountability & Engagement (To Be Done)
*Make government performance public and drive long-term adoption.*

- [ ] **City Heat Map** — Public-facing live map of open issues by zone
- [ ] **Department Scorecards** — Resolution rate, SLA compliance, escalation stats
- [ ] **Trend Reports** — AI-generated weekly/monthly summaries
- [ ] **Budget Cross-Reference** — Issue density vs. allocated budget by ward
- [ ] **Citizen Satisfaction Index** — Aggregated ratings per department
- [ ] **Civic Score & Gamification** — Points system, Civic Champions recognition
- [ ] **Ward Leaderboard** — Community competition on activity and resolution rates
- [ ] **Anonymous Reporting** — Tracking ID system for sensitive reports
- [ ] **Full Multilingual UI** — Hindi, Odia, Telugu, Tamil, Bengali (minimum)
- [ ] **Admin Analytics Dashboard** — City-wide insights for government supervisors

---

## Design Assets

All current design mockups are located in `resources/`:

| File | Screen |
|------|--------|
| `logo.png` | App logo — "Small reports. Big change." |
| `Splash Screen.png` | Onboarding splash with loader |
| `Login Screen.png` | Email + password login |
| `Registration Screen.png` | New user registration |
| `Mobile Verification.png` | Phone OTP verification |
| `Citizen Dashboard.png` | Main dashboard with overview cards |
| `Report Screen.png` | Issue reporting with photo, GPS, map |
| `Live Map.png` | Full-screen issue map |

---

*Last updated: March 31, 2026*