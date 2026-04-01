-- Create ai_rate_limits table for rate limiting
create table ai_rate_limits (
  id          bigserial primary key,
  user_id     uuid not null references auth.users(id) on delete cascade,
  feature     text not null,  -- 'analyze_image' | 'chatbot' | 'draft_response' | 'generate_report'
  created_at  timestamptz not null default now()
);

-- Index for fast per-user + per-feature time-window queries
create index idx_rate_limits_user_feature_time
  on ai_rate_limits (user_id, feature, created_at desc);

-- RLS: users cannot read/write this table directly
alter table ai_rate_limits enable row level security;

-- Only service_role (used inside Edge Functions) can insert/select
create policy "Service role can manage rate limits"
  on ai_rate_limits
  for all
  using (auth.role() = 'service_role')
  with check (auth.role() = 'service_role');

-- Schedule cleanup job to delete old rate limit records
select cron.schedule(
  'cleanup-rate-limits',
  '* * * * *',  -- every minute
  $$delete from ai_rate_limits where created_at < now() - interval '2 minutes'$$
);
