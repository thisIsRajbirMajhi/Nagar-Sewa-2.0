CREATE TABLE IF NOT EXISTS issue_comments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  issue_id uuid NOT NULL REFERENCES issues(id) ON DELETE CASCADE,
  author_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  content text NOT NULL CHECK (char_length(content) <= 500),
  created_at timestamptz DEFAULT now()
);

CREATE INDEX idx_issue_comments_issue_id ON issue_comments(issue_id);
CREATE INDEX idx_issue_comments_created_at ON issue_comments(created_at);

ALTER TABLE issue_comments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can read issue comments"
  ON issue_comments FOR SELECT
  USING (true);

CREATE POLICY "Authenticated users can create comments"
  ON issue_comments FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = author_id);

-- Trigger to notify on new comment
CREATE OR REPLACE FUNCTION notify_on_comment()
RETURNS TRIGGER AS $$
DECLARE
  v_issue_reporter uuid;
  v_commenter_role text;
  v_metadata jsonb;
BEGIN
  -- Get issue reporter
  SELECT reporter_id INTO v_issue_reporter FROM issues WHERE id = NEW.issue_id;
  
  -- Get commenter role and name
  SELECT role INTO v_commenter_role FROM profiles WHERE id = NEW.author_id;

  -- Only notify if commenter is NOT the reporter
  IF NEW.author_id != v_issue_reporter THEN
    v_metadata := jsonb_build_object(
      'comment_id', NEW.id,
      'commenter_id', NEW.author_id,
      'is_officer', (v_commenter_role = 'officer'),
      'text_preview', substring(NEW.content from 1 for 50)
    );

    INSERT INTO notifications (
      user_id,
      issue_id,
      type,
      title,
      message,
      metadata,
      group_key,
      priority
    ) VALUES (
      v_issue_reporter,
      NEW.issue_id,
      'comment',
      'New Comment',
      'Someone commented on your issue.',
      v_metadata,
      'comment_' || NEW.issue_id,
      'medium'
    );
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tr_notify_on_comment
AFTER INSERT ON issue_comments
FOR EACH ROW
EXECUTE FUNCTION notify_on_comment();
