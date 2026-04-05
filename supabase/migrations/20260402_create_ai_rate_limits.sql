create table if not exists ai_rate_limits (
  id          bigserial primary key,
  user_id     uuid not null references auth.users(id) on delete cascade,
  feature     text not null,
  created_at  timestamptz not null default now()
);

create index if not exists idx_rate_limits_user_feature_time
  on ai_rate_limits (user_id, feature, created_at desc);

alter table ai_rate_limits enable row level security;

create or replace policy "Service role can manage rate limits"
  on ai_rate_limits
  for all
  using (auth.role() = 'service_role')
  with check (auth.role() = 'service_role');

select cron.unschedule('cleanup-rate-limits');
select cron.schedule(
  'cleanup-rate-limits',
  '* * * * *',
  $sql$delete from ai_rate_limits where created_at < now() - interval '2 minutes'$sql$
);
