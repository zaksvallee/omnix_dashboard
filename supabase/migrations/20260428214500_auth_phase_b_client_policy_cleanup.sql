BEGIN;

-- Phase B follow-up: the clients table already has tenant-scoped authenticated
-- policies from the directory migrations, but the reverse-engineered baseline
-- also preserved broad permissive policies that shadow them. Remove only the
-- permissive variants so the stricter client-scoped rules become effective.

DROP POLICY IF EXISTS "clients_all" ON public.clients;
DROP POLICY IF EXISTS "clients_insert" ON public.clients;
DROP POLICY IF EXISTS "clients_select" ON public.clients;

COMMIT;
