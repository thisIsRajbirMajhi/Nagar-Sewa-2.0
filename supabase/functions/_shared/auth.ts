// @ts-ignore
import { createClient, User, SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2';

declare const Deno: any;

export type AuthResult = 
  | { user: User; supabaseClient: SupabaseClient; error?: never; status?: never }
  | { error: string; status: number; user?: never; supabaseClient?: never };

export async function verifyAuth(req: Request): Promise<AuthResult> {
  const authHeader = req.headers.get('Authorization');
  if (!authHeader) {
    console.error('[verifyAuth] No Authorization header present');
    return { error: 'unauthorized: missing_header', status: 401 };
  }

  const token = authHeader.replace('Bearer ', '');
  if (!token || token === 'undefined' || token === 'null') {
    console.error('[verifyAuth] Invalid token format or empty token');
    return { error: 'unauthorized: invalid_token_format', status: 401 };
  }

  // Debug: Log first 10 and last 10 chars of token
  console.log(`[verifyAuth] Received token: ${token.substring(0, 10)}...${token.substring(token.length - 10)} (Length: ${token.length})`);

  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');

  if (!supabaseUrl || !supabaseServiceKey) {
    console.error('[verifyAuth] Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY environment variables');
    return { error: 'configuration_error', status: 500 };
  }

  const supabaseClient = createClient(supabaseUrl, supabaseServiceKey);

  try {
    const { data, error } = await supabaseClient.auth.getUser(token);

    if (error) {
      console.error('[verifyAuth] supabase.auth.getUser error:', error.message, error.status, error.code);
      return { error: `unauthorized: ${error.message} (code: ${error.code}, status: ${error.status})`, status: 401 };
    }

    if (!data.user) {
      console.error('[verifyAuth] No user returned from auth.getUser');
      return { error: 'unauthorized: user_not_found', status: 401 };
    }

    console.log(`[verifyAuth] Authenticated as user: ${data.user.id} (${data.user.email ?? 'no email'})`);
    return { user: data.user, supabaseClient };
  } catch (err) {
    console.error('[verifyAuth] Unexpected error during authentication:', err);
    return { error: 'auth_internal_error', status: 500 };
  }
}
