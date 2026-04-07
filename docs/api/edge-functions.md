# Edge Functions API

## Overview

Active Edge Functions are currently being refactored. Standard CRUD operations are handled directly via the Supabase Client.

### 1. Future Functions (Planned)
- `analyze-image`: Standard image classification
- `chatbot`: Support stream via Groq
- `notification-service`: Push notification triggers

---

## CORS

All functions return these headers on every response:

```
Access-Control-Allow-Origin: *
Access-Control-Allow-Headers: authorization, x-client-info, apikey, content-type
Access-Control-Allow-Methods: POST, OPTIONS
```

OPTIONS preflight requests return `200 OK` immediately.
