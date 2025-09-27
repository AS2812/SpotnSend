
-- 004_report_audience_gender.sql
-- Introduce audience gender targeting for people notifications and modernise report RPCs.

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
      FROM information_schema.columns
     WHERE table_schema = 'public'
       AND table_name = 'reports'
       AND column_name = 'notify_people_gender'
  ) THEN
    ALTER TABLE public.reports
      ADD COLUMN notify_people_gender text DEFAULT 'both'
      CHECK (notify_people_gender IN ('male', 'female', 'both'));
  END IF;
END
$$;

ALTER TABLE public.reports
  ALTER COLUMN notify_people_gender SET DEFAULT 'both';

UPDATE public.reports
   SET notify_people_gender = 'both'
 WHERE notify_people_gender IS NULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
      FROM pg_constraint
     WHERE conrelid = 'public.reports'::regclass
       AND conname = 'reports_notify_people_gender_check'
  ) THEN
    ALTER TABLE public.reports
      ADD CONSTRAINT reports_notify_people_gender_check
      CHECK (notify_people_gender IN ('male', 'female', 'both'));
  END IF;
END
$$;

ALTER TABLE public.reports
  ALTER COLUMN notify_people_gender SET NOT NULL;

CREATE OR REPLACE FUNCTION public.create_report_simple(
  p_category_id smallint,
  p_subcategory_id integer DEFAULT NULL,
  p_description text,
  p_lat double precision,
  p_lng double precision,
  p_notify text DEFAULT 'people',
  p_priority text DEFAULT 'normal',
  p_radius integer DEFAULT NULL,
  p_notify_people_gender text DEFAULT 'both'
)
RETURNS public.reports
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id bigint;
  v_radius integer;
  v_notify text;
  v_priority text;
  v_gender text;
  v_report public.reports;
BEGIN
  v_user_id := current_user_id();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'User must be authenticated';
  END IF;

  v_radius := COALESCE(NULLIF(p_radius, 0), 500);
  v_notify := LOWER(COALESCE(NULLIF(p_notify, ''), 'people'));
  v_priority := LOWER(COALESCE(NULLIF(p_priority, ''), 'normal'));
  v_gender := LOWER(COALESCE(NULLIF(p_notify_people_gender, ''), 'both'));

  IF v_notify <> 'people' THEN
    v_gender := 'both';
  ELSIF v_gender NOT IN ('male', 'female', 'both') THEN
    v_gender := 'both';
  END IF;

  INSERT INTO public.reports (
    user_id,
    category_id,
    subcategory_id,
    description,
    latitude,
    longitude,
    location_geog,
    notify_scope,
    priority,
    alert_radius_meters,
    notify_people_gender
  )
  VALUES (
    v_user_id,
    p_category_id,
    p_subcategory_id,
    NULLIF(p_description, ''),
    p_lat,
    p_lng,
    ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography,
    v_notify::notify_scope,
    v_priority::report_priority,
    v_radius,
    v_gender
  )
  RETURNING * INTO v_report;

  RETURN v_report;
END;
$$;

CREATE OR REPLACE FUNCTION public.create_report(
  p_category_id smallint,
  p_subcategory_id integer DEFAULT NULL,
  p_description text,
  p_lat double precision,
  p_lng double precision,
  p_notify text DEFAULT 'people',
  p_priority text DEFAULT 'normal',
  p_radius integer DEFAULT NULL,
  p_notify_people_gender text DEFAULT 'both'
)
RETURNS public.reports
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN public.create_report_simple(
    p_category_id => p_category_id,
    p_subcategory_id => p_subcategory_id,
    p_description => p_description,
    p_lat => p_lat,
    p_lng => p_lng,
    p_notify => p_notify,
    p_priority => p_priority,
    p_radius => p_radius,
    p_notify_people_gender => p_notify_people_gender
  );
END;
$$;

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
    v_gender         text;
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
    v_gender := LOWER(COALESCE(v_report.notify_people_gender, 'both'));

    WITH candidate_users AS (
        SELECT DISTINCT fs.user_id
          FROM public.favorite_spots fs
          JOIN public.user_notification_preferences prefs
            ON prefs.user_id = fs.user_id
          JOIN public.users app_user ON app_user.user_id = fs.user_id
          LEFT JOIN public.user_profiles profile
            ON profile.user_id = app_user.auth_user_id
          LEFT JOIN public.user_category_filters filter
            ON filter.user_id = fs.user_id
           AND filter.category_id = v_report.category_id
         WHERE prefs.notifications_enabled = TRUE
           AND (prefs.push_enabled OR prefs.email_enabled OR prefs.sms_enabled)
           AND (filter.is_selected IS NULL OR filter.is_selected = TRUE)
           AND fs.location_geog IS NOT NULL
           AND ST_DWithin(fs.location_geog, v_report.location_geog, v_radius)
           AND fs.user_id IS NOT NULL
           AND (
             v_gender = 'both'
             OR (
               v_gender = 'male'
               AND profile.gender::text = 'male'
             )
             OR (
               v_gender = 'female'
               AND profile.gender::text = 'female'
             )
           )
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
                'notify_scope', v_report.notify_scope::text,
                'notify_people_gender', v_gender
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
