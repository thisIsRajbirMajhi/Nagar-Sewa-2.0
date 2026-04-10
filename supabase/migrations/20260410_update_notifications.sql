ALTER TABLE notifications 
ADD COLUMN IF NOT EXISTS group_key text,
ADD COLUMN IF NOT EXISTS action_url text,
ADD COLUMN IF NOT EXISTS metadata jsonb DEFAULT '{}'::jsonb,
ADD COLUMN IF NOT EXISTS priority text DEFAULT 'normal';

CREATE INDEX IF NOT EXISTS idx_notifications_group_key ON notifications(group_key);
