# NagarSewa AI Features Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Integrate AI capabilities (Groq + Supabase Edge Functions) into NagarSewa Flutter app for image analysis, chatbot, officer drafting, and admin reports.

**Architecture:** Supabase Edge Functions as secure proxy layer between Flutter client and Groq API. All model identifiers kept server-side. Rate limiting via Supabase DB. Flutter uses Riverpod for state management.

**Tech Stack:** Groq API (Llama 4 Scout, Llama 3.1 8B, Llama 3.3 70B), Supabase Edge Functions (Deno), Supabase PostgreSQL, Flutter Riverpod 3.x, flutter_image_compress

---

## Branch Structure

| Branch | Purpose | Depends On |
|--------|---------|------------|
| `ai/db-migration` | Rate limits table + pg_cron | None |
| `ai/edge-functions-shared` | CORS, auth, rate limit utilities | `ai/db-migration` |
| `ai/edge-function-analyze-image` | Vision + JSON analysis | `ai/edge-functions-shared` |
| `ai/edge-function-chatbot` | Streaming conversation | `ai/edge-functions-shared` |
| `ai/edge-function-draft-response` | Officer text drafting | `ai/edge-functions-shared` |
| `ai/edge-function-generate-report` | Admin summaries | `ai/edge-functions-shared` |
| `ai/flutter-ai-service` | AI models + service | All edge functions |
| `ai/flutter-ai-ui` | UI integration | `ai/flutter-ai-service` |

---

## Plan 1: Database Migration (`ai/db-migration`)

### Task 1.1: Create `ai_rate_limits` Table

**Files:**
- Create: `supabase/migrations/20260401_create_ai_rate_limits.sql`

- [ ] **Step 1: Write the migration SQL**

```sql
-- Create ai_rate_limits table for rate limiting
create table ai_rate_limits (
  id          bigserial primary key,
  user_id     uuid not null references auth.users(id) on delete cascade,
  feature     text not null,  -- 'analyze_image' | 'chatbot' | 'draft_response' | 'generate_report'
  created_at  timestamptz not null default now()
);

-- Index for fast per-user + per-feature time-window queries
create index idx_rate_limits_user_feature_time
  on ai_rate_limits (user_id, feature, created_at desc);

-- RLS: users cannot read/write this table directly
alter table ai_rate_limits enable row level security;

-- Only service_role (used inside Edge Functions) can insert/select
create policy "Service role can manage rate limits"
  on ai_rate_limits
  for all
  using (auth.role() = 'service_role')
  with check (auth.role() = 'service_role');
```

- [ ] **Step 2: Add pg_cron cleanup job**

```sql
-- Schedule cleanup job to delete old rate limit records
select cron.schedule(
  'cleanup-rate-limits',
  '* * * * *',  -- every minute
  $$delete from ai_rate_limits where created_at < now() - interval '2 minutes'$$
);
```

- [ ] **Step 3: Commit**

```bash
git add supabase/migrations/20260401_create_ai_rate_limits.sql
git commit -m "feat(ai): add ai_rate_limits table and cleanup cron job"
```

---

## Plan 2: Edge Functions Shared Utilities (`ai/edge-functions-shared`)

### Task 2.1: Create Shared Directory Structure

**Files:**
- Create: `supabase/functions/_shared/cors.ts`
- Create: `supabase/functions/_shared/auth.ts`
- Create: `supabase/functions/_shared/rate_limit.ts`

- [ ] **Step 1: Create CORS utility**

```typescript
// supabase/functions/_shared/cors.ts

export const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

export function handleCors(req: Request): Response | null {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }
  return null;
}

export function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

export function errorResponse(message: string, status = 500): Response {
  return jsonResponse({ error: message }, status);
}
```

- [ ] **Step 2: Create JWT auth utility**

```typescript
// supabase/functions/_shared/auth.ts
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { corsHeaders } from './cors.ts';

export async function verifyAuth(req: Request) {
  const token = req.headers.get('Authorization')?.replace('Bearer ', '');
  
  if (!token) {
    return { error: 'No authorization token provided', status: 401 };
  }

  const supabaseClient = createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
  );

  const { data: { user }, error } = await supabaseClient.auth.getUser(token);
  
  if (error || !user) {
    return { error: 'Unauthorized', status: 401 };
  }

  return { user, supabaseClient };
}
```

- [ ] **Step 3: Create rate limit utility**

```typescript
// supabase/functions/_shared/rate_limit.ts
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { corsHeaders, jsonResponse } from './cors.ts';

export interface RateLimitConfig {
  feature: string;
  maxRequests: number;
  windowMs: number;
}

const RATE_LIMITS: Record<string, RateLimitConfig> = {
  analyze_image: { feature: 'analyze_image', maxRequests: 10, windowMs: 60 * 1000 },
  chatbot: { feature: 'chatbot', maxRequests: 20, windowMs: 60 * 1000 },
  draft_response: { feature: 'draft_response', maxRequests: 10, windowMs: 60 * 1000 },
  generate_report: { feature: 'generate_report', maxRequests: 5, windowMs: 60 * 1000 },
};

export async function checkRateLimit(
  userId: string,
  featureKey: string,
  supabase: ReturnType<typeof createClient>
): Promise<{ allowed: boolean; remaining?: number }> {
  const config = RATE_LIMITS[featureKey];
  if (!config) {
    return { allowed: true };
  }

  const { count, error } = await supabase
    .from('ai_rate_limits')
    .select('*', { count: 'exact', head: true })
    .eq('user_id', userId)
    .eq('feature', config.feature)
    .gte('created_at', new Date(Date.now() - config.windowMs).toISOString());

  if (error) {
    console.error('Rate limit check failed:', error);
    return { allowed: true }; // Fail open for rate limit errors
  }

  const allowed = (count ?? 0) < config.maxRequests;
  return { allowed, remaining: config.maxRequests - (count ?? 0) };
}

export async function recordRequest(
  userId: string,
  featureKey: string,
  supabase: ReturnType<typeof createClient>
): Promise<void> {
  const config = RATE_LIMITS[featureKey];
  if (!config) return;

  await supabase.from('ai_rate_limits').insert({
    user_id: userId,
    feature: config.feature,
  });
}

export function rateLimitResponse(remaining: number): Response {
  return new Response(JSON.stringify({ error: 'Rate limit exceeded' }), {
    status: 429,
    headers: {
      ...corsHeaders,
      'Content-Type': 'application/json',
      'Retry-After': '60',
      'X-RateLimit-Remaining': String(remaining),
    },
  });
}
```

- [ ] **Step 4: Commit**

```bash
git add supabase/functions/_shared/
git commit -m "feat(ai): add shared Edge Functions utilities (CORS, auth, rate_limit)"
```

---

## Plan 3: Analyze Image Edge Function (`ai/edge-function-analyze-image`)

### Task 3.1: Create Analyze Image Edge Function

**Files:**
- Create: `supabase/functions/analyze-image/index.ts`

- [ ] **Step 1: Create the Edge Function**

```typescript
// supabase/functions/analyze-image/index.ts
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { handleCors, jsonResponse, errorResponse } from '../_shared/cors.ts';
import { verifyAuth } from '../_shared/auth.ts';
import { checkRateLimit, recordRequest, rateLimitResponse } from '../_shared/rate_limit.ts';

const GROQ_API_URL = 'https://api.groq.com/openai/v1/chat/completions';
const VISION_MODEL = Deno.env.get('GROQ_MODEL_VISION') ?? 'meta-llama/llama-4-scout-17b-16e-instruct';

const VALID_CATEGORIES = ['road', 'water', 'electricity', 'sanitation', 'garbage', 'other'];
const VALID_DEPARTMENTS = [
  'works_department', 'water_resources_department', 'housing_urban_development',
  'rural_development_department', 'energy_department', 'school_mass_education',
  'health_family_welfare', 'agriculture_farmers_empowerment', 'forest_environment',
  'revenue_disaster_management', 'commerce_transport', 'steel_mines_department',
  'tourism_culture', 'women_child_development', 'panchayati_raj', 'other_department'
];
const VALID_SEVERITIES = ['low', 'medium', 'high'];

interface ImageAnalysisRequest {
  imageBase64: string;
  locale: string;
}

function buildSystemPrompt(locale: string): string {
  const isOdiaLocale = locale?.startsWith('or') ?? false;
  const languageInstruction = isOdiaLocale
    ? 'Return the "title" and "description" fields in Odia script. Return all other fields in English.'
    : 'Return the "title" and "description" fields in English.';

  return `You are an AI assistant for NagarSewa, a civic issue reporting platform in Odisha, India.
Analyze the image and extract information about any civic infrastructure issues.

Return a valid JSON object with these exact fields:
{
  "title": "Brief title of the issue (max 100 characters)",
  "description": "Detailed description of the issue (max 500 characters)",
  "category": "One of: ${VALID_CATEGORIES.join(' | ')}",
  "category_confidence": 0.0 to 1.0,
  "severity": "One of: ${VALID_SEVERITIES.join(' | ')}",
  "severity_confidence": 0.0 to 1.0,
  "suggested_department": "One of: ${VALID_DEPARTMENTS.join(' | ')}",
  "department_confidence": 0.0 to 1.0,
  "extracted_text": ["array of detected text strings, empty array if none"],
  "warnings": ["array of warnings like 'image_quality_low', 'multiple_issues_detected', etc."]
}

${languageInstruction}
Enums (category, severity, suggested_department) MUST be in English.
If no text is detected, return empty array for extracted_text.
If no issues are detected in the image, set category to 'other' and add 'no_civic_issue_detected' to warnings.`;
}

serve(async (req) => {
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  try {
    const authResult = await verifyAuth(req);
    if ('error' in authResult) {
      return errorResponse(authResult.error, authResult.status);
    }
    const { user, supabaseClient } = authResult;

    const rateLimitResult = await checkRateLimit(user.id, 'analyze_image', supabaseClient);
    if (!rateLimitResult.allowed) {
      return rateLimitResponse(rateLimitResult.remaining ?? 0);
    }

    const { imageBase64, locale } = await req.json() as ImageAnalysisRequest;

    if (!imageBase64 || typeof imageBase64 !== 'string') {
      return errorResponse('invalid_payload: imageBase64 is required', 400);
    }

    const estimatedBytes = imageBase64.length * 0.75;
    const maxBytes = 4 * 1024 * 1024;
    if (estimatedBytes > maxBytes) {
      return jsonResponse({ error: 'image_too_large' }, 400);
    }

    await recordRequest(user.id, 'analyze_image', supabaseClient);

    const systemPrompt = buildSystemPrompt(locale);

    const groqResponse = await fetch(GROQ_API_URL, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${Deno.env.get('GROQ_API_KEY')}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: VISION_MODEL,
        messages: [
          { role: 'system', content: systemPrompt },
          { role: 'user', content: [
            { type: 'text', text: 'Analyze this image and extract civic issue information.' },
            { type: 'image_url', image_url: { url: `data:image/jpeg;base64,${imageBase64}` } }
          ]}
        ],
        temperature: 0.3,
        response_format: { type: 'json_object' },
      }),
    });

    if (!groqResponse.ok) {
      const errorText = await groqResponse.text();
      console.error('Groq API error:', errorText);
      return errorResponse('groq_error', 500);
    }

    const groqData = await groqResponse.json();
    const content = groqData.choices?.[0]?.message?.content;

    if (!content) {
      return errorResponse('no_response_from_llm', 500);
    }

    let analysis = JSON.parse(content);

    // Validate and correct enum values
    if (!VALID_CATEGORIES.includes(analysis.category)) {
      analysis.category = 'other';
    }
    if (!VALID_DEPARTMENTS.includes(analysis.suggested_department)) {
      analysis.suggested_department = 'other_department';
    }
    if (!VALID_SEVERITIES.includes(analysis.severity)) {
      analysis.severity = 'medium';
    }

    // Ensure arrays are always arrays
    analysis.extracted_text = Array.isArray(analysis.extracted_text) ? analysis.extracted_text : [];
    analysis.warnings = Array.isArray(analysis.warnings) ? analysis.warnings : [];

    // Add server-side timestamp
    analysis.analysis_timestamp = new Date().toISOString();

    return jsonResponse(analysis);
  } catch (error) {
    console.error('Analyze image error:', error);
    if (error instanceof SyntaxError) {
      return errorResponse('json_parse_fail', 500);
    }
    return errorResponse('internal_error', 500);
  }
});
```

- [ ] **Step 2: Commit**

```bash
git add supabase/functions/analyze-image/
git commit -m "feat(ai): add analyze-image Edge Function with vision analysis"
```

---

## Plan 4: Chatbot Edge Function (`ai/edge-function-chatbot`)

### Task 4.1: Create Chatbot Edge Function

**Files:**
- Create: `supabase/functions/chatbot/index.ts`

- [ ] **Step 1: Create the Edge Function with SSE streaming**

```typescript
// supabase/functions/chatbot/index.ts
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { handleCors, jsonResponse, errorResponse } from '../_shared/cors.ts';
import { verifyAuth } from '../_shared/auth.ts';
import { checkRateLimit, recordRequest, rateLimitResponse } from '../_shared/rate_limit.ts';

const GROQ_API_URL = 'https://api.groq.com/openai/v1/chat/completions';
const CHAT_MODEL = Deno.env.get('GROQ_MODEL_CHAT') ?? 'llama-3.1-8b-instant';

interface ChatMessage {
  role: 'user' | 'assistant' | 'system';
  content: string;
}

interface ChatRequest {
  message: string;
  history: ChatMessage[];
  locale: string;
}

function buildSystemPrompt(locale: string): string {
  const isOdiaLocale = locale?.startsWith('or') ?? false;
  const languageInstruction = isOdiaLocale
    ? 'Always detect the language of the user\'s message and respond in the same language. If the user writes in Odia script, respond in Odia.'
    : 'Always respond in English.';

  return `You are a civic helpdesk assistant for NagarSewa, Odisha's civic issue reporting platform.
You help citizens with:
- Tracking complaint status
- Understanding document requirements
- Learning about the complaint process
- Getting department contact information

Be concise, helpful, and friendly. Provide accurate information based on the context provided.
${languageInstruction}
If you don't know something, say so honestly rather than making up information.`;
}

serve(async (req) => {
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  try {
    const authResult = await verifyAuth(req);
    if ('error' in authResult) {
      return errorResponse(authResult.error, authResult.status);
    }
    const { user, supabaseClient } = authResult;

    const rateLimitResult = await checkRateLimit(user.id, 'chatbot', supabaseClient);
    if (!rateLimitResult.allowed) {
      return rateLimitResponse(rateLimitResult.remaining ?? 0);
    }

    const { message, history = [], locale = 'en' } = await req.json() as ChatRequest;

    if (!message || typeof message !== 'string') {
      return errorResponse('invalid_payload: message is required', 400);
    }

    await recordRequest(user.id, 'chatbot', supabaseClient);

    const systemPrompt = buildSystemPrompt(locale);
    
    const messages = [
      { role: 'system', content: systemPrompt },
      ...history.slice(-10), // Last 10 messages
      { role: 'user', content: message }
    ];

    // Use streaming response
    const groqResponse = await fetch(GROQ_API_URL, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${Deno.env.get('GROQ_API_KEY')}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: CHAT_MODEL,
        messages,
        stream: true,
        temperature: 0.7,
      }),
    });

    if (!groqResponse.ok) {
      const errorText = await groqResponse.text();
      console.error('Groq API error:', errorText);
      return errorResponse('groq_error', 500);
    }

    // Stream response back to client
    const stream = new ReadableStream({
      async start(controller) {
        const reader = groqResponse.body?.getReader();
        if (!reader) {
          controller.close();
          return;
        }

        const decoder = new TextDecoder();
        let buffer = '';

        try {
          while (true) {
            const { done, value } = await reader.read();
            if (done) break;

            buffer += decoder.decode(value, { stream: true });
            const lines = buffer.split('\n');
            buffer = lines.pop() ?? '';

            for (const line of lines) {
              if (line.startsWith('data: ')) {
                const data = line.slice(6);
                if (data === '[DONE]') {
                  controller.enqueue(new TextEncoder().encode('data: [DONE]\n\n'));
                } else {
                  try {
                    const parsed = JSON.parse(data);
                    const content = parsed.choices?.[0]?.delta?.content;
                    if (content) {
                      controller.enqueue(new TextEncoder().encode(`data: ${JSON.stringify({ content })}\n\n`));
                    }
                  } catch {
                    // Skip invalid JSON
                  }
                }
              }
            }
          }
        } finally {
          reader.releaseLock();
          controller.close();
        }
      },
    });

    return new Response(stream, {
      headers: {
        ...Object.fromEntries(Object.entries({
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
          'Content-Type': 'text/event-stream',
          'Cache-Control': 'no-cache',
          'Connection': 'keep-alive',
        })),
      },
    });
  } catch (error) {
    console.error('Chatbot error:', error);
    return errorResponse('internal_error', 500);
  }
});
```

- [ ] **Step 2: Commit**

```bash
git add supabase/functions/chatbot/
git commit -m "feat(ai): add chatbot Edge Function with SSE streaming"
```

---

## Plan 5: Draft Response Edge Function (`ai/edge-function-draft-response`)

### Task 5.1: Create Draft Response Edge Function

**Files:**
- Create: `supabase/functions/draft-response/index.ts`

- [ ] **Step 1: Create the Edge Function**

```typescript
// supabase/functions/draft-response/index.ts
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { handleCors, jsonResponse, errorResponse } from '../_shared/cors.ts';
import { verifyAuth } from '../_shared/auth.ts';
import { checkRateLimit, recordRequest, rateLimitResponse } from '../_shared/rate_limit.ts';

const GROQ_API_URL = 'https://api.groq.com/openai/v1/chat/completions';
const DRAFT_MODEL = Deno.env.get('GROQ_MODEL_DRAFT') ?? 'llama-3.3-70b-versatile';

interface StatusLogEntry {
  changed_by_name: string;
  old_status: string;
  new_status: string;
  officer_note: string;
  changed_at: string;
}

interface DraftRequest {
  issueTitle: string;
  category: string;
  currentStatus: string;
  lastTwoLogs: StatusLogEntry[];
}

function buildSystemPrompt(): string {
  return `You are an administrative assistant helping government officers draft professional resolution notes for civic issues.

Given the issue details and status history, generate a professional resolution note in English that:
1. Summarizes the issue briefly
2. Describes actions taken based on status changes
3. Provides a clear resolution status
4. Is formal and appropriate for official records

Keep the tone professional and concise. Output only the draft resolution note text, no additional commentary.`;
}

serve(async (req) => {
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  try {
    const authResult = await verifyAuth(req);
    if ('error' in authResult) {
      return errorResponse(authResult.error, authResult.status);
    }
    const { user, supabaseClient } = authResult;

    const rateLimitResult = await checkRateLimit(user.id, 'draft_response', supabaseClient);
    if (!rateLimitResult.allowed) {
      return rateLimitResponse(rateLimitResult.remaining ?? 0);
    }

    const { issueTitle, category, currentStatus, lastTwoLogs = [] } = await req.json() as DraftRequest;

    if (!issueTitle) {
      return errorResponse('invalid_payload: issueTitle is required', 400);
    }

    await recordRequest(user.id, 'draft_response', supabaseClient);

    const systemPrompt = buildSystemPrompt();
    
    const historyContext = lastTwoLogs.length > 0
      ? lastTwoLogs.map(log => 
          `- ${log.changed_at}: ${log.changed_by_name} changed status from ${log.old_status} to ${log.new_status}. ${log.officer_note || '(no note)'}`
        ).join('\n')
      : 'No status changes recorded yet.';

    const userMessage = `Issue: ${issueTitle}
Category: ${category}
Current Status: ${currentStatus}

Recent Status Changes:
${historyContext}

Please draft a professional resolution note.`;

    const groqResponse = await fetch(GROQ_API_URL, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${Deno.env.get('GROQ_API_KEY')}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: DRAFT_MODEL,
        messages: [
          { role: 'system', content: systemPrompt },
          { role: 'user', content: userMessage }
        ],
        temperature: 0.5,
      }),
    });

    if (!groqResponse.ok) {
      const errorText = await groqResponse.text();
      console.error('Groq API error:', errorText);
      return errorResponse('groq_error', 500);
    }

    const groqData = await groqResponse.json();
    const draftText = groqData.choices?.[0]?.message?.content;

    if (!draftText) {
      return errorResponse('no_response_from_llm', 500);
    }

    return jsonResponse({ draft: draftText.trim() });
  } catch (error) {
    console.error('Draft response error:', error);
    return errorResponse('internal_error', 500);
  }
});
```

- [ ] **Step 2: Commit**

```bash
git add supabase/functions/draft-response/
git commit -m "feat(ai): add draft-response Edge Function for officer drafting"
```

---

## Plan 6: Generate Report Edge Function (`ai/edge-function-generate-report`)

### Task 6.1: Create Generate Report Edge Function

**Files:**
- Create: `supabase/functions/generate-report/index.ts`

- [ ] **Step 1: Create the Edge Function**

```typescript
// supabase/functions/generate-report/index.ts
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { handleCors, jsonResponse, errorResponse } from '../_shared/cors.ts';
import { verifyAuth } from '../_shared/auth.ts';
import { checkRateLimit, recordRequest, rateLimitResponse } from '../_shared/rate_limit.ts';

const GROQ_API_URL = 'https://api.groq.com/openai/v1/chat/completions';
const REPORT_MODEL = Deno.env.get('GROQ_MODEL_REPORT') ?? 'llama-3.3-70b-versatile';

interface ReportFilters {
  district?: string;
  department?: string;
  startDate?: string;
  endDate?: string;
  category?: string;
}

interface AggregatedData {
  totalIssues: number;
  byStatus: Record<string, number>;
  byCategory: Record<string, number>;
  bySeverity: Record<string, number>;
  byDepartment: Record<string, number>;
  recentTrend: { date: string; count: number }[];
}

interface ReportRequest {
  filters: ReportFilters;
}

function buildSystemPrompt(): string {
  return `You are a data analyst assistant for NagarSewa, Odisha's civic issue reporting platform.

You will receive pre-aggregated data about civic issues. Your task is to:
1. Analyze the data and identify key trends
2. Highlight notable patterns (high/low areas, trending categories, etc.)
3. Provide actionable insights in a readable prose format

Format your response as a clear, professional report with:
- Executive summary (2-3 sentences)
- Key findings (bullet points)
- Observations about trends
- Any notable outliers or concerns

Keep the analysis focused and avoid speculation beyond what the data shows.`;
}

serve(async (req) => {
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  try {
    const authResult = await verifyAuth(req);
    if ('error' in authResult) {
      return errorResponse(authResult.error, authResult.status);
    }
    const { user, supabaseClient } = authResult;

    const rateLimitResult = await checkRateLimit(user.id, 'generate_report', supabaseClient);
    if (!rateLimitResult.allowed) {
      return rateLimitResponse(rateLimitResult.remaining ?? 0);
    }

    const { filters = {} } = await req.json() as ReportRequest;

    await recordRequest(user.id, 'generate_report', supabaseClient);

    // Build aggregation query
    let query = supabaseClient
      .from('issues')
      .select('status, category, severity, department_id, created_at');

    if (filters.district) {
      query = query.eq('district', filters.district);
    }
    if (filters.category) {
      query = query.eq('category', filters.category);
    }
    if (filters.startDate) {
      query = query.gte('created_at', filters.startDate);
    }
    if (filters.endDate) {
      query = query.lte('created_at', filters.endDate);
    }

    const { data: issues, error: queryError } = await query;

    if (queryError) {
      console.error('Query error:', queryError);
      return errorResponse('database_error', 500);
    }

    // Aggregate data
    const aggregated: AggregatedData = {
      totalIssues: issues?.length ?? 0,
      byStatus: {},
      byCategory: {},
      bySeverity: {},
      byDepartment: {},
      recentTrend: [],
    };

    for (const issue of issues ?? []) {
      aggregated.byStatus[issue.status] = (aggregated.byStatus[issue.status] ?? 0) + 1;
      aggregated.byCategory[issue.category] = (aggregated.byCategory[issue.category] ?? 0) + 1;
      aggregated.bySeverity[issue.severity] = (aggregated.bySeverity[issue.severity] ?? 0) + 1;
      if (issue.department_id) {
        aggregated.byDepartment[issue.department_id] = (aggregated.byDepartment[issue.department_id] ?? 0) + 1;
      }

      const date = issue.created_at.split('T')[0];
      const trendEntry = aggregated.recentTrend.find(t => t.date === date);
      if (trendEntry) {
        trendEntry.count++;
      } else {
        aggregated.recentTrend.push({ date, count: 1 });
      }
    }

    // Sort trend by date
    aggregated.recentTrend.sort((a, b) => a.date.localeCompare(b.date));

    // Generate report with LLM
    const systemPrompt = buildSystemPrompt();
    const userMessage = `Here is the aggregated issue data:

Total Issues: ${aggregated.totalIssues}

By Status:
${JSON.stringify(aggregated.byStatus, null, 2)}

By Category:
${JSON.stringify(aggregated.byCategory, null, 2)}

By Severity:
${JSON.stringify(aggregated.bySeverity, null, 2)}

${filters.district ? `District: ${filters.district}\n` : ''}${filters.category ? `Category Filter: ${filters.category}\n` : ''}${filters.startDate ? `From: ${filters.startDate}\n` : ''}${filters.endDate ? `To: ${filters.endDate}\n` : ''}

Please generate a summary report.`;

    const groqResponse = await fetch(GROQ_API_URL, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${Deno.env.get('GROQ_API_KEY')}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: REPORT_MODEL,
        messages: [
          { role: 'system', content: systemPrompt },
          { role: 'user', content: userMessage }
        ],
        temperature: 0.3,
      }),
    });

    if (!groqResponse.ok) {
      const errorText = await groqResponse.text();
      console.error('Groq API error:', errorText);
      return errorResponse('groq_error', 500);
    }

    const groqData = await groqResponse.json();
    const reportText = groqData.choices?.[0]?.message?.content;

    if (!reportText) {
      return errorResponse('no_response_from_llm', 500);
    }

    return jsonResponse({
      report: reportText.trim(),
      aggregated,
      generatedAt: new Date().toISOString(),
    });
  } catch (error) {
    console.error('Generate report error:', error);
    return errorResponse('internal_error', 500);
  }
});
```

- [ ] **Step 2: Commit**

```bash
git add supabase/functions/generate-report/
git commit -m "feat(ai): add generate-report Edge Function for admin summaries"
```

---

## Plan 7: Flutter AI Service (`ai/flutter-ai-service`)

### Task 7.1: Create AI Models

**Files:**
- Create: `lib/models/ai_models.dart`

- [ ] **Step 1: Define AI models**

```dart
// lib/models/ai_models.dart

class ImageAnalysisResult {
  final String title;
  final String description;
  final String category;
  final double categoryConfidence;
  final String severity;
  final double severityConfidence;
  final String suggestedDepartment;
  final double departmentConfidence;
  final List<String> extractedText;
  final List<String> warnings;
  final DateTime analysisTimestamp;

  const ImageAnalysisResult({
    required this.title,
    required this.description,
    required this.category,
    required this.categoryConfidence,
    required this.severity,
    required this.severityConfidence,
    required this.suggestedDepartment,
    required this.departmentConfidence,
    required this.extractedText,
    required this.warnings,
    required this.analysisTimestamp,
  });

  factory ImageAnalysisResult.fromJson(Map<String, dynamic> json) {
    return ImageAnalysisResult(
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      category: json['category'] as String? ?? 'other',
      categoryConfidence: (json['category_confidence'] as num?)?.toDouble() ?? 0.0,
      severity: json['severity'] as String? ?? 'medium',
      severityConfidence: (json['severity_confidence'] as num?)?.toDouble() ?? 0.0,
      suggestedDepartment: json['suggested_department'] as String? ?? 'other_department',
      departmentConfidence: (json['department_confidence'] as num?)?.toDouble() ?? 0.0,
      extractedText: (json['extracted_text'] as List<dynamic>?)?.cast<String>() ?? [],
      warnings: (json['warnings'] as List<dynamic>?)?.cast<String>() ?? [],
      analysisTimestamp: json['analysis_timestamp'] != null
          ? DateTime.parse(json['analysis_timestamp'] as String)
          : DateTime.now(),
    );
  }

  bool get hasLowConfidence =>
      categoryConfidence < 0.7 || severityConfidence < 0.7 || departmentConfidence < 0.7;
}

class ChatMessage {
  final String role;
  final String content;

  const ChatMessage({required this.role, required this.content});

  Map<String, dynamic> toJson() => {'role': role, 'content': content};

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      role: json['role'] as String,
      content: json['content'] as String,
    );
  }
}

class StatusLogEntry {
  final String changedByName;
  final String oldStatus;
  final String newStatus;
  final String officerNote;
  final DateTime changedAt;

  const StatusLogEntry({
    required this.changedByName,
    required this.oldStatus,
    required this.newStatus,
    required this.officerNote,
    required this.changedAt,
  });

  Map<String, dynamic> toJson() => {
        'changed_by_name': changedByName,
        'old_status': oldStatus,
        'new_status': newStatus,
        'officer_note': officerNote,
        'changed_at': changedAt.toIso8601String(),
      };
}

class ReportFilters {
  final String? district;
  final String? department;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? category;

  const ReportFilters({
    this.district,
    this.department,
    this.startDate,
    this.endDate,
    this.category,
  });

  Map<String, dynamic> toJson() => {
        if (district != null) 'district': district,
        if (department != null) 'department': department,
        if (startDate != null) 'startDate': startDate!.toIso8601String().split('T')[0],
        if (endDate != null) 'endDate': endDate!.toIso8601String().split('T')[0],
        if (category != null) 'category': category,
      };
}

class AiException implements Exception {
  final String message;
  final int? statusCode;
  final String? errorCode;

  const AiException({
    required this.message,
    this.statusCode,
    this.errorCode,
  });

  factory AiException.fromResponse(int statusCode, Map<String, dynamic> json) {
    final error = json['error'];
    if (error is String) {
      return AiException(message: error, statusCode: statusCode, errorCode: error);
    }
    return AiException(
      message: json['error']?['message'] ?? 'Unknown error',
      statusCode: statusCode,
      errorCode: json['error']?['code'],
    );
  }

  @override
  String toString() => 'AiException: $message (code: $errorCode, status: $statusCode)';
}

class ReportResult {
  final String report;
  final Map<String, dynamic> aggregated;
  final DateTime generatedAt;

  const ReportResult({
    required this.report,
    required this.aggregated,
    required this.generatedAt,
  });

  factory ReportResult.fromJson(Map<String, dynamic> json) {
    return ReportResult(
      report: json['report'] as String? ?? '',
      aggregated: json['aggregated'] as Map<String, dynamic>? ?? {},
      generatedAt: json['generatedAt'] != null
          ? DateTime.parse(json['generatedAt'] as String)
          : DateTime.now(),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/models/ai_models.dart
git commit -m "feat(ai): add AI models (ImageAnalysisResult, ChatMessage, etc.)"
```

### Task 7.2: Create AI Service

**Files:**
- Create: `lib/services/ai_service.dart`

- [ ] **Step 1: Add flutter_image_compress to pubspec.yaml**

```yaml
dependencies:
  flutter_image_compress: ^2.2.0
```

- [ ] **Step 2: Create AI Service**

```dart
// lib/services/ai_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/ai_models.dart';

class AiService {
  final SupabaseClient _client;
  static const String _baseUrl = 'functions/v1';

  AiService(this._client);

  Future<Uint8List> _compressImage(Uint8List raw) async {
    return await FlutterImageCompress.compressWithList(
      raw,
      minWidth: 1024,
      minHeight: 1024,
      quality: 75,
      format: CompressFormat.jpeg,
    );
  }

  Future<T> _withRetry<T>(Future<T> Function() fn) async {
    const delays = [Duration(seconds: 2), Duration(seconds: 4), Duration(seconds: 8)];
    for (int i = 0; i <= delays.length; i++) {
      try {
        return await fn();
      } catch (e) {
        if (i == delays.length) rethrow;
        if (e is AiException &&
            (e.statusCode == 401 || e.statusCode == 400)) rethrow;
        await Future.delayed(delays[i]);
      }
    }
    throw StateError('unreachable');
  }

  Future<ImageAnalysisResult> analyzeImage(
    Uint8List imageBytes,
    String locale,
  ) async {
    return _withRetry(() async {
      final compressed = await _compressImage(imageBytes);
      final base64 = base64Encode(compressed);

      final response = await _client.functions.invoke(
        'analyze-image',
        body: {
          'imageBase64': base64,
          'locale': locale,
        },
      );

      if (response.status != 200) {
        final data = response.data as Map<String, dynamic>?;
        final error = data?['error'];
        
        if (response.status == 400 && error == 'image_too_large') {
          throw const AiException(
            message: 'Photo is too large. Try a smaller image or enter details manually.',
            statusCode: 400,
            errorCode: 'image_too_large',
          );
        }
        if (response.status == 401) {
          throw const AiException(
            message: 'Session expired. Please log in again.',
            statusCode: 401,
          );
        }
        if (response.status == 429) {
          throw const AiException(
            message: 'Too many requests. Please wait a moment and try again.',
            statusCode: 429,
          );
        }
        if (response.status == 500 && error == 'json_parse_fail') {
          throw const AiException(
            message: 'Could not understand the image. Please enter details manually.',
            statusCode: 500,
            errorCode: 'json_parse_fail',
          );
        }
        throw AiException.fromResponse(response.status, data ?? {});
      }

      final data = response.data as Map<String, dynamic>;
      return ImageAnalysisResult.fromJson(data);
    });
  }

  Stream<String> chat(
    String message,
    List<ChatMessage> history,
    String locale,
  ) async* {
    final response = await _client.functions.invoke(
      'chatbot',
      body: {
        'message': message,
        'history': history.map((m) => m.toJson()).toList(),
        'locale': locale,
      },
    );

    if (response.status != 200) {
      final data = response.data as Map<String, dynamic>?;
      if (response.status == 401) {
        throw const AiException(
          message: 'Session expired. Please log in again.',
          statusCode: 401,
        );
      }
      if (response.status == 429) {
        throw const AiException(
          message: 'Too many requests. Please wait a moment and try again.',
          statusCode: 429,
        );
      }
      throw AiException.fromResponse(
        response.status,
        data ?? {},
      );
    }

    // For simplicity, return the full response
    // Full streaming implementation would require SSE handling
    final data = response.data;
    if (data is String) {
      yield data;
    } else if (data is Map && data['content'] != null) {
      yield data['content'] as String;
    }
  }

  Future<String> draftResolutionNote(
    String issueTitle,
    String category,
    String currentStatus,
    List<StatusLogEntry> lastTwoLogs,
  ) async {
    return _withRetry(() async {
      final response = await _client.functions.invoke(
        'draft-response',
        body: {
          'issueTitle': issueTitle,
          'category': category,
          'currentStatus': currentStatus,
          'lastTwoLogs': lastTwoLogs.map((e) => e.toJson()).toList(),
        },
      );

      if (response.status != 200) {
        final data = response.data as Map<String, dynamic>?;
        if (response.status == 401) {
          throw const AiException(
            message: 'Session expired. Please log in again.',
            statusCode: 401,
          );
        }
        if (response.status == 429) {
          throw const AiException(
            message: 'Too many requests. Please wait a moment and try again.',
            statusCode: 429,
          );
        }
        throw AiException.fromResponse(response.status, data ?? {});
      }

      final data = response.data as Map<String, dynamic>;
      return data['draft'] as String? ?? '';
    });
  }

  Future<ReportResult> generateReport(ReportFilters filters) async {
    return _withRetry(() async {
      final response = await _client.functions.invoke(
        'generate-report',
        body: {
          'filters': filters.toJson(),
        },
      );

      if (response.status != 200) {
        final data = response.data as Map<String, dynamic>?;
        if (response.status == 401) {
          throw const AiException(
            message: 'Session expired. Please log in again.',
            statusCode: 401,
          );
        }
        if (response.status == 429) {
          throw const AiException(
            message: 'Too many requests. Please wait a moment and try again.',
            statusCode: 429,
          );
        }
        throw AiException.fromResponse(response.status, data ?? {});
      }

      final data = response.data as Map<String, dynamic>;
      return ReportResult.fromJson(data);
    });
  }
}
```

- [ ] **Step 3: Commit**

```bash
git add pubspec.yaml lib/services/ai_service.dart
git commit -m "feat(ai): add AiService with image analysis, chatbot, drafting, reports"
```

---

## Plan 8: Flutter AI UI Integration (`ai/flutter-ai-ui`)

### Task 8.1: Create AI Image Analysis Notifier

**Files:**
- Create: `lib/features/report/notifiers/ai_image_analysis_notifier.dart`

- [ ] **Step 1: Create AsyncNotifier for image analysis**

```dart
// lib/features/report/notifiers/ai_image_analysis_notifier.dart
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/ai_models.dart';
import '../../services/ai_service.dart';
import '../../providers/ai_service_provider.dart';

final aiImageAnalysisProvider =
    AsyncNotifierProvider<AiImageAnalysisNotifier, ImageAnalysisResult?>(
  AiImageAnalysisNotifier.new,
);

class AiImageAnalysisNotifier extends AsyncNotifier<ImageAnalysisResult?> {
  bool _mounted = true;

  @override
  Future<ImageAnalysisResult?> build() async {
    ref.onDispose(() => _mounted = false);
    return null;
  }

  Future<void> analyzeImage(Uint8List imageBytes, String locale) async {
    state = const AsyncLoading();
    final startTime = DateTime.now();
    final aiService = ref.read(aiServiceProvider);

    try {
      final result = await aiService.analyzeImage(imageBytes, locale);
      
      final elapsed = DateTime.now().difference(startTime);
      if (elapsed < const Duration(milliseconds: 300)) {
        await Future.delayed(const Duration(milliseconds: 300) - elapsed);
      }
      
      if (_mounted) {
        state = AsyncData(result);
      }
    } catch (e, st) {
      if (_mounted) {
        state = AsyncError(e, st);
      }
    }
  }

  void clear() {
    state = const AsyncData(null);
  }
}
```

- [ ] **Step 2: Create AI service provider**

```dart
// lib/providers/ai_service_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/ai_service.dart';

final aiServiceProvider = Provider<AiService>((ref) {
  final client = Supabase.instance.client;
  return AiService(client);
});
```

- [ ] **Step 3: Commit**

```bash
git add lib/features/report/notifiers/ai_image_analysis_notifier.dart lib/providers/ai_service_provider.dart
git commit -m "feat(ai): add image analysis notifier with shimmer handling"
```

### Task 8.2: Create Chatbot Notifiers

**Files:**
- Create: `lib/features/chat/notifiers/chat_history_notifier.dart`
- Create: `lib/features/chat/notifiers/chatbot_notifier.dart`

- [ ] **Step 1: Create chat history notifier**

```dart
// lib/features/chat/notifiers/chat_history_notifier.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/ai_models.dart';

final chatHistoryProvider =
    NotifierProvider<ChatHistoryNotifier, List<ChatMessage>>(
  ChatHistoryNotifier.new,
);

class ChatHistoryNotifier extends Notifier<List<ChatMessage>> {
  static const int maxHistorySize = 10;
  static const int summarizationThreshold = 10;
  static const int messagesToSummarize = 6;

  @override
  List<ChatMessage> build() => [];

  void addUserMessage(String content) {
    state = [
      ...state,
      ChatMessage(role: 'user', content: content),
    ];

    if (state.length > summarizationThreshold) {
      _summarizeAndTrim();
    }
  }

  void addAssistantMessage(String content) {
    state = [
      ...state,
      ChatMessage(role: 'assistant', content: content),
    ];
  }

  void _summarizeAndTrim() {
    final messagesToKeep = state.length - messagesToSummarize;
    final messagesToSummarizeList = state.sublist(0, messagesToSummarize);
    
    final summary = messagesToSummarizeList
        .map((m) => '${m.role}: ${m.content}')
        .join(' | ');

    state = [
      ChatMessage(
        role: 'system',
        content: 'Previous conversation summary: $summary',
      ),
      ...state.sublist(messagesToSummarize),
    ];
  }

  void clear() {
    state = [];
  }
}
```

- [ ] **Step 2: Create chatbot notifier**

```dart
// lib/features/chat/notifiers/chatbot_notifier.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/ai_models.dart';
import '../../../providers/ai_service_provider.dart';
import 'chat_history_notifier.dart';

final chatbotProvider =
    AsyncNotifierProvider<ChatbotNotifier, String>(
  ChatbotNotifier.new,
);

class ChatbotNotifier extends AsyncNotifier<String> {
  @override
  Future<String> build() async => '';

  Future<void> sendMessage(String message, String locale) async {
    final history = ref.read(chatHistoryProvider);
    final aiService = ref.read(aiServiceProvider);

    ref.read(chatHistoryProvider.notifier).addUserMessage(message);
    state = const AsyncLoading();

    try {
      final response = StringBuffer();
      await for (final chunk in aiService.chat(message, history, locale)) {
        response.write(chunk);
        if (state.value != null) {
          state = AsyncData(state.value! + chunk);
        } else {
          state = AsyncData(chunk);
        }
      }

      final fullResponse = response.toString();
      ref.read(chatHistoryProvider.notifier).addAssistantMessage(fullResponse);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  void clearChat() {
    ref.read(chatHistoryProvider.notifier).clear();
    state = const AsyncData('');
  }
}
```

- [ ] **Step 3: Commit**

```bash
git add lib/features/chat/notifiers/
git commit -m "feat(ai): add chatbot notifiers with history management and summarization"
```

### Task 8.3: Create Officer Drafting Notifier

**Files:**
- Create: `lib/features/officer/notifiers/draft_response_notifier.dart`

- [ ] **Step 1: Create draft response notifier**

```dart
// lib/features/officer/notifiers/draft_response_notifier.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/ai_models.dart';
import '../../../providers/ai_service_provider.dart';

final draftResponseProvider =
    AsyncNotifierProvider<DraftResponseNotifier, String?>(
  DraftResponseNotifier.new,
);

class DraftResponseNotifier extends AsyncNotifier<String?> {
  @override
  Future<String?> build() async => null;

  Future<void> generateDraft(
    String issueTitle,
    String category,
    String currentStatus,
    List<StatusLogEntry> lastTwoLogs,
  ) async {
    state = const AsyncLoading();
    final aiService = ref.read(aiServiceProvider);

    try {
      final draft = await aiService.draftResolutionNote(
        issueTitle,
        category,
        currentStatus,
        lastTwoLogs,
      );
      state = AsyncData(draft);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  void clear() {
    state = const AsyncData(null);
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/features/officer/notifiers/draft_response_notifier.dart
git commit -m "feat(ai): add officer draft response notifier"
```

### Task 8.4: Create Admin Report Notifier

**Files:**
- Create: `lib/features/admin/notifiers/ai_report_notifier.dart`

- [ ] **Step 1: Create admin report notifier with caching**

```dart
// lib/features/admin/notifiers/ai_report_notifier.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/ai_models.dart';
import '../../../providers/ai_service_provider.dart';

final aiReportProvider =
    AsyncNotifierProvider<AiReportNotifier, ReportResult?>(
  AiReportNotifier.new,
);

class AiReportNotifier extends AsyncNotifier<ReportResult?> {
  DateTime? _lastFetchTime;
  ReportFilters? _lastFilters;
  static const Duration cacheDuration = Duration(minutes: 5);

  @override
  Future<ReportResult?> build() async => null;

  Future<void> generateReport(ReportFilters filters) async {
    if (_lastFilters == filters &&
        _lastFetchTime != null &&
        DateTime.now().difference(_lastFetchTime!) < cacheDuration) {
      return;
    }

    state = const AsyncLoading();
    final aiService = ref.read(aiServiceProvider);

    try {
      final result = await aiService.generateReport(filters);
      _lastFetchTime = DateTime.now();
      _lastFilters = filters;
      state = AsyncData(result);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  void invalidateCache() {
    _lastFetchTime = null;
    _lastFilters = null;
  }

  void clear() {
    state = const AsyncData(null);
    invalidateCache();
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/features/admin/notifiers/ai_report_notifier.dart
git commit -m "feat(ai): add admin report notifier with 5-minute caching"
```

---

## Self-Review Checklist

- [ ] All Edge Functions include CORS headers
- [ ] All Edge Functions verify JWT
- [ ] All Edge Functions check rate limits
- [ ] Image analysis validates enum values (category, department, severity)
- [ ] Flutter uses AsyncNotifier for user-triggered actions (not FutureProvider)
- [ ] Chat history clears on logout
- [ ] Minimum 300ms shimmer for AI responses
- [ ] Error messages are contextual
- [ ] All AI models defined in Edge Functions, not Flutter

---

## Implementation Order

1. **Merge `ai/db-migration`** → Creates rate limits table
2. **Merge `ai/edge-functions-shared`** → Shared utilities
3. **Merge all edge function branches** → Can be done in parallel after shared
4. **Merge `ai/flutter-ai-service`** → Models + service
5. **Merge `ai/flutter-ai-ui`** → UI integration
