import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
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

    if (!VALID_CATEGORIES.includes(analysis.category)) {
      analysis.category = 'other';
    }
    if (!VALID_DEPARTMENTS.includes(analysis.suggested_department)) {
      analysis.suggested_department = 'other_department';
    }
    if (!VALID_SEVERITIES.includes(analysis.severity)) {
      analysis.severity = 'medium';
    }

    analysis.extracted_text = Array.isArray(analysis.extracted_text) ? analysis.extracted_text : [];
    analysis.warnings = Array.isArray(analysis.warnings) ? analysis.warnings : [];

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
