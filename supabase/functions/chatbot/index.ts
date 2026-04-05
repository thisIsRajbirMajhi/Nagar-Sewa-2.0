// supabase/functions/chatbot/index.ts
// @ts-ignore
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
// @ts-ignore
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { handleCors, jsonResponse, errorResponse } from '../_shared/cors.ts';
import { verifyAuth } from '../_shared/auth.ts';
import { checkRateLimit, recordRequest, rateLimitResponse } from '../_shared/rate_limit.ts';

declare const Deno: any;

const GROQ_API_URL = 'https://api.groq.com/openai/v1/chat/completions';
const CHAT_MODEL = Deno.env.get('GROQ_MODEL_CHAT') ?? 'openai/gpt-oss-120b';

interface ChatMessage {
  role: 'user' | 'assistant' | 'system' | 'tool';
  content: string | null;
  tool_calls?: any[];
  tool_call_id?: string;
}

interface ChatRequest {
  message: string;
  history: ChatMessage[];
  locale: string;
  user_location?: { lat: number; lng: number };
}

const TOOLS = [
  {
    type: 'function',
    function: {
      name: 'get_my_complaints',
      description: 'Fetch all civic issues/complaints reported by the current user to track their status.',
      parameters: { type: 'object', properties: {} }
    }
  },
  {
    type: 'function',
    function: {
      name: 'get_nearby_complaints',
      description: 'Fetch civic issues reported near the user\'s current location.',
      parameters: {
        type: 'object',
        properties: {
          radius_km: { type: 'number', default: 5, description: 'Radius in kilometers to search.' }
        }
      }
    }
  },
  {
    type: 'function',
    function: {
      name: 'get_departments',
      description: 'Get a list of all civic departments and their contact information.',
      parameters: { type: 'object', properties: {} }
    }
  }
];

function buildSystemPrompt(locale: string, location?: { lat: number, lng: number }): string {
  const isOdiaLocale = locale?.startsWith('or') ?? false;
  const locationContext = location 
    ? `The user is currently at coordinates: Lat ${location.lat}, Lng ${location.lng}. Use this to help them with location-specific queries.`
    : 'User location is not available.';

  return `You are "Sewa Sathi", an advanced AI assistant for NagarSewa, Odisha\'s premier civic issue reporting platform.

CORE CAPABILITIES:
- You help citizens report issues (road, water, electricity, sanitation, etc.).
- You can track the status of current complaints using the "get_my_complaints" tool.
- You can find nearby issues using the "get_nearby_complaints" tool.
- You can provide department contact info using the "get_departments" tool.

LOCATION CONTEXT:
${locationContext}

BEHAVIORAL GUIDELINES:
- Be professional, empathetic, and efficient.
- If the user asks about their complaints, ALWAYS use "get_my_complaints".
- If the user asks about issues in their area, use "get_nearby_complaints".
- Always respond in the language the user is using. Current locale: ${locale}.
- If you call a tool, summarize the findings for the user in a helpful way.
- Use Markdown for formatting (bolding, lists).`;
}

async function handleToolCall(name: string, args: any, userId: string, supabase: any, userLocation?: { lat: number, lng: number }) {
  console.log(`[ToolCall] Calling ${name} with args:`, args);
  
  if (name === 'get_my_complaints') {
    const { data, error } = await supabase
      .from('issues')
      .select('*')
      .eq('reporter_id', userId)
      .order('created_at', { ascending: false });
    
    if (error) return `Error fetching complaints: ${error.message}`;
    return JSON.stringify(data || []);
  }

  if (name === 'get_nearby_complaints') {
    if (!userLocation) return 'Location not provided. Please enable location services to find nearby issues.';
    
    const radiusStr = (args.radius_km || 5).toString();
    // Use PostGIS st_dwithin for efficiency if possible
    const { data, error } = await supabase
      .rpc('get_issues_nearby', {
        user_lat: userLocation.lat,
        user_lng: userLocation.lng,
        radius_km: parseFloat(radiusStr)
      });
    
    // Fallback if RPC doesn't exist (this is likely the case initially)
    if (error) {
      console.warn('RPC get_issues_nearby failed, falling back to basic query:', error.message);
      const { data: fallbackData } = await supabase
        .from('issues')
        .select('*')
        .limit(10); // Basic fallback for demo
      return JSON.stringify(fallbackData || []);
    }
    return JSON.stringify(data || []);
  }

  if (name === 'get_departments') {
    const { data, error } = await supabase
      .from('departments')
      .select('*')
      .order('name');
    
    if (error) return `Error fetching departments: ${error.message}`;
    return JSON.stringify(data || []);
  }

  return 'Tool not found.';
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

    const rateLimitResult = await checkRateLimit(user.id!, 'chatbot', supabaseClient);
    if (!rateLimitResult.allowed) {
      return rateLimitResponse(rateLimitResult.remaining ?? 0);
    }

    const { message, history = [], locale = 'en', user_location } = await req.json() as ChatRequest;

    if (!message || typeof message !== 'string') {
      return errorResponse('invalid_payload: message is required', 400);
    }

    await recordRequest(user.id!, 'chatbot', supabaseClient);

    const systemPrompt = buildSystemPrompt(locale, user_location);
    
    let messages: any[] = [
      { role: 'system', content: systemPrompt },
      ...history.slice(-10),
      { role: 'user', content: message }
    ];

    // 1. Initial Groq request (Check for Initial Tool Calls)
    const initialResponse = await fetch(GROQ_API_URL, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${Deno.env.get('GROQ_API_KEY')!}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: CHAT_MODEL,
        messages,
        tools: TOOLS,
        tool_choice: 'auto',
        temperature: 0.5,
      }),
    });

    if (!initialResponse.ok) {
      const errorText = await initialResponse.text();
      console.error('Groq API error (Initial):', errorText);
      return errorResponse('groq_error', 500);
    }

    const initialData = await initialResponse.json();
    const assistantMessage = initialData.choices?.[0]?.message;

    if (assistantMessage?.tool_calls) {
      messages.push(assistantMessage);
      
      for (const toolCall of assistantMessage.tool_calls) {
        const result = await handleToolCall(
          toolCall.function.name, 
          JSON.parse(toolCall.function.arguments),
          user.id,
          supabaseClient,
          user_location
        );
        messages.push({
          role: 'tool',
          tool_call_id: toolCall.id,
          content: result
        });
      }
    } else {
      // If no tool calls, we can just use the initial response content or proceed to stream
      // To keep it simple and consistent with streaming, we'll just push the assistant message if it has content
      // But actually, we want to STREAM the final answer.
    }

    // 2. Final Groq request with STREAMING
    const groqResponse = await fetch(GROQ_API_URL, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${Deno.env.get('GROQ_API_KEY')!}`,
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
      console.error('Groq API error (Stream):', errorText);
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
