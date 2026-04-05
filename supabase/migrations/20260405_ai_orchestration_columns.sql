-- Migration: Add AI orchestration metadata columns to issues table
-- Date: 2026-04-05

ALTER TABLE issues ADD COLUMN IF NOT EXISTS ai_confidence FLOAT;
ALTER TABLE issues ADD COLUMN IF NOT EXISTS ai_confidence_tier TEXT;
ALTER TABLE issues ADD COLUMN IF NOT EXISTS ai_secondary_issues JSONB DEFAULT '[]'::jsonb;
ALTER TABLE issues ADD COLUMN IF NOT EXISTS ai_location_hint TEXT;
ALTER TABLE issues ADD COLUMN IF NOT EXISTS ai_vision_summary TEXT;
ALTER TABLE issues ADD COLUMN IF NOT EXISTS ai_extracted_text JSONB DEFAULT '[]'::jsonb;
ALTER TABLE issues ADD COLUMN IF NOT EXISTS ai_warnings JSONB DEFAULT '[]'::jsonb;

-- Add index for confidence-based queries
CREATE INDEX IF NOT EXISTS idx_issues_ai_confidence ON issues(ai_confidence DESC);
CREATE INDEX IF NOT EXISTS idx_issues_ai_confidence_tier ON issues(ai_confidence_tier);
