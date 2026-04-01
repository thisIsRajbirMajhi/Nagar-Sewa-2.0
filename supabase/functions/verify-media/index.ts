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
