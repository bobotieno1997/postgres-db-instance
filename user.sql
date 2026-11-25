-- Applied by the postgres service each time its container starts.
-- Keep every statement safe to rerun.

\getenv lawrence_password LAWRENCE_PASSWORD
\getenv bob_password BOB_PASSWORD
\getenv table_owner TABLE_OWNER

-- ---------------------------------------------------------------
-- Schema
-- ---------------------------------------------------------------
CREATE SCHEMA IF NOT EXISTS analytics;

-- ---------------------------------------------------------------
-- User: lawrence (read-only on analytics)
-- ---------------------------------------------------------------

-- Create only if missing (an existing password is not changed)
SELECT format('CREATE ROLE lawrence LOGIN PASSWORD %L', :'lawrence_password')
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'lawrence')
\gexec

GRANT CONNECT ON DATABASE :"DBNAME" TO lawrence;
GRANT USAGE ON SCHEMA analytics TO lawrence;

-- Existing tables and views
GRANT SELECT ON ALL TABLES IN SCHEMA analytics TO lawrence;

-- Future tables and views created by table_owner
ALTER DEFAULT PRIVILEGES FOR ROLE :"table_owner" IN SCHEMA analytics
    GRANT SELECT ON TABLES TO lawrence;

ALTER ROLE lawrence IN DATABASE :"DBNAME" SET search_path = analytics;

-- ---------------------------------------------------------------
-- User: bob (read-only on analytics)
-- ---------------------------------------------------------------

-- Create only if missing (an existing password is not changed)
SELECT format('CREATE ROLE bob LOGIN PASSWORD %L', :'bob_password')
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'bob')
\gexec

GRANT CONNECT ON DATABASE :"DBNAME" TO bob;
GRANT USAGE ON SCHEMA analytics TO bob;

-- Existing tables and views
GRANT SELECT ON ALL TABLES IN SCHEMA analytics TO bob;

-- Future tables and views created by table_owner
ALTER DEFAULT PRIVILEGES FOR ROLE :"table_owner" IN SCHEMA analytics
    GRANT SELECT ON TABLES TO bob;

ALTER ROLE bob IN DATABASE :"DBNAME" SET search_path = analytics;