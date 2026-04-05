-- Model Metrics Table for storing ML training results
CREATE TABLE IF NOT EXISTS model_metrics (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  accuracy FLOAT,
  precision FLOAT,
  recall FLOAT,
  f1_score FLOAT,
  confusion_matrix JSONB,
  training_history JSONB,
  epochs_trained INTEGER,
  final_val_accuracy FLOAT,
  final_val_loss FLOAT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE model_metrics ENABLE ROW LEVEL SECURITY;

-- Policy: authenticated users can view
do $$ begin
  if not exists (
    select 1 from pg_policies 
    where tablename = 'model_metrics' 
    and policyname = 'Users can view model_metrics'
  ) then
    create policy "Users can view model_metrics" on model_metrics
      for select using (auth.role() = 'authenticated');
  end if;
end $$;

-- Policy: service role can insert (for Python script)
do $$ begin
  if not exists (
    select 1 from pg_policies 
    where tablename = 'model_metrics' 
    and policyname = 'Service can insert model_metrics'
  ) then
    create policy "Service can insert model_metrics" on model_metrics
      for insert with check (auth.role() = 'service_role');
  end if;
end $$;
