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
