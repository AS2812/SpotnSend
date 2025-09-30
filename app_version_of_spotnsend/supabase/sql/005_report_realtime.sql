-- 005_report_realtime.sql
-- Legacy websocket broadcasting has been removed in favour of periodic polling.
-- This script now drops the trigger/function that previously emitted NOTIFY events.

DROP TRIGGER IF EXISTS trg_reports_broadcast_notify ON public.reports;
DROP FUNCTION IF EXISTS public.reports_broadcast_notify();
