// supabase/functions/orchestrate-report/index.ts
// @ts-ignore
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { handleCors, jsonResponse, errorResponse } from '../_shared/cors.ts';
import { verifyAuth } from '../_shared/auth.ts';
import { checkRateLimit, recordRequest, rateLimitResponse } from '../_shared/rate_limit.ts';

declare const Deno: any;

const GROQ_API_URL = 'https://api.groq.com/openai/v1/chat/completions';
const GROQ_AUDIO_URL = 'https://api.groq.com/openai/v1/audio/transcriptions';
const VISION_MODEL = Deno.env.get('GROQ_MODEL_VISION') ?? 'meta-llama/llama-4-scout-17b-16e-instruct';
const ORCHESTRATOR_MODEL = Deno.env.get('GROQ_MODEL_ORCHESTRATOR') ?? 'openai/gpt-oss-120b';
const WHISPER_MODEL = Deno.env.get('GROQ_MODEL_WHISPER') ?? 'whisper-large-v3-turbo';

const VALID_CATEGORIES = [
  'pothole', 'garbage_overflow', 'broken_streetlight', 'sewage_leak',
  'encroachment', 'damaged_road_divider', 'broken_footpath', 'open_manhole',
  'waterlogging', 'construction_debris', 'illegal_dumping', 'traffic_signal_issue',
  'road_crack', 'drainage_blockage', 'other'
];
const VALID_SEVERITIES = ['low', 'medium', 'high'];
const VALID_DEPARTMENTS = [
  'works_department', 'water_resources_department', 'housing_urban_development',
  'rural_development_department', 'energy_department', 'school_mass_education',
  'health_family_welfare', 'agriculture_farmers_empowerment', 'forest_environment',
  'revenue_disaster_management', 'commerce_transport', 'steel_mines_department',
  'tourism_culture', 'women_child_development', 'panchayati_raj', 'other_department'
];

interface OrchestrateRequest {
  imageBase64: string;
  audioBase64?: string;
  userText?: string;
  latitude?: number;
  longitude?: number;
  locale: string;
}

async function transcribeAudio(audioBase64: string): Promise<{ text: string; warning?: string }> {
  try {
    const audioBytes = Uint8Array.from(atob(audioBase64), c => c.charCodeAt(0));
    const blob = new Blob([audioBytes], { type: 'audio/webm' });
    const formData = new FormData();
    formData.append('file', blob, 'audio.webm');
    formData.append('model', WHISPER_MODEL);

    const response = await fetch(GROQ_AUDIO_URL, {
      method: 'POST',
      headers: { 'Authorization': `Bearer ${Deno.env.get('GROQ_API_KEY')!}` },
      body: formData,
    });

    if (!response.ok) {
      return { text: '', warning: 'voice_transcription_failed' };
    }

    const data = await response.json();
    return { text: data.text || '' };
  } catch {
    return { text: '', warning: 'voice_transcription_failed' };
  }
}

async function analyzeImage(imageBase64: string): Promise<{ vision: any; warning?: string }> {
  try {
    const response = await fetch(GROQ_API_URL, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${Deno.env.get('GROQ_API_KEY')!}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: VISION_MODEL,
        messages: [
          {
            role: 'system',
            content: `You are a civic infrastructure analysis AI for NagarSewa, Odisha, India.
Analyze this image for civic issues. Return a valid JSON object:
{
  "scene_description": "Detailed description of what you see (max 300 chars)",
  "primary_issue": "The most prominent civic issue visible",
  "secondary_issues": ["array of additional issues detected, empty if none"],
  "severity_cues": "Description of factors affecting severity (size, location, danger)",
  "extracted_text": ["all visible text: signs, boards, shop names, street names"],
  "landmarks": ["visible landmarks, buildings, notable features"],
  "image_quality": "high | medium | low",
  "confidence_estimate": 0.0 to 1.0
}
All fields must be present. Use empty arrays if nothing detected.`
          },
          {
            role: 'user',
            content: [
              { type: 'text', text: 'Analyze this image for civic infrastructure issues.' },
              { type: 'image_url', image_url: { url: `data:image/jpeg;base64,${imageBase64}` } }
            ]
          }
        ],
        temperature: 0.3,
        response_format: { type: 'json_object' },
      }),
    });

    if (!response.ok) {
      return { vision: null, warning: 'image_analysis_failed' };
    }

    const data = await response.json();
    const content = data.choices?.[0]?.message?.content;
    if (!content) return { vision: null, warning: 'image_analysis_failed' };

    return { vision: JSON.parse(content) };
  } catch {
    return { vision: null, warning: 'image_analysis_failed' };
  }
}

async function orchestrate(
  visionResult: any,
  transcribedText: string,
  userText: string | undefined,
  latitude: number | undefined,
  longitude: number | undefined,
  locale: string,
): Promise<any> {
  const locationContext = (latitude && longitude)
    ? `GPS: ${latitude.toFixed(6)}, ${longitude.toFixed(6)}`
    : 'GPS not available.';

  const languageInstruction = locale?.startsWith('or')
    ? 'Return the "description" field in Odia script. All enum fields (category, severity) MUST be in English.'
    : locale?.startsWith('hi')
    ? 'Return the "description" field in Hindi. All enum fields (category, severity) MUST be in English.'
    : 'Return the "description" field in English. All enum fields (category, severity) MUST be in English.';

  const response = await fetch(GROQ_API_URL, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${Deno.env.get('GROQ_API_KEY')!}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model: ORCHESTRATOR_MODEL,
      messages: [
        {
          role: 'system',
          content: `You are the AI classification engine for NagarSewa, a civic issue reporting platform in Odisha, India.

Combine the following inputs and produce a structured classification:
- Vision analysis from image
- Voice transcription (if available)
- Citizen's text description (if available)
- GPS coordinates (if available)

Return ONLY a valid JSON object with these exact fields:
{
  "category": "One of: ${VALID_CATEGORIES.join(' | ')}",
  "confidence": 0.0 to 1.0,
  "description": "Clear, professional description of the issue (max 500 chars)",
  "severity": "${VALID_SEVERITIES.join(' | ')}",
  "location_hint": "Location description extracted from image text, landmarks, and GPS",
  "tags": ["relevant tags like road_damage, traffic_risk, health_hazard, etc."],
  "requires_immediate_action": true/false,
  "secondary_issues": ["additional issues detected, empty if none"],
  "extracted_text": ["text found in image, empty if none"],
  "vision_summary": "Brief scene description (max 200 chars)",
  "suggested_department": "One of: ${VALID_DEPARTMENTS.join(' | ')}",
  "department_confidence": 0.0 to 1.0,
  "warnings": ["quality warnings, e.g. image_quality_low, multiple_issues_detected"]
}

Rules:
- Category MUST be one of the listed values
- Confidence: 0.9+ = very clear evidence, 0.7-0.9 = likely, 0.5-0.7 = uncertain, <0.5 = unclear
- Severity: high = immediate safety risk, medium = affects daily life, low = cosmetic/minor
- requires_immediate_action: true only if severity is high
- location_hint: combine GPS context with any text/landmarks from image
- If no civic issue is detectable, set category to "other" and add "no_civic_issue_detected" to warnings
${languageInstruction}`
        },
        {
          role: 'user',
          content: `Vision Analysis: ${JSON.stringify(visionResult)}
Transcribed Voice: ${transcribedText || '(none)'}
Citizen Text: ${userText || '(none)'}
Location: ${locationContext}

Classify this civic issue and return structured JSON.`
        }
      ],
      temperature: 0.3,
      response_format: { type: 'json_object' },
    }),
  });

  if (!response.ok) {
    throw new Error('orchestrator_failed');
  }

  const data = await response.json();
  const content = data.choices?.[0]?.message?.content;
  if (!content) throw new Error('orchestrator_no_response');

  return JSON.parse(content);
}

function getConfidenceTier(confidence: number): string {
  if (confidence >= 0.9) return 'very_clear';
  if (confidence >= 0.7) return 'likely';
  if (confidence >= 0.5) return 'uncertain';
  return 'unclear';
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

    const rateLimitResult = await checkRateLimit(user.id!, 'orchestrate_report', supabaseClient);
    if (!rateLimitResult.allowed) {
      return rateLimitResponse(rateLimitResult.remaining ?? 0);
    }

    const { imageBase64, audioBase64, userText, latitude, longitude, locale } =
      await req.json() as OrchestrateRequest;

    if (!imageBase64 || typeof imageBase64 !== 'string') {
      return errorResponse('invalid_payload: imageBase64 is required', 400);
    }

    await recordRequest(user.id!, 'orchestrate_report', supabaseClient);

    const warnings: string[] = [];

    // Step 1: Voice transcription (optional)
    let transcribedText = '';
    if (audioBase64) {
      const audioResult = await transcribeAudio(audioBase64);
      transcribedText = audioResult.text;
      if (audioResult.warning) warnings.push(audioResult.warning);
    }

    // Step 2: Image analysis
    const imageResult = await analyzeImage(imageBase64);
    if (imageResult.warning) warnings.push(imageResult.warning);

    // Step 3: Orchestration
    let result = await orchestrate(
      imageResult.vision,
      transcribedText,
      userText,
      latitude,
      longitude,
      locale || 'en',
    );

    // Validate and sanitize output
    if (!VALID_CATEGORIES.includes(result.category)) {
      result.category = 'other';
    }
    if (!VALID_SEVERITIES.includes(result.severity)) {
      result.severity = 'medium';
    }
    if (!VALID_DEPARTMENTS.includes(result.suggested_department)) {
      result.suggested_department = 'other_department';
    }

    result.confidence = Math.max(0, Math.min(1, result.confidence ?? 0.5));
    result.confidence_tier = getConfidenceTier(result.confidence);
    result.requires_immediate_action = result.severity === 'high';
    result.secondary_issues = Array.isArray(result.secondary_issues) ? result.secondary_issues : [];
    result.extracted_text = Array.isArray(result.extracted_text) ? result.extracted_text : [];
    result.tags = Array.isArray(result.tags) ? result.tags : [];
    result.warnings = [...(Array.isArray(result.warnings) ? result.warnings : []), ...warnings];

    return jsonResponse(result);
  } catch (error: any) {
    console.error('[orchestrate-report] error:', error);
    if (error.message === 'json_parse_fail' || error.message === 'orchestrator_failed') {
      return errorResponse('orchestration_failed', 500);
    }
    return errorResponse('internal_error', 500);
  }
});
