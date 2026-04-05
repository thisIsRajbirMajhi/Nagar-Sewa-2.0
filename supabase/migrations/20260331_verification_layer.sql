-- Verification Layer Migration
-- Date: 2026-03-31

ALTER TABLE issues 
ADD COLUMN IF NOT EXISTS verification_confidence TEXT DEFAULT 'high',
ADD COLUMN IF NOT EXISTS verification_flags JSONB DEFAULT '[]'::jsonb,
ADD COLUMN IF NOT EXISTS exif_gps_lat FLOAT,
ADD COLUMN IF NOT EXISTS exif_gps_lng FLOAT,
ADD COLUMN IF NOT EXISTS exif_timestamp TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS capture_device TEXT,
ADD COLUMN IF NOT EXISTS is_delayed_submission BOOLEAN DEFAULT false,
ADD COLUMN IF NOT EXISTS admin_reviewed BOOLEAN DEFAULT false,
ADD COLUMN IF NOT EXISTS admin_approved BOOLEAN;

CREATE TABLE IF NOT EXISTS verification_queue (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  issue_id UUID REFERENCES issues(id) ON DELETE CASCADE,
  confidence TEXT NOT NULL,
  flags JSONB NOT NULL,
  photo_score FLOAT,
  video_score FLOAT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  reviewed_at TIMESTAMPTZ,
  reviewed_by UUID REFERENCES auth.users(id),
  approved BOOLEAN,
  review_notes TEXT
);

ALTER TABLE verification_queue ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view verification_queue" ON verification_queue;
DROP POLICY IF EXISTS "Users can insert into verification_queue" ON verification_queue;
DROP POLICY IF EXISTS "Users can update verification_queue" ON verification_queue;
DROP POLICY IF EXISTS "Admins can manage verification_queue" ON verification_queue;
DROP POLICY IF EXISTS "Users can view own verification_queue" ON verification_queue;

CREATE POLICY "Admins can manage verification_queue" ON verification_queue
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role IN ('admin', 'officer')
    )
  );

CREATE POLICY "Users can view own verification_queue" ON verification_queue
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM issues
      WHERE issues.id = verification_queue.issue_id
      AND issues.reporter_id = auth.uid()
    )
  );

CREATE INDEX IF NOT EXISTS idx_verification_queue_unreviewed 
  ON verification_queue(created_at) 
  WHERE reviewed_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_issues_verification_confidence 
  ON issues(verification_confidence) 
  WHERE verification_confidence = 'low';

CREATE OR REPLACE FUNCTION add_to_verification_queue()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.verification_confidence = 'low' THEN
    INSERT INTO verification_queue (issue_id, confidence, flags, photo_score, video_score)
    VALUES (NEW.id, NEW.verification_confidence, NEW.verification_flags, NULL, NULL);
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_add_to_verification_queue ON issues;
CREATE TRIGGER trigger_add_to_verification_queue
  AFTER INSERT ON issues
  FOR EACH ROW
  EXECUTE FUNCTION add_to_verification_queue();

-- RPC: toggle_upvote
CREATE OR REPLACE FUNCTION toggle_upvote(p_issue_id UUID, p_user_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_exists BOOLEAN;
  v_count INT;
BEGIN
  SELECT EXISTS(SELECT 1 FROM upvotes WHERE issue_id = p_issue_id AND user_id = p_user_id) INTO v_exists;
  
  IF v_exists THEN
    DELETE FROM upvotes WHERE issue_id = p_issue_id AND user_id = p_user_id;
  ELSE
    DELETE FROM downvotes WHERE issue_id = p_issue_id AND user_id = p_user_id;
    INSERT INTO upvotes (issue_id, user_id) VALUES (p_issue_id, p_user_id) ON CONFLICT DO NOTHING;
  END IF;
  
  SELECT upvote_count INTO v_count FROM issues WHERE id = p_issue_id;
  RETURN jsonb_build_object('upvoted', NOT v_exists, 'count', v_count);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- RPC: toggle_downvote
CREATE OR REPLACE FUNCTION toggle_downvote(p_issue_id UUID, p_user_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_exists BOOLEAN;
  v_count INT;
BEGIN
  SELECT EXISTS(SELECT 1 FROM downvotes WHERE issue_id = p_issue_id AND user_id = p_user_id) INTO v_exists;
  
  IF v_exists THEN
    DELETE FROM downvotes WHERE issue_id = p_issue_id AND user_id = p_user_id;
  ELSE
    DELETE FROM upvotes WHERE issue_id = p_issue_id AND user_id = p_user_id;
    INSERT INTO downvotes (issue_id, user_id) VALUES (p_issue_id, p_user_id) ON CONFLICT DO NOTHING;
  END IF;
  
  SELECT downvote_count INTO v_count FROM issues WHERE id = p_issue_id;
  RETURN jsonb_build_object('downvoted', NOT v_exists, 'count', v_count);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- RPC: get_dashboard_stats
CREATE OR REPLACE FUNCTION get_dashboard_stats(p_user_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_resolved INT;
  v_urgent INT;
  v_reported INT;
  v_nearby INT;
BEGIN
  SELECT COUNT(*) INTO v_resolved FROM issues WHERE reporter_id = p_user_id AND status IN ('resolved', 'citizen_confirmed', 'closed');
  SELECT COUNT(*) INTO v_urgent FROM issues WHERE severity IN ('high', 'critical') AND status NOT IN ('resolved', 'citizen_confirmed', 'closed');
  SELECT COUNT(*) INTO v_reported FROM issues WHERE reporter_id = p_user_id;
  SELECT COUNT(*) INTO v_nearby FROM issues WHERE is_draft = false;
  
  RETURN jsonb_build_object(
    'resolved', v_resolved,
    'urgent', v_urgent,
    'reported', v_reported,
    'nearby', v_nearby
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- RPC: mark_all_notifications_read
CREATE OR REPLACE FUNCTION mark_all_notifications_read(p_user_id UUID)
RETURNS VOID AS $$
BEGIN
  UPDATE notifications SET is_read = true WHERE user_id = p_user_id AND is_read = false;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
