import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

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
