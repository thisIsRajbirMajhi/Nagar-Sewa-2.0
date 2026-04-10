# Officer Dashboard

## Overview

The Officer Dashboard is a specialized interface within the NagarSewa app designed for government officials to manage, verify, and resolve reported infrastructure issues within their jurisdiction.

## Key Features

### 1. Incident Management
- **Quick Actions**: Swipe gestures (Acknowledge, Start Work, Resolve) allow for rapid workflow transitions.
- **Filtering**: Automated routing ensures officers only see issues belonging to their specific department and geographic area.
- **Priority Sorting**: Issues are ranked based on community urgency (votes) and AI-calculated confidence scores.

### 2. Resolution Workflow
- **Tab-based Detail View**: Separate views for Issue Overview, Actions (Workflow), and History (Audit Trail).
- **Proof of Work**: Officers must upload "After" photos/videos to mark an issue as Resolved, providing transparency to the citizens.
- **Comment Threads**: Direct one-to-one communication between the assigned officer and the reporting citizen to clarify details or request more information.

### 3. Analytics & Performance
- **Visual Analytics**: Metrics for resolution time, SLA compliance, and weekly/monthly performance are displayed using custom-drawn charts.
- **Trend Mapping**: Identification of hotspot areas with recurring infrastructure failures.

## Technology

- **Supabase Realtime**: Dashboard updates live as new reports are filed.
- **Custom Paint**: Lightweight visualizations for performance metrics without heavy dependencies.
- **Audit Logs**: Immutable database records for every status change and action taken by an officer.
