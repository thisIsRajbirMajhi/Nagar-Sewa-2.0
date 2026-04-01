// supabase/functions/chatbot/index.ts
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { handleCors, errorResponse } from '../_shared/cors.ts';
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
      ...history.slice(-10),
      { role: 'user', content: message }
    ];

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
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
        'Content-Type': 'text/event-stream',
        'Cache-Control': 'no-cache',
        'Connection': 'keep-alive',
      },
    });
  } catch (error) {
    console.error('Chatbot error:', error);
    return errorResponse('internal_error', 500);
  }
});
