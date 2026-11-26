-- =====================================================================
-- Cortex AI — DATABASE SECURITY SETUP  (run ONCE, as an administrator, AFTER schema.sql)
-- ---------------------------------------------------------------------
-- Creates least-privilege ROLES and hardened login USERS:
--   cortex_app_role      the backend API at runtime: read/write user data, read-only reference data,
--                        INSERT-only audit log, no DDL, no access to schema_migrations
--   cortex_maint_role    scheduled jobs: purge deleted accounts / expired tokens
--   cortex_analyst_role  optional read-only reporting; cannot see passwords, sessions or reset tokens
--   cortex_migrator_role schema changes (deploy pipeline only; never used by the running app)
--
-- BEFORE YOU RUN:  edit the 6 SET lines below.
--   * Generate passwords with a password manager / `openssl rand -base64 36` (never reuse, never commit).
--   * Put the backend's fixed egress IP (or CIDR like '203.0.113.%') in @app_host. Do NOT leave '%' in production.
--   * On managed services (RDS, Cloud SQL, Azure, Aiven ...) you may not be allowed some options
--     (e.g. REQUIRE SSL is already enforced by a server parameter). Remove only the clauses your provider rejects.
-- Re-running is safe: users/roles are dropped & recreated.
-- =====================================================================
SET @app_host         = '%';                       -- <-- CHANGE: backend IP/CIDR, e.g. '203.0.113.%'
SET @app_password     = 'CHANGE_ME_app';           -- <-- CHANGE (>= 20 random characters)
SET @maint_password   = 'CHANGE_ME_maint';         -- <-- CHANGE
SET @analyst_password = 'CHANGE_ME_analyst';       -- <-- CHANGE (or skip the analyst user)
SET @migrator_password= 'CHANGE_ME_migrator';      -- <-- CHANGE
SET @admin_host       = '%';                       -- <-- CHANGE: your office/VPN IP for the migrator/analyst users

USE cortex_ai;

-- Refuse to continue with placeholder passwords
DROP PROCEDURE IF EXISTS tmp_guard;
DELIMITER $$
CREATE PROCEDURE tmp_guard()
BEGIN
  IF @app_password LIKE 'CHANGE\_ME%' OR @maint_password LIKE 'CHANGE\_ME%'
     OR @analyst_password LIKE 'CHANGE\_ME%' OR @migrator_password LIKE 'CHANGE\_ME%' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Edit the SET lines at the top of security.sql: placeholder passwords are not allowed';
  END IF;
  IF CHAR_LENGTH(@app_password) < 16 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Use a password of at least 16 characters for the application user';
  END IF;
END$$
DELIMITER ;
CALL tmp_guard();
DROP PROCEDURE tmp_guard;

-- ---------------------------------------------------------------------
-- 1. ROLES
-- ---------------------------------------------------------------------
DROP ROLE IF EXISTS 'cortex_app_role', 'cortex_maint_role', 'cortex_analyst_role', 'cortex_migrator_role';
CREATE ROLE 'cortex_app_role', 'cortex_maint_role', 'cortex_analyst_role', 'cortex_migrator_role';

-- 1a. Application role -------------------------------------------------
-- Reference data: read-only (the app can never change categories, strategies, weights ...)
GRANT SELECT ON cortex_ai.expense_category_groups   TO 'cortex_app_role';
GRANT SELECT ON cortex_ai.income_categories         TO 'cortex_app_role';
GRANT SELECT ON cortex_ai.role_expense_categories   TO 'cortex_app_role';
GRANT SELECT ON cortex_ai.goal_types                TO 'cortex_app_role';
GRANT SELECT ON cortex_ai.interest_options          TO 'cortex_app_role';
GRANT SELECT ON cortex_ai.allocation_buckets        TO 'cortex_app_role';
GRANT SELECT ON cortex_ai.strategies                TO 'cortex_app_role';
GRANT SELECT ON cortex_ai.strategy_bucket_weights   TO 'cortex_app_role';
GRANT SELECT ON cortex_ai.strategy_rationales       TO 'cortex_app_role';
GRANT SELECT ON cortex_ai.next_month_actions        TO 'cortex_app_role';
GRANT SELECT ON cortex_ai.next_month_action_tweaks  TO 'cortex_app_role';
-- Custom expense categories are user data (system rows have user_id NULL; the backend must only write rows with the caller's user_id)
GRANT SELECT, INSERT, UPDATE ON cortex_ai.expense_categories TO 'cortex_app_role';          -- no DELETE: deactivate with is_active = 0
-- User-owned data: full CRUD
GRANT SELECT, INSERT, UPDATE, DELETE ON cortex_ai.users                  TO 'cortex_app_role';
GRANT SELECT, INSERT, UPDATE, DELETE ON cortex_ai.user_profiles          TO 'cortex_app_role';
GRANT SELECT, INSERT, UPDATE, DELETE ON cortex_ai.user_preferences       TO 'cortex_app_role';
GRANT SELECT, INSERT, UPDATE, DELETE ON cortex_ai.user_interests         TO 'cortex_app_role';
GRANT SELECT, INSERT, UPDATE, DELETE ON cortex_ai.user_sessions          TO 'cortex_app_role';
GRANT SELECT, INSERT, UPDATE, DELETE ON cortex_ai.password_reset_tokens  TO 'cortex_app_role';
GRANT SELECT, INSERT, UPDATE, DELETE ON cortex_ai.monthly_budgets        TO 'cortex_app_role';
GRANT SELECT, INSERT, UPDATE, DELETE ON cortex_ai.income_entries         TO 'cortex_app_role';
GRANT SELECT, INSERT, UPDATE, DELETE ON cortex_ai.expense_entries        TO 'cortex_app_role';
GRANT SELECT, INSERT, UPDATE, DELETE ON cortex_ai.financial_goals        TO 'cortex_app_role';
GRANT SELECT, INSERT, UPDATE, DELETE ON cortex_ai.goal_contributions     TO 'cortex_app_role';
GRANT SELECT, INSERT, UPDATE, DELETE ON cortex_ai.transactions           TO 'cortex_app_role';
GRANT SELECT, INSERT, UPDATE, DELETE ON cortex_ai.recommendations        TO 'cortex_app_role';
GRANT SELECT, INSERT, UPDATE, DELETE ON cortex_ai.recommendation_allocations TO 'cortex_app_role';
GRANT SELECT, INSERT, UPDATE, DELETE ON cortex_ai.recommendation_factors TO 'cortex_app_role';
GRANT SELECT, INSERT, UPDATE, DELETE ON cortex_ai.recommendation_insights TO 'cortex_app_role';
GRANT SELECT, INSERT, UPDATE, DELETE ON cortex_ai.monthly_plans          TO 'cortex_app_role';
GRANT SELECT, INSERT, UPDATE, DELETE ON cortex_ai.plan_allocations       TO 'cortex_app_role';
GRANT SELECT, INSERT, UPDATE, DELETE ON cortex_ai.allocation_valuations  TO 'cortex_app_role';
-- Audit log is append-only for the app: it can write entries but never read, edit or erase them
GRANT INSERT ON cortex_ai.audit_logs TO 'cortex_app_role';
GRANT SELECT ON cortex_ai.v_monthly_summary         TO 'cortex_app_role';
GRANT SELECT ON cortex_ai.v_plan_allocation_totals  TO 'cortex_app_role';
GRANT EXECUTE ON PROCEDURE cortex_ai.sp_request_account_deletion TO 'cortex_app_role';
GRANT EXECUTE ON PROCEDURE cortex_ai.sp_lock_plan                TO 'cortex_app_role';

-- 1b. Maintenance role (cron / scheduler) ------------------------------
GRANT EXECUTE ON PROCEDURE cortex_ai.sp_purge_deleted_accounts       TO 'cortex_maint_role';
GRANT EXECUTE ON PROCEDURE cortex_ai.sp_purge_expired_security_data  TO 'cortex_maint_role';
GRANT EXECUTE ON PROCEDURE cortex_ai.sp_delete_user_account          TO 'cortex_maint_role';

-- 1c. Analyst role: aggregates & user-agnostic reporting, NO credentials/sessions/tokens/audit -----
GRANT SELECT ON cortex_ai.monthly_budgets TO 'cortex_analyst_role';
GRANT SELECT ON cortex_ai.income_entries TO 'cortex_analyst_role';
GRANT SELECT ON cortex_ai.expense_entries TO 'cortex_analyst_role';
GRANT SELECT ON cortex_ai.expense_categories TO 'cortex_analyst_role';
GRANT SELECT ON cortex_ai.income_categories TO 'cortex_analyst_role';
GRANT SELECT ON cortex_ai.role_expense_categories TO 'cortex_analyst_role';
GRANT SELECT ON cortex_ai.expense_category_groups TO 'cortex_analyst_role';
GRANT SELECT ON cortex_ai.allocation_buckets TO 'cortex_analyst_role';
GRANT SELECT ON cortex_ai.strategies TO 'cortex_analyst_role';
GRANT SELECT ON cortex_ai.monthly_plans TO 'cortex_analyst_role';
GRANT SELECT ON cortex_ai.plan_allocations TO 'cortex_analyst_role';
GRANT SELECT ON cortex_ai.allocation_valuations TO 'cortex_analyst_role';
GRANT SELECT ON cortex_ai.v_monthly_summary TO 'cortex_analyst_role';
GRANT SELECT ON cortex_ai.v_plan_allocation_totals TO 'cortex_analyst_role';

-- 1d. Migrator role: schema changes only -------------------------------
GRANT CREATE, ALTER, DROP, INDEX, REFERENCES, CREATE VIEW, SHOW VIEW, TRIGGER, CREATE ROUTINE, ALTER ROUTINE,
      SELECT, INSERT, UPDATE, DELETE ON cortex_ai.* TO 'cortex_migrator_role';

-- ---------------------------------------------------------------------
-- 2. LOGIN USERS  (passwords come from the SET lines above; never commit real ones)
-- Created through a throw-away procedure because CREATE USER cannot take variables directly.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS tmp_make_user;
DELIMITER $$
CREATE PROCEDURE tmp_make_user(IN p_user VARCHAR(32), IN p_host VARCHAR(255), IN p_pwd VARCHAR(255), IN p_role VARCHAR(32), IN p_max_conn INT)
BEGIN
  SET @s = CONCAT('DROP USER IF EXISTS ', QUOTE(p_user), '@', QUOTE(p_host));
  PREPARE st FROM @s; EXECUTE st; DEALLOCATE PREPARE st;
  SET @s = CONCAT('CREATE USER ', QUOTE(p_user), '@', QUOTE(p_host),
                  ' IDENTIFIED BY ', QUOTE(p_pwd),
                  ' REQUIRE SSL',                                   -- encrypted connections only
                  ' WITH MAX_USER_CONNECTIONS ', p_max_conn,        -- caps connection exhaustion
                  ' PASSWORD EXPIRE INTERVAL 180 DAY',              -- forces rotation
                  ' FAILED_LOGIN_ATTEMPTS 5 PASSWORD_LOCK_TIME 1');  -- brute-force protection (MySQL 8.0.19+)
  PREPARE st FROM @s; EXECUTE st; DEALLOCATE PREPARE st;
  SET @s = CONCAT('GRANT ', QUOTE(p_role), ' TO ', QUOTE(p_user), '@', QUOTE(p_host));
  PREPARE st FROM @s; EXECUTE st; DEALLOCATE PREPARE st;
  SET @s = CONCAT('SET DEFAULT ROLE ', QUOTE(p_role), ' TO ', QUOTE(p_user), '@', QUOTE(p_host));
  PREPARE st FROM @s; EXECUTE st; DEALLOCATE PREPARE st;
END$$
DELIMITER ;

CALL tmp_make_user('cortex_app',      @app_host,   @app_password,      'cortex_app_role',      40);
CALL tmp_make_user('cortex_maint',    @admin_host, @maint_password,    'cortex_maint_role',     2);
CALL tmp_make_user('cortex_analyst',  @admin_host, @analyst_password,  'cortex_analyst_role',   3);
CALL tmp_make_user('cortex_migrator', @admin_host, @migrator_password, 'cortex_migrator_role',  2);
DROP PROCEDURE tmp_make_user;

-- ---------------------------------------------------------------------
-- 3. VERIFY (read the output; each line should match the comment)
-- ---------------------------------------------------------------------
SHOW GRANTS FOR 'cortex_app_role';                         -- no DROP/ALTER/CREATE, no GRANT OPTION, audit_logs = INSERT only
SELECT user, host, ssl_type, max_user_connections, password_lifetime, account_locked
  FROM mysql.user WHERE user IN ('cortex_app','cortex_maint','cortex_analyst','cortex_migrator') ORDER BY user;   -- ssl_type should be ANY

-- Quick manual checks, run while connected as cortex_app (each of these MUST fail):
--   DROP TABLE users;                              -> ERROR 1142 (no DROP privilege)
--   DELETE FROM audit_logs;                        -> ERROR 1142 (INSERT only)
--   UPDATE strategies SET name = 'x';              -> ERROR 1142 (read-only reference data)
--   SELECT * FROM schema_migrations;               -- ERROR 1142
--   CALL sp_purge_deleted_accounts(0);             -> ERROR 1370 (only the maintenance role may purge)
