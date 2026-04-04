# Officer Dashboard – Functional Specification

## 1. Issue Filtering & Assignment
- Officers should **only see issues relevant to their jurisdiction and department**.
- Mapping logic:
  - `departments.json` → maps issue categories to departments
  - `places.json` → maps geographic regions to officers
- Filtering criteria:
  - Department match
  - Geographic jurisdiction match

---

## 2. Issue Prioritization (Urgency-Based Sorting)
- Issues must be displayed based on **priority ranking**.

### Priority Factors
- Primary:
  - **Number of citizen votes**
- Secondary (optional):
  - Severity level
  - Time since reported
  - AI confidence score

### Sorting Logic

Higher votes → Higher priority


---

## 3. Issue Authenticity & AI Confidence Layer

### 3.1 Confidence Score
- Each issue includes an **AI-generated confidence score** indicating likelihood of being genuine.

Example:
Confidence Score: 0.92 (High)

---

### 3.2 Explainability (Critical Requirement)
Officers must be able to inspect **why the AI assigned the score**.

#### Confidence Breakdown Includes:
- Image/video analysis:
  - Object detection (e.g., pothole, garbage overflow)
- Metadata validation:
  - GPS consistency
  - Timestamp validity
- Duplicate detection:
  - Similar reports in nearby area
- User credibility:
  - Reporter history (optional)
- Anomaly detection:
  - Spam patterns / suspicious activity

---

### 3.3 Officer Decision Flow
- **High confidence**
  - Proceed normally
- **Medium confidence**
  - Requires manual verification
- **Low confidence**
  - Flag as suspicious
  - Options:
    - Reject issue
    - Investigate further

---

### 3.4 Manual Verification (Human-in-the-Loop)
- Officers act as validation authority:
  - Accept → Continue lifecycle
  - Reject → Mark as `Rejected`
  - Request more info → Notify citizen

---

## 4. Issue Resolution Workflow (Version-Control Inspired)

### 4.1 Status Lifecycle
- `Open`
- `Verified`
- `In Progress`
- `Under Review`
- `Resolved`
- `Closed`
- `Rejected`

---

### 4.2 Versioned Updates (Audit Trail)
Each update behaves like a commit log:
- Timestamp
- Officer ID
- Status change
- Notes

---

### 4.3 Media Uploads
- Required:
  - Before images
  - After images
  - Videos (optional)
- Purpose:
  - Proof of work
  - Transparency

---

## 5. Closed Issues Management

### 5.1 Closed Section
- Separate dashboard section for closed issues

---

### 5.2 Feedback Loop
- Citizens can:
  - Provide feedback
  - Challenge resolution

---

### 5.3 Reopening Logic
Closed → Reopened → In Progress

---

## 6. Real-Time Synchronization

### Requirements
- All dashboards must be **live and consistent**

### Suggested Technologies
- WebSockets
- Firebase Realtime DB
- Supabase Realtime

---

### Real-Time Events
- Status changes
- Votes
- Feedback
- Media uploads
- Confidence updates

---

## 7. Accountability & Data Integrity

### Mandatory Inputs During Resolution
- Action taken
- Resources used
- Time spent
- Optional GPS verification
- Media uploads

---

### Audit System
- Immutable logs
- Full traceability of:
  - Status changes
  - Verification decisions
  - Confidence overrides

---

## 8. Citizen Verification & Escalation

### Citizen Capabilities
- Mark issue:
  - ✅ Properly resolved
  - ❌ Not resolved

---

### Escalation Actions
- Reopen issue
- Raise complaint
- Create escalation ticket

---

## 9. Notification System

### Notification Triggers
- Status changes
- Verification decisions
- Resolution updates
- Feedback responses
- Reopen events

---

### Notification Channels
- In-app notifications
- Push notifications
- Email (optional)

---

## 10. System Architecture Overview

| Module                  | Responsibility |
|------------------------|---------------|
| Issue Service          | CRUD + lifecycle |
| AI Analysis Service    | Confidence scoring + explainability | (Improve or extend existing system) 
| Verification Engine    | Manual + AI validation |
| Realtime Engine        | Live synchronization |
| Media Service          | File storage |
| Notification Service   | Alerts |
| Audit Log System       | Immutable logs |
| Feedback System        | Citizen validation |

---

## 11. Core System Model

### Trust Architecture


- **AI Layer** → Initial validation (confidence scoring)
- **Officer Layer** → Manual verification
- **Citizen Layer** → Final validation

---

## 12. Optional Enhancements
- SLA tracking (resolution deadlines)
- Officer performance analytics
- AI-based priority prediction
- Fraud detection (fake closures)
- Reputation system for citizens

---

For AI use groq or custom built edge functions.

Cycle:
citizens reports --> Ai verifies (issue authenticity, auto write description, assign category etc..) --> issues delivers to respective department --> officer checks the issue (know more about it, asks ai for more details, do plannings, visit site, start resolving, upload results and progress and much more) --> issue gets resolved and closed --> citizens verify --> if unsatisfied --> raise complaint (ticket) --> again same process repeats 

# End-to-End Issue Lifecycle (Refined Workflow)

## Overview
This defines a **closed-loop, AI-assisted civic issue resolution pipeline** with continuous validation at three levels:
- AI (pre-validation)
- Officer (execution)
- Citizen (post-validation)

---

## 1. Citizen Reporting Phase
- Citizen submits an issue with:
  - Description (optional)
  - Images/videos
  - Location (GPS or manual)
- System generates:
  - Unique Issue ID
  - Timestamp
  - Initial status: `Open`

---

## 2. AI Pre-Processing & Verification
AI performs automated analysis immediately after submission.

### Responsibilities
- **Authenticity Check**
  - Detect if issue is genuine or spam
- **Auto-Enrichment**
  - Generate structured description
  - Assign category (e.g., pothole, garbage overflow)
  - Tag severity level
- **Confidence Scoring**
  - Output confidence score with explainability
- **Duplicate Detection**
  - Merge or link similar issues

### Output
- Status updated to: `AI Verified` *(or `Flagged` if suspicious)*
- Issue routed with:
  - Confidence score
  - AI-generated metadata

---

## 3. Department Routing
- Issue is automatically assigned using:
  - `departments.json` → category mapping
  - `places.json` → geographic mapping

### Outcome
- Delivered to **relevant department dashboard**
- Visible only to **authorized officers**

---

## 4. Officer Analysis & Planning Phase

### 4.1 Issue Inspection
- Officer reviews:
  - AI-generated description
  - Confidence score + reasoning
  - Media evidence
  - Location data

### 4.2 AI-Assisted Exploration
- Officer can query AI for:
  - Additional insights
  - Suggested resolution steps
  - Similar past cases
  - Resource estimation

### 4.3 Planning
- Officer prepares:
  - Resolution plan
  - Resource allocation
  - Timeline

### Status Transition

AI Verified → Verified → In Progress


---

## 5. Field Execution & Resolution

### Activities
- Site visit (if required)
- Execute resolution steps
- Continuously log progress

### Mandatory Updates
- Status updates (version-controlled)
- Notes (actions taken)
- Media uploads:
  - Before
  - During
  - After

### Status Flow

In Progress → Under Review → Resolved


---

## 6. Closure Phase
- After internal verification:
  - Issue marked as `Closed`
- All logs finalized:
  - Work summary
  - Resources used
  - Time spent
  - Supporting media

---

## 7. Citizen Verification Phase

### Citizen Actions
- Review:
  - Final status
  - Uploaded proof (images/videos)
- Provide feedback:
  - ✅ Satisfied → No action
  - ❌ Unsatisfied → Raise complaint

---

## 8. Complaint / Escalation Loop

### If Unsatisfied:
- Citizen creates a **complaint ticket**
- Ticket links to original issue

### System Behavior
- Issue status transitions:

Closed → Reopened → In Progress


- Re-enters workflow at **Officer Analysis Phase**

---

## 9. Continuous Feedback Loop
- System supports iterative resolution:
  - Multiple reopen cycles allowed
  - Each cycle logged independently

---

## 10. Real-Time Synchronization
- All stages are **live-updated across dashboards**

### Synced Entities
- Status changes
- Officer actions
- Citizen feedback
- AI updates
- Media uploads

---

## 11. Lifecycle Summary (Compact Flow)

Citizen Reports
→ AI Verification & Enrichment
→ Department Routing
→ Officer Analysis & Planning
→ Field Execution
→ Resolution & Closure
→ Citizen Verification
→ (If Unsatisfied → Complaint → Reopen → Repeat)


---

## 12. Key Design Characteristics

### 12.1 Human-in-the-Loop AI System
- AI assists but does not finalize decisions

### 12.2 Version-Control Inspired Tracking
- Every action = logged event (immutable)

### 12.3 Closed Feedback Loop
- Ensures:
  - Accountability
  - Transparency
  - Continuous improvement

### 12.4 Trust Layers
AI → Officer → Citizen


---

## 13. Optional Enhancements
- Auto-escalation if SLA breached
- AI-based fraud detection in complaints
- Predictive maintenance insights
- Officer workload balancing

---





