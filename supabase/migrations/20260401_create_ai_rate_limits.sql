-- Create ai_rate_limits table for rate limiting
create table if not exists ai_rate_limits (
  id          bigserial primary key,
  user_id     uuid not null references auth.users(id) on delete cascade,
  feature     text not null,  -- 'analyze_image' | 'chatbot' | 'draft_response' | 'generate_report'
  created_at  timestamptz not null default now()
);

-- Index for fast per-user + per-feature time-window queries
create index if not exists idx_rate_limits_user_feature_time
  on ai_rate_limits (user_id, feature, created_at desc);

-- RLS: users cannot read/write this table directly
alter table ai_rate_limits enable row level security;

-- Only service_role (used inside Edge Functions) can insert/select
do $$ begin
  if not exists (
    select 1 from pg_policies 
    where tablename = 'ai_rate_limits' 
    and policyname = 'Service role can manage rate limits'
  ) then
    create policy "Service role can manage rate limits"
      on ai_rate_limits
      for all
      using (auth.role() = 'service_role')
      with check (auth.role() = 'service_role');
  end if;
end $$;

-- Schedule cleanup job to delete old rate limit records
select cron.unschedule('cleanup-rate-limits');
select cron.schedule(
  'cleanup-rate-limits',
  '* * * * *',  -- every minute
  $sql$delete from ai_rate_limits where created_at < now() - interval '2 minutes'$sql$
);
