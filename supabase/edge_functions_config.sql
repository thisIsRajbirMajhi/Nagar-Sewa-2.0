-- ============================================================================
-- NagarSewa Edge Functions Configuration
-- ============================================================================

-- ============================================================================
-- Function: verify-media
-- Purpose: Server-side verification of media metadata
-- Deploy: supabase/functions/verify-media/index.ts
-- ============================================================================

/*
Deno TypeScript code for verify-media edge function:

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface VerificationRequest {
  issueId: string
  exifGpsLat?: number
  exifGpsLng?: number
  exifTimestamp?: string
  userGpsLat: number
  userGpsLng: number
  submissionTime: string
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    )

    const { issueId, exifGpsLat, exifGpsLng, exifTimestamp, userGpsLat, userGpsLng, submissionTime } 
      = await req.json() as VerificationRequest

    const flags: string[] = []
    let serverConfidence = 'high'

    if (exifGpsLat && exifGpsLng) {
      const distance = calculateDistance(userGpsLat, userGpsLng, exifGpsLat, exifGpsLng)
      
      if (distance > 2000) {
        flags.push('server_gps_mismatch_high')
        serverConfidence = 'low'
      } else if (distance > 500) {
        flags.push('server_gps_mismatch')
        if (serverConfidence !== 'low') serverConfidence = 'medium'
      }
    }

    if (exifTimestamp) {
      const captureTime = new Date(exifTimestamp)
      const submitTime = new Date(submissionTime)
      const hoursDiff = Math.abs(submitTime.getTime() - captureTime.getTime()) / 36e5

      if (hoursDiff > 4) {
        flags.push('server_timestamp_suspicious')
        serverConfidence = 'low'
      }
    }

    await supabaseClient
      .from('issues')
      .update({
        verification_confidence: serverConfidence,
        verification_flags: flags,
      })
      .eq('id', issueId)

    if (serverConfidence === 'low') {
      const { data: existing } = await supabaseClient
        .from('verification_queue')
        .select('id')
        .eq('issue_id', issueId)
        .maybeSingle()

      if (!existing) {
        await supabaseClient.from('verification_queue').insert({
          issue_id: issueId,
          confidence: serverConfidence,
          flags: flags,
        })
      }
    }

    return new Response(
      JSON.stringify({ confidence: serverConfidence, flags }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }
})

function calculateDistance(lat1: number, lng1: number, lat2: number, lng2: number): number {
  const R = 6371000
  const dLat = toRad(lat2 - lat1)
  const dLng = toRad(lng2 - lng1)
  const a = Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) *
    Math.sin(dLng / 2) ** 2
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
}

function toRad(deg: number): number {
  return deg * Math.PI / 180
}
*/

-- ============================================================================
-- SECTION 1: STORAGE BUCKETS (Alternative SQL approach)
-- ============================================================================

-- Enable storage extension if not already enabled
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create buckets using SQL (if not using dashboard)
-- Note: Some Supabase versions require dashboard for bucket creation

-- Bucket: issues
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'issues',
    'issues',
    true,
    52428800,  -- 50MB
    ARRAY['image/jpeg', 'image/png', 'image/gif', 'video/mp4', 'video/quicktime']
)
ON CONFLICT (id) DO NOTHING;

-- Bucket: avatars
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'avatars',
    'avatars',
    true,
    5242880,  -- 5MB
    ARRAY['image/jpeg', 'image/png', 'image/gif', 'image/webp']
)
ON CONFLICT (id) DO NOTHING;

-- ============================================================================
-- SECTION 2: STORAGE POLICIES
-- ============================================================================

-- Issues bucket policies
CREATE POLICY "Enable uploads for authenticated users" ON storage.objects
    FOR INSERT TO authenticated
    WITH CHECK (bucket_id = 'issues');

CREATE POLICY "Enable reads for everyone" ON storage.objects
    FOR SELECT TO public
    USING (bucket_id = 'issues');

CREATE POLICY "Enable updates for authenticated users" ON storage.objects
    FOR UPDATE TO authenticated
    USING (bucket_id = 'issues');

CREATE POLICY "Enable deletes for authenticated users" ON storage.objects
    FOR DELETE TO authenticated
    USING (bucket_id = 'issues');

-- Avatars bucket policies
CREATE POLICY "Enable uploads for authenticated users" ON storage.objects
    FOR INSERT TO authenticated
    WITH CHECK (bucket_id = 'avatars');

CREATE POLICY "Enable reads for everyone" ON storage.objects
    FOR SELECT TO public
    USING (bucket_id = 'avatars');

CREATE POLICY "Enable updates for authenticated users" ON storage.objects
    FOR UPDATE TO authenticated
    USING (bucket_id = 'avatars');

CREATE POLICY "Enable deletes for authenticated users" ON storage.objects
    FOR DELETE TO authenticated
    USING (bucket_id = 'avatars');

-- ============================================================================
-- SECTION 3: AUTHENTICATION CONFIGURATION
-- ============================================================================

-- Site URL (update for production)
-- Note: Set this in Supabase Dashboard > Authentication > URL Configuration
-- Site URL: io.supabase.nagarsewa://

-- Redirect URLs to configure:
-- - io.supabase.nagarsewa://login-callback/
-- - https://yourdomain.com/*

-- ============================================================================
-- SECTION 4: EMAIL TEMPLATES (Configure in Dashboard)
-- ============================================================================

-- Configure these email templates in Supabase Dashboard > Authentication > Email Templates:

-- 1. Confirm Signup Template
/*
Subject: Confirm your NagarSewa account

<p>Hey {{ .UserMetaData.full_name }},</p>
<p>Thanks for joining NagarSewa! Click the link below to confirm your account:</p>
<p><a href="{{ .ConfirmationURL }}">Confirm Account</a></p>
<p>This link expires in {{ .TokenLife }} minutes.</p>
*/

-- 2. Reset Password Template
/*
Subject: Reset your NagarSewa password

<p>Hey {{ .UserMetaData.full_name }},</p>
<p>Click the link below to reset your password:</p>
<p><a href="{{ .ConfirmationURL }}">Reset Password</a></p>
<p>This link expires in {{ .TokenLife }} minutes.</p>
<p>If you didn't request this, please ignore this email.</p>
*/

-- ============================================================================
-- SECTION 5: ROW LEVEL SECURITY FOR STORAGE
-- ============================================================================

-- Enhanced storage policies with user folder isolation
CREATE OR REPLACE FUNCTION storage.get_user_folder(user_id UUID)
RETURNS TEXT AS $$
BEGIN
    RETURN user_id::TEXT;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Issues bucket - users can only access their own files
CREATE POLICY "Users can only access their own issue files" ON storage.objects
    FOR SELECT USING (
        bucket_id = 'issues' AND
        (storage.foldername(name))[1] = auth.uid()::TEXT
    );

CREATE POLICY "Users can only upload to their own folder" ON storage.objects
    FOR INSERT TO authenticated
    WITH CHECK (
        bucket_id = 'issues' AND
        (storage.foldername(name))[1] = auth.uid()::TEXT
    );

CREATE POLICY "Users can only update their own files" ON storage.objects
    FOR UPDATE TO authenticated
    USING (
        bucket_id = 'issues' AND
        (storage.foldername(name))[1] = auth.uid()::TEXT
    );

CREATE POLICY "Users can only delete their own files" ON storage.objects
    FOR DELETE TO authenticated
    USING (
        bucket_id = 'issues' AND
        (storage.foldername(name))[1] = auth.uid()::TEXT
    );

-- Avatars bucket - users can only access their own avatar
CREATE POLICY "Users can only access their own avatar" ON storage.objects
    FOR SELECT USING (
        bucket_id = 'avatars' AND
        (storage.foldername(name))[1] = auth.uid()::TEXT
    );

CREATE POLICY "Users can only upload to their own avatar folder" ON storage.objects
    FOR INSERT TO authenticated
    WITH CHECK (
        bucket_id = 'avatars' AND
        (storage.foldername(name))[1] = auth.uid()::TEXT
    );

CREATE POLICY "Users can only update their own avatar" ON storage.objects
    FOR UPDATE TO authenticated
    USING (
        bucket_id = 'avatars' AND
        (storage.foldername(name))[1] = auth.uid()::TEXT
    );

CREATE POLICY "Users can only delete their own avatar" ON storage.objects
    FOR DELETE TO authenticated
    USING (
        bucket_id = 'avatars' AND
        (storage.foldername(name))[1] = auth.uid()::TEXT
    );

-- ============================================================================
-- SECTION 6: ADDITIONAL EDGE FUNCTION: send-notification
-- ============================================================================

/*
Deno code for send-notification edge function:

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    )

    const { userId, issueId, title, message, type } = await req.json()

    const { error } = await supabaseClient
      .from('notifications')
      .insert({
        user_id: userId,
        issue_id: issueId,
        title,
        message,
        type: type || 'info'
      })

    if (error) throw error

    return new Response(
      JSON.stringify({ success: true }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }
})
*/

-- ============================================================================
-- SECTION 7: CRON JOBS (Requires pg_cron extension)
-- ============================================================================

-- Note: Enable pg_cron extension in Supabase Dashboard > Database > Extensions

-- Example: Daily cleanup of old verification queue items (older than 90 days)
/*
SELECT cron.schedule(
    'cleanup-old-verification-queue',
    '0 3 * * *',
    $$
    DELETE FROM verification_queue 
    WHERE created_at < NOW() - INTERVAL '90 days' 
    AND reviewed_at IS NOT NULL;
    $$
);
*/

-- Example: Weekly update of civic scores
/*
SELECT cron.schedule(
    'update-civic-scores',
    '0 4 * * 0',
    $$
    UPDATE profiles p
    SET civic_score = (
        SELECT COALESCE(SUM(upvote_count), 0) + 
               (SELECT COUNT(*) * 10 FROM issues WHERE reporter_id = p.id AND status IN ('resolved', 'citizen_confirmed', 'closed'))
        FROM issues WHERE reporter_id = p.id
    );
    $$
);
*/

-- ============================================================================
-- END OF EDGE FUNCTIONS CONFIGURATION
-- ============================================================================
