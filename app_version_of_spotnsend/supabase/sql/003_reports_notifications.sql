-- 003_reports_notifications.sql
-- Report notification fan-out (people + authorities) and notification RLS helpers.

-- Helpful spatial indexes (idempotent)
CREATE INDEX IF NOT EXISTS idx_reports_location_geog
    ON public.reports
    USING GIST (location_geog);

CREATE INDEX IF NOT EXISTS idx_favorite_spots_location_geog
    ON public.favorite_spots
    USING GIST (location_geog);

CREATE UNIQUE INDEX IF NOT EXISTS idx_report_authority_dispatches_unique
    ON public.report_authority_dispatches (report_id, authority_id);

-- ============================================================================
-- Function: notify_people_for_report
-- ============================================================================
CREATE OR REPLACE FUNCTION public.notify_people_for_report(p_report_id bigint)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_report         public.reports%ROWTYPE;
    v_radius         integer;
    v_inserted_count integer := 0;
BEGIN
    SELECT *
      INTO v_report
      FROM public.reports
     WHERE report_id = p_report_id;

    IF NOT FOUND THEN
        RETURN;
    END IF;

    IF v_report.notify_scope NOT IN ('people', 'both') THEN
        RETURN;
    END IF;

    IF v_report.location_geog IS NULL THEN
        RETURN;
    END IF;

    v_radius := GREATEST(COALESCE(v_report.alert_radius_meters, 500), 100);

    WITH candidate_users AS (
        SELECT DISTINCT fs.user_id
          FROM public.favorite_spots fs
          JOIN public.user_notification_preferences prefs
            ON prefs.user_id = fs.user_id
          LEFT JOIN public.user_category_filters filter
            ON filter.user_id = fs.user_id
           AND filter.category_id = v_report.category_id
         WHERE prefs.notifications_enabled = TRUE
           AND (prefs.push_enabled OR prefs.email_enabled OR prefs.sms_enabled)
           AND (filter.is_selected IS NULL OR filter.is_selected = TRUE)
           AND fs.location_geog IS NOT NULL
           AND ST_DWithin(fs.location_geog, v_report.location_geog, v_radius)
           AND fs.user_id IS NOT NULL
    ), inserted AS (
        INSERT INTO public.notifications (
            user_id,
            notification_type,
            title,
            body,
            payload,
            related_report_id
        )
        SELECT
            cu.user_id,
            'system',
            'تنبيه قريب من موقعك',
            COALESCE(v_report.description, 'بلاغ جديد ضمن نطاقك'),
            jsonb_build_object(
                'report_id', v_report.report_id,
                'category_id', v_report.category_id,
                'lat', v_report.latitude,
                'lng', v_report.longitude,
                'radius_m', v_radius,
                'priority', v_report.priority::text,
                'notify_scope', v_report.notify_scope::text
            ),
            v_report.report_id
          FROM candidate_users cu
         WHERE cu.user_id IS DISTINCT FROM v_report.user_id
        ON CONFLICT DO NOTHING
        RETURNING 1
    )
    SELECT COUNT(*) INTO v_inserted_count FROM inserted;

    IF v_inserted_count > 0 THEN
        UPDATE public.reports
           SET notified_people_at = NOW()
         WHERE report_id = v_report.report_id;
    END IF;
END;
$$;

-- ============================================================================
-- Function: dispatch_report_to_authorities
-- ============================================================================
CREATE OR REPLACE FUNCTION public.dispatch_report_to_authorities(p_report_id bigint)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_report         public.reports%ROWTYPE;
    v_inserted_count integer := 0;
BEGIN
    SELECT *
      INTO v_report
      FROM public.reports
     WHERE report_id = p_report_id;

    IF NOT FOUND THEN
        RETURN;
    END IF;

    IF v_report.notify_scope NOT IN ('government', 'both') THEN
        RETURN;
    END IF;

    IF v_report.location_geog IS NULL THEN
        RETURN;
    END IF;

    WITH dispatched AS (
        INSERT INTO public.report_authority_dispatches (
            report_id,
            authority_id,
            status,
            channel,
            notified_at,
            created_by
        )
        SELECT
            v_report.report_id,
            a.authority_id,
            'pending',
            NULL,
            NOW(),
            v_report.user_id
          FROM public.authorities a
         WHERE a.is_active = TRUE
           AND a.location_geog IS NOT NULL
           AND ST_DWithin(a.location_geog, v_report.location_geog, a.service_radius_meters)
        ON CONFLICT DO NOTHING
        RETURNING 1
    )
    SELECT COUNT(*) INTO v_inserted_count FROM dispatched;

    IF v_inserted_count > 0 THEN
        UPDATE public.reports
           SET notified_government_at = NOW()
         WHERE report_id = v_report.report_id;
    END IF;
END;
$$;

-- ============================================================================
-- Trigger: reports_after_insert_notify
-- ============================================================================
CREATE OR REPLACE FUNCTION public.reports_after_insert_notify()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    PERFORM public.notify_people_for_report(NEW.report_id);
    PERFORM public.dispatch_report_to_authorities(NEW.report_id);
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_reports_after_insert_notify ON public.reports;
CREATE TRIGGER trg_reports_after_insert_notify
AFTER INSERT ON public.reports
FOR EACH ROW
EXECUTE FUNCTION public.reports_after_insert_notify();

-- ============================================================================
-- Notifications helper RPC + RLS policies
-- ============================================================================
CREATE OR REPLACE FUNCTION public.notifications_delete(p_id bigint)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    UPDATE public.notifications
       SET deleted_at = NOW()
     WHERE notification_id = p_id
       AND user_id = current_user_id();
END;
$$;

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
          FROM pg_policies
         WHERE schemaname = 'public'
           AND tablename = 'notifications'
           AND policyname = 'Notifications select own'
    ) THEN
        CREATE POLICY "Notifications select own"
            ON public.notifications
            FOR SELECT
            USING (user_id = current_user_id());
    END IF;

    IF NOT EXISTS (
        SELECT 1
          FROM pg_policies
         WHERE schemaname = 'public'
           AND tablename = 'notifications'
           AND policyname = 'Notifications update own'
    ) THEN
        CREATE POLICY "Notifications update own"
            ON public.notifications
            FOR UPDATE
            USING (user_id = current_user_id())
            WITH CHECK (user_id = current_user_id());
    END IF;

    IF NOT EXISTS (
        SELECT 1
          FROM pg_policies
         WHERE schemaname = 'public'
           AND tablename = 'notifications'
           AND policyname = 'Notifications service inserts'
    ) THEN
        CREATE POLICY "Notifications service inserts"
            ON public.notifications
            FOR INSERT
            TO service_role
            WITH CHECK (true);
    END IF;
END;
$$;
