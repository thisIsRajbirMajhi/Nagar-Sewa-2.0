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
CREATE POLICY "Users can view model_metrics" ON model_metrics
  FOR SELECT USING (auth.role() = 'authenticated');

-- Policy: service role can insert (for Python script)
CREATE POLICY "Service can insert model_metrics" ON model_metrics
  FOR INSERT WITH CHECK (auth.role() = 'service_role');
