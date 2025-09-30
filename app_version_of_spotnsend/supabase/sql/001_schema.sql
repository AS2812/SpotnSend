-- 001_schema.sql
-- Idempotent schema setup for SpotnSend realtime alert pipeline.

-- Ensure gender enum exists
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'gender') THEN
        CREATE TYPE public.gender AS ENUM ('male', 'female');
    END IF;
END
$$;

-- user_profiles table
CREATE TABLE IF NOT EXISTS public.user_profiles (
    user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    gender public.gender NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

-- user_devices table
CREATE TABLE IF NOT EXISTS public.user_devices (
    device_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    platform text NOT NULL CHECK (platform IN ('android', 'ios')),
    fcm_token text NOT NULL,
    notifications_enabled boolean NOT NULL DEFAULT true,
    last_seen timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT user_devices_user_token_key UNIQUE (user_id, fcm_token)
);

-- alert_types lookup table
CREATE TABLE IF NOT EXISTS public.alert_types (
    category text NOT NULL,
    subcategory text NOT NULL,
    label_en text NOT NULL,
    label_ar text NOT NULL,
    default_ttl_minutes integer NOT NULL,
    ongoing_days integer,
    CONSTRAINT alert_types_pkey PRIMARY KEY (category, subcategory)
);

-- Ensure alerts table has required columns
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = 'alerts' AND column_name = 'audience'
    ) THEN
        EXECUTE $$ALTER TABLE public.alerts ADD COLUMN audience text NOT NULL DEFAULT 'people' CHECK (audience IN ('people','government','both'))$$;
    END IF;
END
$$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = 'alerts' AND column_name = 'people_gender'
    ) THEN
        EXECUTE $$ALTER TABLE public.alerts ADD COLUMN people_gender text CHECK (people_gender IN ('male','female','both'))$$;
    END IF;
END
$$;

-- Ensure audience column has appropriate constraint (set explicitly in case default was used above)
ALTER TABLE public.alerts
    ALTER COLUMN audience DROP DEFAULT,
    ALTER COLUMN audience SET NOT NULL;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conrelid = 'public.alerts'::regclass AND conname = 'alerts_audience_check'
    ) THEN
        ALTER TABLE public.alerts
            ADD CONSTRAINT alerts_audience_check CHECK (audience IN ('people','government','both'));
    END IF;
END
$$;

-- Ensure people_gender constraint exists
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conrelid = 'public.alerts'::regclass AND conname = 'alerts_people_gender_check'
    ) THEN
        ALTER TABLE public.alerts
            ADD CONSTRAINT alerts_people_gender_check CHECK (people_gender IN ('male','female','both'));
    END IF;
END
$$;

-- Shared updated_at trigger function
CREATE OR REPLACE FUNCTION public.tg_set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at := now();
    RETURN NEW;
END;
$$;

-- Trigger for user_profiles updated_at
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_trigger
        WHERE tgname = 'tg_user_profiles_set_updated_at'
          AND tgrelid = 'public.user_profiles'::regclass
    ) THEN
        CREATE TRIGGER tg_user_profiles_set_updated_at
        BEFORE UPDATE ON public.user_profiles
        FOR EACH ROW
        EXECUTE FUNCTION public.tg_set_updated_at();
    END IF;
END
$$;

-- Trigger for alerts updated_at (assumes column exists)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_trigger
        WHERE tgname = 'tg_alerts_set_updated_at'
          AND tgrelid = 'public.alerts'::regclass
    ) THEN
        CREATE TRIGGER tg_alerts_set_updated_at
        BEFORE UPDATE ON public.alerts
        FOR EACH ROW
        EXECUTE FUNCTION public.tg_set_updated_at();
    END IF;
END
$$;

-- Defaulting trigger for alerts
CREATE OR REPLACE FUNCTION public.tg_alerts_defaults()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    ttl_minutes integer;
BEGIN
    IF NEW.audience = 'people' AND NEW.people_gender IS NULL THEN
        NEW.people_gender := 'both';
    END IF;

    IF NEW.live_until IS NULL THEN
        SELECT default_ttl_minutes
          INTO ttl_minutes
          FROM public.alert_types
         WHERE category = NEW.category AND subcategory = NEW.subcategory;

        IF ttl_minutes IS NULL THEN
            ttl_minutes := 60; -- fallback 1 hour
        END IF;
        NEW.live_until := now() + make_interval(mins => ttl_minutes);
    END IF;

    IF NEW.inserted_at IS NULL THEN
        NEW.inserted_at := now();
    END IF;

    RETURN NEW;
END;
$$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_trigger
        WHERE tgname = 'tg_alerts_defaults'
          AND tgrelid = 'public.alerts'::regclass
    ) THEN
        CREATE TRIGGER tg_alerts_defaults
        BEFORE INSERT ON public.alerts
        FOR EACH ROW
        EXECUTE FUNCTION public.tg_alerts_defaults();
    END IF;
END
$$;

-- Indexes for alerts
CREATE INDEX IF NOT EXISTS alerts_geom_gist ON public.alerts USING GIST (geom);
CREATE INDEX IF NOT EXISTS alerts_status_live_until_idx ON public.alerts (status, live_until);
CREATE INDEX IF NOT EXISTS alerts_category_subcategory_idx ON public.alerts (category, subcategory);

-- Index for user_devices
CREATE INDEX IF NOT EXISTS user_devices_user_idx ON public.user_devices (user_id);

-- Enable RLS and policies
ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.alerts ENABLE ROW LEVEL SECURITY;

-- user_profiles policies
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public' AND tablename = 'user_profiles' AND policyname = 'user_profiles_select'
    ) THEN
        CREATE POLICY user_profiles_select ON public.user_profiles
            FOR SELECT USING (user_id = auth.uid());
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public' AND tablename = 'user_profiles' AND policyname = 'user_profiles_modify'
    ) THEN
        CREATE POLICY user_profiles_modify ON public.user_profiles
            FOR ALL USING (user_id = auth.uid())
            WITH CHECK (user_id = auth.uid());
    END IF;
END
$$;

-- user_devices policies
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public' AND tablename = 'user_devices' AND policyname = 'user_devices_select'
    ) THEN
        CREATE POLICY user_devices_select ON public.user_devices
            FOR SELECT USING (user_id = auth.uid());
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public' AND tablename = 'user_devices' AND policyname = 'user_devices_modify'
    ) THEN
        CREATE POLICY user_devices_modify ON public.user_devices
            FOR ALL USING (user_id = auth.uid())
            WITH CHECK (user_id = auth.uid());
    END IF;
END
$$;

-- alerts policies
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public' AND tablename = 'alerts' AND policyname = 'alerts_select_live'
    ) THEN
        CREATE POLICY alerts_select_live ON public.alerts
            FOR SELECT USING (status IN ('LIVE','ONGOING'));
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public' AND tablename = 'alerts' AND policyname = 'alerts_insert_own'
    ) THEN
        CREATE POLICY alerts_insert_own ON public.alerts
            FOR INSERT WITH CHECK (reported_by = auth.uid());
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public' AND tablename = 'alerts' AND policyname = 'alerts_update_delete_limited'
    ) THEN
        CREATE POLICY alerts_update_delete_limited ON public.alerts
            FOR UPDATE, DELETE USING (
                (reported_by = auth.uid() AND now() - inserted_at <= interval '15 minutes')
                OR auth.jwt() ->> 'role' IN ('moderator','admin')
            )
            WITH CHECK (
                (reported_by = auth.uid() AND now() - inserted_at <= interval '15 minutes')
                OR auth.jwt() ->> 'role' IN ('moderator','admin')
            );
    END IF;
END
$$;

-- Allow authenticated users to read alert_types
ALTER TABLE public.alert_types ENABLE ROW LEVEL SECURITY;
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public' AND tablename = 'alert_types' AND policyname = 'alert_types_read'
    ) THEN
        CREATE POLICY alert_types_read ON public.alert_types
            FOR SELECT USING (auth.role() = 'authenticated' OR auth.role() = 'service_role');
    END IF;
END
$$;

-- Service role can manage alert_types (assumes service_role claim is available)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public' AND tablename = 'alert_types' AND policyname = 'alert_types_manage'
    ) THEN
        CREATE POLICY alert_types_manage ON public.alert_types
            FOR ALL USING (auth.role() = 'service_role')
            WITH CHECK (auth.role() = 'service_role');
    END IF;
END
$$;

-- Optional helper: ensure auth.uid() checks work for service_role inserts via supabase client
COMMENT ON TABLE public.user_profiles IS 'Stores required gender field for each user profile.';
COMMENT ON TABLE public.user_devices IS 'Registered push notification devices for each user.';
COMMENT ON TABLE public.alert_types IS 'Lookup metadata for alerts including TTL defaults.';
