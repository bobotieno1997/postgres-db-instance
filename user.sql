-- Applied by the postgres service each time its container starts.
-- Keep every statement safe to rerun.
-- Layout: 1) users (shared by all databases)  2) one access section per database.

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
-- 2. DATABASE: key_accounts_prod
--    Read-only on schema analytics: lawrence, bob
-- ===============================================================
-- Create the database if missing (must stay outside BEGIN/COMMIT)
SELECT 'CREATE DATABASE key_accounts_prod'
WHERE NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = 'key_accounts_prod')
\gexec

\connect key_accounts_prod
BEGIN;

CREATE SCHEMA IF NOT EXISTS analytics;

GRANT CONNECT ON DATABASE :"DBNAME" TO lawrence, bob;
GRANT USAGE ON SCHEMA analytics TO lawrence, bob;

-- Existing tables and views
GRANT SELECT ON ALL TABLES IN SCHEMA analytics TO lawrence, bob;

-- Future tables and views created by table_owner
ALTER DEFAULT PRIVILEGES FOR ROLE :"table_owner" IN SCHEMA analytics
    GRANT SELECT ON TABLES TO lawrence, bob;

ALTER ROLE lawrence IN DATABASE :"DBNAME" SET search_path = analytics;
ALTER ROLE bob IN DATABASE :"DBNAME" SET search_path = analytics;

COMMIT;