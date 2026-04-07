-- Fix toggle_upvote to update issues table

CREATE OR REPLACE FUNCTION toggle_upvote(p_issue_id UUID, p_user_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_exists BOOLEAN;
  v_count INT;
BEGIN
  SELECT EXISTS(SELECT 1 FROM upvotes WHERE issue_id = p_issue_id AND user_id = p_user_id) INTO v_exists;
  
  IF v_exists THEN
    DELETE FROM upvotes WHERE issue_id = p_issue_id AND user_id = p_user_id;
    UPDATE issues SET upvote_count = GREATEST(upvote_count - 1, 0) WHERE id = p_issue_id;
  ELSE
    DELETE FROM downvotes WHERE issue_id = p_issue_id AND user_id = p_user_id;
    UPDATE issues SET downvote_count = GREATEST(downvote_count - 1, 0) WHERE id = p_issue_id;
    INSERT INTO upvotes (issue_id, user_id) VALUES (p_issue_id, p_user_id) ON CONFLICT DO NOTHING;
    UPDATE issues SET upvote_count = upvote_count + 1 WHERE id = p_issue_id;
  END IF;
  
  SELECT upvote_count INTO v_count FROM issues WHERE id = p_issue_id;
  RETURN jsonb_build_object('upvoted', NOT v_exists, 'count', v_count);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Fix toggle_downvote
CREATE OR REPLACE FUNCTION toggle_downvote(p_issue_id UUID, p_user_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_exists BOOLEAN;
  v_count INT;
BEGIN
  SELECT EXISTS(SELECT 1 FROM downvotes WHERE issue_id = p_issue_id AND user_id = p_user_id) INTO v_exists;
  
  IF v_exists THEN
    DELETE FROM downvotes WHERE issue_id = p_issue_id AND user_id = p_user_id;
    UPDATE issues SET downvote_count = GREATEST(downvote_count - 1, 0) WHERE id = p_issue_id;
  ELSE
    DELETE FROM upvotes WHERE issue_id = p_issue_id AND user_id = p_user_id;
    UPDATE issues SET upvote_count = GREATEST(upvote_count - 1, 0) WHERE id = p_issue_id;
    INSERT INTO downvotes (issue_id, user_id) VALUES (p_issue_id, p_user_id) ON CONFLICT DO NOTHING;
    UPDATE issues SET downvote_count = downvote_count + 1 WHERE id = p_issue_id;
  END IF;
  
  SELECT downvote_count INTO v_count FROM issues WHERE id = p_issue_id;
  RETURN jsonb_build_object('downvoted', NOT v_exists, 'count', v_count);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
