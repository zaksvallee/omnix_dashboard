BEGIN;

-- Phase B follow-up: the guards table already has the intended tenant-scoped
-- authenticated policies from the directory migrations, but the reverse-
-- engineered baseline also captured several broad permissive policies that
-- shadow them. Remove only the permissive variants so the stricter policies
-- become effective without redesigning the table contract.

DROP POLICY IF EXISTS "allow authenticated read guards" ON public.guards;
DROP POLICY IF EXISTS "guards_all" ON public.guards;
DROP POLICY IF EXISTS "guards_insert" ON public.guards;
DROP POLICY IF EXISTS "guards_read_authenticated" ON public.guards;
DROP POLICY IF EXISTS "guards_select" ON public.guards;
DROP POLICY IF EXISTS "guards_write_authenticated" ON public.guards;

COMMIT;
