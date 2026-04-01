-- ============================================================================
-- NagarSewa Complete Database Schema Backup
-- Generated: 2026-04-01
-- Description: Complete schema for civic accountability platform
-- ============================================================================

-- ============================================================================
-- SECTION 1: EXTENSIONS
-- ============================================================================
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "postgis";  -- For geospatial queries (optional)

-- ============================================================================
-- SECTION 2: CORE TABLES
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Table: profiles
-- Description: Extended user profiles linked to auth.users
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    full_name TEXT NOT NULL,
    phone TEXT,
    avatar_url TEXT,
    civic_score INTEGER DEFAULT 0,
    role TEXT DEFAULT 'citizen' CHECK (role IN ('citizen', 'officer', 'admin')),
    ward TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Trigger to auto-create profile on user signup
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO profiles (id, full_name)
    VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data->>'full_name', 'User')
    )
    ON CONFLICT (id) DO NOTHING;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- Trigger to update updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS update_profiles_updated_at ON profiles;
CREATE TRIGGER update_profiles_updated_at
    BEFORE UPDATE ON profiles
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ----------------------------------------------------------------------------
-- Table: departments
-- Description: Government departments responsible for issue categories
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS departments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    code TEXT UNIQUE NOT NULL,
    description TEXT,
    contact_email TEXT,
    contact_phone TEXT,
    geo_zones TEXT[] DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Seed initial departments
INSERT INTO departments (name, code, description, contact_email, contact_phone, geo_zones) VALUES
    ('Public Works Department', 'PWD', 'Roads, bridges, and infrastructure maintenance', 'pwd@nagarsewa.gov', '+91-1234567890', ARRAY['zone_1', 'zone_2', 'zone_3']),
    ('Sanitation Department', 'SAN', 'Waste management and street cleaning', 'sanitation@nagarsewa.gov', '+91-1234567891', ARRAY['zone_1', 'zone_2', 'zone_3']),
    ('Electrical Department', 'ELE', 'Streetlights and electrical infrastructure', 'electrical@nagarsewa.gov', '+91-1234567892', ARRAY['zone_1', 'zone_2', 'zone_3']),
    ('Water Supply', 'WAT', 'Water distribution and sewage', 'water@nagarsewa.gov', '+91-1234567893', ARRAY['zone_1', 'zone_2', 'zone_3']),
    ('Parks and Gardens', 'PAR', 'Public parks and green spaces', 'parks@nagarsewa.gov', '+91-1234567894', ARRAY['zone_1', 'zone_2']),
    ('Traffic Department', 'TRF', 'Traffic signals and road markings', 'traffic@nagarsewa.gov', '+91-1234567895', ARRAY['zone_1', 'zone_2', 'zone_3'])
ON CONFLICT (code) DO NOTHING;

-- ----------------------------------------------------------------------------
-- Table: issues
-- Description: Civic issue reports submitted by citizens
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS issues (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reporter_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
    department_id UUID REFERENCES departments(id) ON DELETE SET NULL,
    title TEXT NOT NULL,
    description TEXT,
    category TEXT NOT NULL CHECK (category IN (
        'pothole', 'garbage_overflow', 'broken_streetlight', 'sewage_leak',
        'waterlogging', 'damaged_road', 'open_manhole', 'illegal_dumping',
        'streetlight_outage', 'drainage_issue', 'other'
    )),
    severity TEXT DEFAULT 'medium' CHECK (severity IN ('low', 'medium', 'high', 'critical')),
    status TEXT DEFAULT 'submitted' CHECK (status IN (
        'submitted', 'verified', 'assigned', 'acknowledged',
        'in_progress', 'resolved', 'citizen_confirmed', 'closed', 'rejected'
    )),
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    address TEXT,
    photo_urls TEXT[] DEFAULT '{}',
    video_url TEXT,
    severity_score DOUBLE PRECISION,
    sla_deadline TIMESTAMPTZ,
    upvote_count INTEGER DEFAULT 0,
    downvote_count INTEGER DEFAULT 0,
    is_draft BOOLEAN DEFAULT FALSE,
    is_anonymous BOOLEAN DEFAULT FALSE,
    resolved_at TIMESTAMPTZ,
    resolution_proof_urls TEXT[] DEFAULT '{}',
    citizen_rating INTEGER CHECK (citizen_rating BETWEEN 1 AND 5),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Verification fields
    verification_confidence TEXT DEFAULT 'high' CHECK (verification_confidence IN ('high', 'medium', 'low')),
    verification_flags JSONB DEFAULT '[]'::jsonb,
    exif_gps_lat DOUBLE PRECISION,
    exif_gps_lng DOUBLE PRECISION,
    exif_timestamp TIMESTAMPTZ,
    capture_device TEXT,
    is_delayed_submission BOOLEAN DEFAULT FALSE,
    admin_reviewed BOOLEAN DEFAULT FALSE,
    admin_approved BOOLEAN
);

-- Trigger to update upvote/downvote counts
CREATE OR REPLACE FUNCTION update_issue_counts()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_TABLE_NAME = 'upvotes' THEN
        IF TG_OP = 'INSERT' THEN
            UPDATE issues SET upvote_count = upvote_count + 1 WHERE id = NEW.issue_id;
        ELSIF TG_OP = 'DELETE' THEN
            UPDATE issues SET upvote_count = upvote_count - 1 WHERE id = OLD.issue_id;
        END IF;
    ELSIF TG_TABLE_NAME = 'downvotes' THEN
        IF TG_OP = 'INSERT' THEN
            UPDATE issues SET downvote_count = downvote_count + 1 WHERE id = NEW.issue_id;
        ELSIF TG_OP = 'DELETE' THEN
            UPDATE issues SET downvote_count = downvote_count - 1 WHERE id = OLD.issue_id;
        END IF;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS update_issue_upvote_count ON upvotes;
CREATE TRIGGER update_issue_upvote_count
    AFTER INSERT OR DELETE ON upvotes
    FOR EACH ROW EXECUTE FUNCTION update_issue_counts();

DROP TRIGGER IF EXISTS update_issue_downvote_count ON downvotes;
CREATE TRIGGER update_issue_downvote_count
    AFTER INSERT OR DELETE ON downvotes
    FOR EACH ROW EXECUTE FUNCTION update_issue_counts();

DROP TRIGGER IF EXISTS update_issues_updated_at ON issues;
CREATE TRIGGER update_issues_updated_at
    BEFORE UPDATE ON issues
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ----------------------------------------------------------------------------
-- Table: upvotes
-- Description: Citizens can upvote issues they care about
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS upvotes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    issue_id UUID NOT NULL REFERENCES issues(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(issue_id, user_id)
);

-- ----------------------------------------------------------------------------
-- Table: downvotes
-- Description: Citizens can downvote issues they disagree with
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS downvotes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    issue_id UUID NOT NULL REFERENCES issues(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(issue_id, user_id)
);

-- ----------------------------------------------------------------------------
-- Table: issue_history
-- Description: Audit trail of issue status changes
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS issue_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    issue_id UUID NOT NULL REFERENCES issues(id) ON DELETE CASCADE,
    actor_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
    from_status TEXT,
    to_status TEXT NOT NULL,
    note TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Trigger to auto-log status changes
CREATE OR REPLACE FUNCTION log_issue_status_change()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.status IS DISTINCT FROM NEW.status THEN
        INSERT INTO issue_history (issue_id, actor_id, from_status, to_status, note)
        VALUES (NEW.id, NEW.reporter_id, OLD.status, NEW.status, 
                CASE 
                    WHEN OLD.status IS NULL THEN 'Issue created'
                    ELSE 'Status changed from ' || OLD.status || ' to ' || NEW.status
                END);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS log_status_change ON issues;
CREATE TRIGGER log_status_change
    AFTER UPDATE OF status ON issues
    FOR EACH ROW EXECUTE FUNCTION log_issue_status_change();

-- ----------------------------------------------------------------------------
-- Table: notifications
-- Description: User notifications for issue updates
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    issue_id UUID REFERENCES issues(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    type TEXT DEFAULT 'info' CHECK (type IN ('info', 'success', 'warning', 'error')),
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Trigger to create notification on status change
CREATE OR REPLACE FUNCTION create_status_notification()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.status IS DISTINCT FROM NEW.status THEN
        INSERT INTO notifications (user_id, issue_id, title, message, type)
        SELECT 
            NEW.reporter_id,
            NEW.id,
            'Issue Status Updated',
            'Your issue "' || NEW.title || '" status changed to ' || NEW.status,
            CASE 
                WHEN NEW.status IN ('resolved', 'closed') THEN 'success'
                WHEN NEW.status IN ('rejected') THEN 'error'
                ELSE 'info'
            END
        WHERE NEW.reporter_id IS NOT NULL;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS notify_status_change ON issues;
CREATE TRIGGER notify_status_change
    AFTER UPDATE OF status ON issues
    FOR EACH ROW EXECUTE FUNCTION create_status_notification();

-- ----------------------------------------------------------------------------
-- Table: verification_queue
-- Description: Issues flagged for manual admin review
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS verification_queue (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    issue_id UUID NOT NULL REFERENCES issues(id) ON DELETE CASCADE,
    confidence TEXT NOT NULL CHECK (confidence IN ('high', 'medium', 'low')),
    flags JSONB NOT NULL DEFAULT '[]'::jsonb,
    photo_score DOUBLE PRECISION,
    video_score DOUBLE PRECISION,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    reviewed_at TIMESTAMPTZ,
    reviewed_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    approved BOOLEAN,
    review_notes TEXT
);

-- Trigger to add low-confidence issues to verification queue
CREATE OR REPLACE FUNCTION add_to_verification_queue()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.verification_confidence = 'low' THEN
        INSERT INTO verification_queue (issue_id, confidence, flags, photo_score, video_score)
        VALUES (NEW.id, NEW.verification_confidence, NEW.verification_flags, NULL, NULL)
        ON CONFLICT DO NOTHING;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_add_to_verification_queue ON issues;
CREATE TRIGGER trigger_add_to_verification_queue
    AFTER INSERT OR UPDATE OF verification_confidence ON issues
    FOR EACH ROW
    EXECUTE FUNCTION add_to_verification_queue();

-- ----------------------------------------------------------------------------
-- Table: model_metrics
-- Description: ML model training results storage
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS model_metrics (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    accuracy DOUBLE PRECISION,
    precision_score DOUBLE PRECISION,
    recall_score DOUBLE PRECISION,
    f1_score DOUBLE PRECISION,
    confusion_matrix JSONB,
    training_history JSONB,
    epochs_trained INTEGER,
    final_val_accuracy DOUBLE PRECISION,
    final_val_loss DOUBLE PRECISION,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- SECTION 3: ROW LEVEL SECURITY (RLS)
-- ============================================================================

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE departments ENABLE ROW LEVEL SECURITY;
ALTER TABLE issues ENABLE ROW LEVEL SECURITY;
ALTER TABLE upvotes ENABLE ROW LEVEL SECURITY;
ALTER TABLE downvotes ENABLE ROW LEVEL SECURITY;
ALTER TABLE issue_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE verification_queue ENABLE ROW LEVEL SECURITY;
ALTER TABLE model_metrics ENABLE ROW LEVEL SECURITY;

-- Helper function to check if user is admin/officer
CREATE OR REPLACE FUNCTION is_admin_or_officer()
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM profiles
        WHERE id = auth.uid()
        AND role IN ('admin', 'officer')
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ===================
-- PROFILES POLICIES
-- ===================
DROP POLICY IF EXISTS "Users can view all profiles" ON profiles;
CREATE POLICY "Users can view all profiles" ON profiles
    FOR SELECT USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Users can update own profile" ON profiles;
CREATE POLICY "Users can update own profile" ON profiles
    FOR UPDATE USING (auth.uid() = id);

DROP POLICY IF EXISTS "Users can insert own profile" ON profiles;
CREATE POLICY "Users can insert own profile" ON profiles
    FOR INSERT WITH CHECK (auth.uid() = id);

DROP POLICY IF EXISTS "Admins can update any profile" ON profiles;
CREATE POLICY "Admins can update any profile" ON profiles
    FOR UPDATE USING (is_admin_or_officer());

-- ===================
-- DEPARTMENTS POLICIES
-- ===================
DROP POLICY IF EXISTS "Anyone can view departments" ON departments;
CREATE POLICY "Anyone can view departments" ON departments
    FOR SELECT USING (TRUE);

DROP POLICY IF EXISTS "Admins can manage departments" ON departments;
CREATE POLICY "Admins can manage departments" ON departments
    FOR ALL USING (is_admin_or_officer());

-- ===================
-- ISSUES POLICIES
-- ===================
DROP POLICY IF EXISTS "Anyone can view published issues" ON issues;
CREATE POLICY "Anyone can view published issues" ON issues
    FOR SELECT USING (is_draft = FALSE OR reporter_id = auth.uid());

DROP POLICY IF EXISTS "Authenticated users can create issues" ON issues;
CREATE POLICY "Authenticated users can create issues" ON issues
    FOR INSERT WITH CHECK (auth.uid() = reporter_id);

DROP POLICY IF EXISTS "Users can update own issues" ON issues;
CREATE POLICY "Users can update own issues" ON issues
    FOR UPDATE USING (
        reporter_id = auth.uid() 
        OR is_admin_or_officer()
        OR (SELECT role FROM profiles WHERE id = auth.uid()) = 'officer'
    );

DROP POLICY IF EXISTS "Users can delete own draft issues" ON issues;
CREATE POLICY "Users can delete own draft issues" ON issues
    FOR DELETE USING (reporter_id = auth.uid() AND is_draft = TRUE);

DROP POLICY IF EXISTS "Admins can manage all issues" ON issues;
CREATE POLICY "Admins can manage all issues" ON issues
    FOR ALL USING (is_admin_or_officer());

-- ===================
-- UPVOTES POLICIES
-- ===================
DROP POLICY IF EXISTS "Authenticated users can view upvotes" ON upvotes;
CREATE POLICY "Authenticated users can view upvotes" ON upvotes
    FOR SELECT USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Users can manage own upvotes" ON upvotes;
CREATE POLICY "Users can manage own upvotes" ON upvotes
    FOR ALL USING (auth.uid() = user_id);

-- ===================
-- DOWNVOTES POLICIES
-- ===================
DROP POLICY IF EXISTS "Authenticated users can view downvotes" ON downvotes;
CREATE POLICY "Authenticated users can view downvotes" ON downvotes
    FOR SELECT USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Users can manage own downvotes" ON downvotes;
CREATE POLICY "Users can manage own downvotes" ON downvotes
    FOR ALL USING (auth.uid() = user_id);

-- ===================
-- ISSUE_HISTORY POLICIES
-- ===================
DROP POLICY IF EXISTS "Anyone can view issue history" ON issue_history;
CREATE POLICY "Anyone can view issue history" ON issue_history
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM issues 
            WHERE issues.id = issue_history.issue_id 
            AND issues.is_draft = FALSE
        )
        OR EXISTS (
            SELECT 1 FROM issues 
            WHERE issues.id = issue_history.issue_id 
            AND issues.reporter_id = auth.uid()
        )
    );

DROP POLICY IF EXISTS "Service can insert history" ON issue_history;
CREATE POLICY "Service can insert history" ON issue_history
    FOR INSERT WITH CHECK (TRUE);

-- ===================
-- NOTIFICATIONS POLICIES
-- ===================
DROP POLICY IF EXISTS "Users can view own notifications" ON notifications;
CREATE POLICY "Users can view own notifications" ON notifications
    FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own notifications" ON notifications;
CREATE POLICY "Users can update own notifications" ON notifications
    FOR UPDATE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "System can create notifications" ON notifications;
CREATE POLICY "System can create notifications" ON notifications
    FOR INSERT WITH CHECK (TRUE);

-- ===================
-- VERIFICATION_QUEUE POLICIES
-- ===================
DROP POLICY IF EXISTS "Admins can manage verification_queue" ON verification_queue;
CREATE POLICY "Admins can manage verification_queue" ON verification_queue
    FOR ALL USING (is_admin_or_officer());

DROP POLICY IF EXISTS "Users can view own issues in verification_queue" ON verification_queue;
CREATE POLICY "Users can view own issues in verification_queue" ON verification_queue
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM issues
            WHERE issues.id = verification_queue.issue_id
            AND issues.reporter_id = auth.uid()
        )
    );

-- ===================
-- MODEL_METRICS POLICIES
-- ===================
DROP POLICY IF EXISTS "Users can view model_metrics" ON model_metrics;
CREATE POLICY "Users can view model_metrics" ON model_metrics
    FOR SELECT USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Service can insert model_metrics" ON model_metrics;
CREATE POLICY "Service can insert model_metrics" ON model_metrics
    FOR INSERT WITH CHECK (auth.role() = 'service_role');

-- ============================================================================
-- SECTION 4: STORED FUNCTIONS (RPCs)
-- ============================================================================

-- Function: toggle_upvote
-- Description: Toggle upvote on an issue (add if not exists, remove if exists)
CREATE OR REPLACE FUNCTION toggle_upvote(p_issue_id UUID, p_user_id UUID)
RETURNS JSONB AS $$
DECLARE
    v_exists BOOLEAN;
    v_count INTEGER;
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

-- Function: toggle_downvote
-- Description: Toggle downvote on an issue (add if not exists, remove if exists)
CREATE OR REPLACE FUNCTION toggle_downvote(p_issue_id UUID, p_user_id UUID)
RETURNS JSONB AS $$
DECLARE
    v_exists BOOLEAN;
    v_count INTEGER;
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

-- Function: get_dashboard_stats
-- Description: Get dashboard statistics for a user
CREATE OR REPLACE FUNCTION get_dashboard_stats(p_user_id UUID)
RETURNS JSONB AS $$
DECLARE
    v_resolved INTEGER;
    v_urgent INTEGER;
    v_reported INTEGER;
    v_nearby INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_resolved FROM issues 
    WHERE reporter_id = p_user_id 
    AND status IN ('resolved', 'citizen_confirmed', 'closed');
    
    SELECT COUNT(*) INTO v_urgent FROM issues 
    WHERE severity IN ('high', 'critical') 
    AND status NOT IN ('resolved', 'citizen_confirmed', 'closed')
    AND is_draft = FALSE;
    
    SELECT COUNT(*) INTO v_reported FROM issues 
    WHERE reporter_id = p_user_id;
    
    SELECT COUNT(*) INTO v_nearby FROM issues 
    WHERE is_draft = FALSE;
    
    RETURN jsonb_build_object(
        'resolved', v_resolved,
        'urgent', v_urgent,
        'reported', v_reported,
        'nearby', v_nearby
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function: mark_all_notifications_read
-- Description: Mark all notifications as read for a user
CREATE OR REPLACE FUNCTION mark_all_notifications_read(p_user_id UUID)
RETURNS VOID AS $$
BEGIN
    UPDATE notifications 
    SET is_read = TRUE 
    WHERE user_id = p_user_id AND is_read = FALSE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function: get_user_civic_score
-- Description: Calculate and return user's civic score
CREATE OR REPLACE FUNCTION get_user_civic_score(p_user_id UUID)
RETURNS INTEGER AS $$
DECLARE
    v_score INTEGER := 0;
    v_resolved_count INTEGER;
    v_upvotes_received INTEGER;
BEGIN
    -- Points for resolved issues
    SELECT COUNT(*) INTO v_resolved_count 
    FROM issues 
    WHERE reporter_id = p_user_id 
    AND status IN ('resolved', 'citizen_confirmed', 'closed');
    v_score := v_score + (v_resolved_count * 10);
    
    -- Points for upvotes received on reported issues
    SELECT COALESCE(SUM(upvote_count), 0) INTO v_upvotes_received
    FROM issues
    WHERE reporter_id = p_user_id;
    v_score := v_score + v_upvotes_received;
    
    -- Points for high ratings
    SELECT COUNT(*) INTO v_resolved_count
    FROM issues
    WHERE reporter_id = p_user_id
    AND citizen_rating >= 4;
    v_score := v_score + (v_resolved_count * 5);
    
    -- Update profile
    UPDATE profiles SET civic_score = v_score WHERE id = p_user_id;
    
    RETURN v_score;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function: get_nearby_issues
-- Description: Get issues within a radius of coordinates
CREATE OR REPLACE FUNCTION get_nearby_issues(
    p_lat DOUBLE PRECISION,
    p_lng DOUBLE PRECISION,
    p_radius_km DOUBLE PRECISION DEFAULT 10
)
RETURNS TABLE (
    id UUID,
    title TEXT,
    category TEXT,
    severity TEXT,
    status TEXT,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    address TEXT,
    distance_meters DOUBLE PRECISION
) AS $$
DECLARE
    lat_delta DOUBLE PRECISION;
    lng_delta DOUBLE PRECISION;
BEGIN
    lat_delta := p_radius_km / 111.0;  -- ~111km per degree latitude
    lng_delta := p_radius_km / (111.0 * COS(RADIANS(p_lat)));
    
    RETURN QUERY
    SELECT 
        i.id,
        i.title,
        i.category,
        i.severity,
        i.status,
        i.latitude,
        i.longitude,
        i.address,
        (
            6371000 * 2 * ASIN(
                SQRT(
                    POWER(SIN(RADIANS(p_lat - i.latitude) / 2), 2) +
                    COS(RADIANS(i.latitude)) * COS(RADIANS(p_lat)) *
                    POWER(SIN(RADIANS(p_lng - i.longitude) / 2), 2)
                )
            )
        ) AS distance_meters
    FROM issues i
    WHERE i.is_draft = FALSE
    AND i.latitude BETWEEN p_lat - lat_delta AND p_lat + lat_delta
    AND i.longitude BETWEEN p_lng - lng_delta AND p_lng + lng_delta
    ORDER BY distance_meters ASC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- SECTION 5: INDEXES
-- ============================================================================

-- Issues indexes
CREATE INDEX IF NOT EXISTS idx_issues_status ON issues(status);
CREATE INDEX IF NOT EXISTS idx_issues_category ON issues(category);
CREATE INDEX IF NOT EXISTS idx_issues_severity ON issues(severity);
CREATE INDEX IF NOT EXISTS idx_issues_reporter ON issues(reporter_id);
CREATE INDEX IF NOT EXISTS idx_issues_department ON issues(department_id);
CREATE INDEX IF NOT EXISTS idx_issues_created_at ON issues(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_issues_location ON issues(latitude, longitude);
CREATE INDEX IF NOT EXISTS idx_issues_verification_confidence ON issues(verification_confidence) WHERE verification_confidence = 'low';
CREATE INDEX IF NOT EXISTS idx_issues_draft ON issues(is_draft, reporter_id) WHERE is_draft = TRUE;

-- Upvotes/Downvotes indexes
CREATE INDEX IF NOT EXISTS idx_upvotes_issue ON upvotes(issue_id);
CREATE INDEX IF NOT EXISTS idx_upvotes_user ON upvotes(user_id);
CREATE INDEX IF NOT EXISTS idx_downvotes_issue ON downvotes(issue_id);
CREATE INDEX IF NOT EXISTS idx_downvotes_user ON downvotes(user_id);

-- Issue history indexes
CREATE INDEX IF NOT EXISTS idx_issue_history_issue ON issue_history(issue_id);
CREATE INDEX IF NOT EXISTS idx_issue_history_created ON issue_history(created_at DESC);

-- Notifications indexes
CREATE INDEX IF NOT EXISTS idx_notifications_user ON notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_unread ON notifications(user_id, is_read) WHERE is_read = FALSE;

-- Verification queue indexes
CREATE INDEX IF NOT EXISTS idx_verification_queue_unreviewed ON verification_queue(created_at) WHERE reviewed_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_verification_queue_issue ON verification_queue(issue_id);

-- ============================================================================
-- SECTION 6: STORAGE BUCKETS CONFIGURATION
-- ============================================================================

-- Bucket: issues
-- Description: Store issue photos and videos
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'issues',
    'issues',
    true,
    52428800,  -- 50MB
    ARRAY['image/jpeg', 'image/png', 'image/gif', 'video/mp4', 'video/quicktime']
)
ON CONFLICT (id) DO UPDATE SET
    public = true,
    file_size_limit = 52428800,
    allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'image/gif', 'video/mp4', 'video/quicktime'];

-- Storage policies for issues bucket
DROP POLICY IF EXISTS "Anyone can view issues images" ON storage.objects;
CREATE POLICY "Anyone can view issues images" ON storage.objects
    FOR SELECT USING (bucket_id = 'issues');

DROP POLICY IF EXISTS "Authenticated users can upload issues images" ON storage.objects;
CREATE POLICY "Authenticated users can upload issues images" ON storage.objects
    FOR INSERT WITH CHECK (
        bucket_id = 'issues' AND
        auth.role() = 'authenticated'
    );

DROP POLICY IF EXISTS "Users can update own issues images" ON storage.objects;
CREATE POLICY "Users can update own issues images" ON storage.objects
    FOR UPDATE USING (
        bucket_id = 'issues' AND
        auth.uid()::TEXT = (storage.foldername(name))[1]
    );

DROP POLICY IF EXISTS "Users can delete own issues images" ON storage.objects;
CREATE POLICY "Users can delete own issues images" ON storage.objects
    FOR DELETE USING (
        bucket_id = 'issues' AND
        auth.uid()::TEXT = (storage.foldername(name))[1]
    );

-- Bucket: avatars
-- Description: Store user profile pictures
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'avatars',
    'avatars',
    true,
    5242880,  -- 5MB
    ARRAY['image/jpeg', 'image/png', 'image/gif', 'image/webp']
)
ON CONFLICT (id) DO UPDATE SET
    public = true,
    file_size_limit = 5242880,
    allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'image/gif', 'image/webp'];

-- Storage policies for avatars bucket
DROP POLICY IF EXISTS "Anyone can view avatars" ON storage.objects;
CREATE POLICY "Anyone can view avatars" ON storage.objects
    FOR SELECT USING (bucket_id = 'avatars');

DROP POLICY IF EXISTS "Users can upload own avatar" ON storage.objects;
CREATE POLICY "Users can upload own avatar" ON storage.objects
    FOR INSERT WITH CHECK (
        bucket_id = 'avatars' AND
        auth.role() = 'authenticated'
    );

DROP POLICY IF EXISTS "Users can update own avatar" ON storage.objects;
CREATE POLICY "Users can update own avatar" ON storage.objects
    FOR UPDATE USING (
        bucket_id = 'avatars' AND
        auth.uid()::TEXT = (storage.foldername(name))[1]
    );

DROP POLICY IF EXISTS "Users can delete own avatar" ON storage.objects;
CREATE POLICY "Users can delete own avatar" ON storage.objects
    FOR DELETE USING (
        bucket_id = 'avatars' AND
        auth.uid()::TEXT = (storage.foldername(name))[1]
    );

-- ============================================================================
-- SECTION 7: ADDITIONAL HELPERS
-- ============================================================================

-- Function: Calculate distance between two points in meters (Haversine formula)
CREATE OR REPLACE FUNCTION haversine_distance(
    lat1 DOUBLE PRECISION,
    lng1 DOUBLE PRECISION,
    lat2 DOUBLE PRECISION,
    lng2 DOUBLE PRECISION
)
RETURNS DOUBLE PRECISION AS $$
DECLARE
    R DOUBLE PRECISION := 6371000;  -- Earth's radius in meters
    dlat DOUBLE PRECISION;
    dlng DOUBLE PRECISION;
    a DOUBLE PRECISION;
    c DOUBLE PRECISION;
BEGIN
    dlat := RADIANS(lat2 - lat1);
    dlng := RADIANS(lng2 - lng1);
    a := SIN(dlat / 2) * SIN(dlat / 2) +
         COS(RADIANS(lat1)) * COS(RADIANS(lat2)) *
         SIN(dlng / 2) * SIN(dlng / 2);
    c := 2 * ATAN2(SQRT(a), SQRT(1 - a));
    RETURN R * c;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- View: issues_with_distance - Issues with calculated distance from a point
CREATE OR REPLACE VIEW issues_with_distance AS
SELECT 
    i.*,
    0 AS distance_meters
FROM issues i
WHERE i.is_draft = FALSE;

-- ============================================================================
-- SECTION 8: GRANTS
-- ============================================================================

-- Grant execute on all functions to authenticated users
GRANT EXECUTE ON FUNCTION toggle_upvote TO authenticated;
GRANT EXECUTE ON FUNCTION toggle_downvote TO authenticated;
GRANT EXECUTE ON FUNCTION get_dashboard_stats TO authenticated;
GRANT EXECUTE ON FUNCTION mark_all_notifications_read TO authenticated;
GRANT EXECUTE ON FUNCTION get_user_civic_score TO authenticated;
GRANT EXECUTE ON FUNCTION get_nearby_issues TO authenticated;
GRANT EXECUTE ON FUNCTION haversine_distance TO PUBLIC;

-- Grant select on views
GRANT SELECT ON issues_with_distance TO PUBLIC;

-- ============================================================================
-- END OF SCHEMA BACKUP
-- ============================================================================
