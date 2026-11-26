-- Applied by the postgres service each time its container starts.
-- Keep every statement safe to rerun.
-- Layout: 1) users  2) databases to create  3) same access setup in every database

\getenv lawrence_password LAWRENCE_PASSWORD
\getenv bob_password BOB_PASSWORD
\getenv table_owner TABLE_OWNER

-- ===============================================================
-- 1. USERS (create only if missing; passwords are not changed)
-- ===============================================================
SELECT format('CREATE ROLE lawrence LOGIN PASSWORD %L', :'lawrence_password')
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'lawrence')
\gexec

SELECT format('CREATE ROLE bob LOGIN PASSWORD %L', :'bob_password')
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'bob')
\gexec

-- ===============================================================
-- 2. DATABASES to create if missing
--    To add a database, add its name to this list.
-- ===============================================================
SELECT format('CREATE DATABASE %I', db)
FROM unnest(ARRAY[
    'key_accounts_prod',
    'secondary_sales_prod'
]) AS db
WHERE NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = db)
\gexec

-- ===============================================================
-- 3. ALL DATABASES (except postgres and templates)
--    Creates schemas raw and analytics.
--    lawrence, bob: read-only on analytics, no grants on raw.
-- ===============================================================
-- Build one block per database into a temporary file, then run it
SELECT format($block$
\connect %1$I
BEGIN;

CREATE SCHEMA IF NOT EXISTS raw;
CREATE SCHEMA IF NOT EXISTS analytics;

GRANT CONNECT ON DATABASE %1$I TO lawrence, bob;
GRANT USAGE ON SCHEMA analytics TO lawrence, bob;

-- Existing tables and views
GRANT SELECT ON ALL TABLES IN SCHEMA analytics TO lawrence, bob;

-- Future tables and views created by table_owner
ALTER DEFAULT PRIVILEGES FOR ROLE %2$I IN SCHEMA analytics
    GRANT SELECT ON TABLES TO lawrence, bob;

ALTER ROLE lawrence IN DATABASE %1$I SET search_path = analytics;
ALTER ROLE bob IN DATABASE %1$I SET search_path = analytics;

COMMIT;
$block$, datname, :'table_owner')
FROM pg_database
WHERE NOT datistemplate
  AND datallowconn
  AND datname <> 'postgres'
ORDER BY datname
\g (format=unaligned tuples_only=on) /tmp/apply_access.sql

\i /tmp/apply_access.sql