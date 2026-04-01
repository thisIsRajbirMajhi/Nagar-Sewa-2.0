<<<<<<< HEAD
// supabase/functions/generate-report/index.ts
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
=======
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
>>>>>>> ai/edge-function-generate-report
import { handleCors, jsonResponse, errorResponse } from '../_shared/cors.ts';
import { verifyAuth } from '../_shared/auth.ts';
import { checkRateLimit, recordRequest, rateLimitResponse } from '../_shared/rate_limit.ts';

const GROQ_API_URL = 'https://api.groq.com/openai/v1/chat/completions';
const REPORT_MODEL = Deno.env.get('GROQ_MODEL_REPORT') ?? 'llama-3.3-70b-versatile';

interface ReportFilters {
  district?: string;
  department?: string;
  startDate?: string;
  endDate?: string;
  category?: string;
}

interface AggregatedData {
  totalIssues: number;
  byStatus: Record<string, number>;
  byCategory: Record<string, number>;
  bySeverity: Record<string, number>;
  byDepartment: Record<string, number>;
  recentTrend: { date: string; count: number }[];
}

interface ReportRequest {
  filters: ReportFilters;
}

function buildSystemPrompt(): string {
  return `You are a data analyst assistant for NagarSewa, Odisha's civic issue reporting platform.

You will receive pre-aggregated data about civic issues. Your task is to:
1. Analyze the data and identify key trends
2. Highlight notable patterns (high/low areas, trending categories, etc.)
3. Provide actionable insights in a readable prose format

Format your response as a clear, professional report with:
- Executive summary (2-3 sentences)
- Key findings (bullet points)
- Observations about trends
- Any notable outliers or concerns

Keep the analysis focused and avoid speculation beyond what the data shows.`;
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

    const rateLimitResult = await checkRateLimit(user.id, 'generate_report', supabaseClient);
    if (!rateLimitResult.allowed) {
      return rateLimitResponse(rateLimitResult.remaining ?? 0);
    }

    const { filters = {} } = await req.json() as ReportRequest;

    await recordRequest(user.id, 'generate_report', supabaseClient);

<<<<<<< HEAD
    // Build aggregation query
=======
>>>>>>> ai/edge-function-generate-report
    let query = supabaseClient
      .from('issues')
      .select('status, category, severity, department_id, created_at');

    if (filters.district) {
      query = query.eq('district', filters.district);
    }
<<<<<<< HEAD
    if (filters.department) {
      query = query.eq('department_id', filters.department);
    }
=======
>>>>>>> ai/edge-function-generate-report
    if (filters.category) {
      query = query.eq('category', filters.category);
    }
    if (filters.startDate) {
      query = query.gte('created_at', filters.startDate);
    }
    if (filters.endDate) {
      query = query.lte('created_at', filters.endDate);
    }

    const { data: issues, error: queryError } = await query;

    if (queryError) {
      console.error('Query error:', queryError);
      return errorResponse('database_error', 500);
    }

<<<<<<< HEAD
    // Aggregate data
=======
>>>>>>> ai/edge-function-generate-report
    const aggregated: AggregatedData = {
      totalIssues: issues?.length ?? 0,
      byStatus: {},
      byCategory: {},
      bySeverity: {},
      byDepartment: {},
      recentTrend: [],
    };

    for (const issue of issues ?? []) {
      aggregated.byStatus[issue.status] = (aggregated.byStatus[issue.status] ?? 0) + 1;
      aggregated.byCategory[issue.category] = (aggregated.byCategory[issue.category] ?? 0) + 1;
      aggregated.bySeverity[issue.severity] = (aggregated.bySeverity[issue.severity] ?? 0) + 1;
      if (issue.department_id) {
        aggregated.byDepartment[issue.department_id] = (aggregated.byDepartment[issue.department_id] ?? 0) + 1;
      }

      const date = issue.created_at.split('T')[0];
      const trendEntry = aggregated.recentTrend.find(t => t.date === date);
      if (trendEntry) {
        trendEntry.count++;
      } else {
        aggregated.recentTrend.push({ date, count: 1 });
      }
    }

<<<<<<< HEAD
    // Sort trend by date
    aggregated.recentTrend.sort((a, b) => a.date.localeCompare(b.date));

    // Generate report with LLM
=======
    aggregated.recentTrend.sort((a, b) => a.date.localeCompare(b.date));

>>>>>>> ai/edge-function-generate-report
    const systemPrompt = buildSystemPrompt();
    const userMessage = `Here is the aggregated issue data:

Total Issues: ${aggregated.totalIssues}

By Status:
${JSON.stringify(aggregated.byStatus, null, 2)}

By Category:
${JSON.stringify(aggregated.byCategory, null, 2)}

By Severity:
${JSON.stringify(aggregated.bySeverity, null, 2)}

${filters.district ? `District: ${filters.district}\n` : ''}${filters.category ? `Category Filter: ${filters.category}\n` : ''}${filters.startDate ? `From: ${filters.startDate}\n` : ''}${filters.endDate ? `To: ${filters.endDate}\n` : ''}

Please generate a summary report.`;

    const groqResponse = await fetch(GROQ_API_URL, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${Deno.env.get('GROQ_API_KEY')}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: REPORT_MODEL,
        messages: [
          { role: 'system', content: systemPrompt },
          { role: 'user', content: userMessage }
        ],
        temperature: 0.3,
      }),
    });

    if (!groqResponse.ok) {
      const errorText = await groqResponse.text();
      console.error('Groq API error:', errorText);
      return errorResponse('groq_error', 500);
    }

    const groqData = await groqResponse.json();
    const reportText = groqData.choices?.[0]?.message?.content;

    if (!reportText) {
      return errorResponse('no_response_from_llm', 500);
    }

    return jsonResponse({
      report: reportText.trim(),
      aggregated,
      generatedAt: new Date().toISOString(),
    });
  } catch (error) {
    console.error('Generate report error:', error);
    return errorResponse('internal_error', 500);
  }
});
