-- 002_realtime.sql
-- Configure Supabase realtime publication + replica identity for SpotnSend.

-- Add alerts table to supabase_realtime publication (ignore if already present)
DO $$
BEGIN
    BEGIN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.alerts;
    EXCEPTION
        WHEN duplicate_object THEN
            NULL; -- already present
    END;
END
$$;

-- Add user_devices for presence/push sync via realtime (ignore duplicates)
DO $$
BEGIN
    BEGIN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.user_devices;
    EXCEPTION
        WHEN duplicate_object THEN
            NULL;
    END;
END
$$;


-- Add notifications table to supabase_realtime publication (ignore if already present)
DO $$
BEGIN
    BEGIN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
    EXCEPTION
        WHEN duplicate_object THEN
            NULL;
    END;
END
$$;

-- Ensure full row data emitted for updates (needed for Postgres Changes payloads)
ALTER TABLE public.alerts REPLICA IDENTITY FULL;
ALTER TABLE public.user_devices REPLICA IDENTITY FULL;

ALTER TABLE public.notifications REPLICA IDENTITY FULL;

-- Tip: In the Supabase Dashboard, Realtime ? "Listen to a table" toggles these tables on/off. Keep alerts/user_devices enabled.

-- Example Flutter subscription using supabase_flutter Postgres Changes API.
-- Source: https://supabase.com/docs/guides/realtime/postgres-changes
--
-- final channel = supabase.channel('alerts-channel')
--   ..onPostgresChanges(
--     event: PostgresChangeEvent.all,
--     schema: 'public',
--     table: 'alerts',
--     callback: (payload) {
--       // Handle INSERT/UPDATE/DELETE
--     },
--   )
--   ..subscribe();
