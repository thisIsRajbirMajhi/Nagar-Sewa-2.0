// @ts-ignore
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { handleCors, jsonResponse, errorResponse } from '../_shared/cors.ts';
import { verifyAuth } from '../_shared/auth.ts';
import { checkRateLimit, recordRequest, rateLimitResponse } from '../_shared/rate_limit.ts';

declare const Deno: any;

const GROQ_API_URL = 'https://api.groq.com/openai/v1/chat/completions';
const DRAFT_MODEL = Deno.env.get('GROQ_MODEL_DRAFT') ?? 'openai/gpt-oss-20b';

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

serve(async (req: Request) => {
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  try {
    const authResult = await verifyAuth(req);
    if ('error' in authResult) {
      return errorResponse(authResult.error!, authResult.status!);
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
        'Authorization': `Bearer ${Deno.env.get('GROQ_API_KEY')!}`,
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
