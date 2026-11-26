-- =====================================================================
-- Cortex AI — MySQL 8.0+ schema            (run first)
-- Database : cortex_ai     Engine: InnoDB     Charset: utf8mb4
-- Run      : MySQL Workbench -> File > Open SQL Script -> Execute (lightning bolt)
-- Safe to re-run: it DROPS and recreates the cortex_ai database.
--            !! NEVER run this against a database holding real user data !!
-- =====================================================================
-- Derived from the uploaded frontend (index.html). Every table below is
-- tagged with the frontend feature it supports:
--   [UI]      = the current frontend collects/shows this data
--   [PHASE-2] = NOT in the current frontend; needed for requested features
--               (transaction history, goal progress). Safe to ignore until
--               the UI adds them.
-- =====================================================================

SET NAMES utf8mb4;
SET time_zone = '+00:00';                 -- all TIMESTAMPs are stored/compared in UTC
SET FOREIGN_KEY_CHECKS = 0;

DROP DATABASE IF EXISTS cortex_ai;
CREATE DATABASE cortex_ai
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_0900_ai_ci;             -- case-insensitive => email uniqueness is case-insensitive
USE cortex_ai;

SET FOREIGN_KEY_CHECKS = 1;

-- =====================================================================
-- SECTION 1 — REFERENCE / LOOKUP TABLES  (written by DBA/migrations only)
-- =====================================================================

-- Tracks which migration files have been applied (see deployment_guide.md)
CREATE TABLE schema_migrations (
  version      VARCHAR(20)  NOT NULL,
  description  VARCHAR(200) NOT NULL,
  applied_at   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (version)
) ENGINE=InnoDB;

-- [UI] Expense group headings on Income & Expenses page
CREATE TABLE expense_category_groups (
  group_id    TINYINT UNSIGNED NOT NULL AUTO_INCREMENT,
  name        VARCHAR(60)      NOT NULL,
  sort_order  TINYINT UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (group_id),
  UNIQUE KEY uq_ecg_name (name)
) ENGINE=InnoDB;

-- [UI] Income lines ("Monthly Salary", "Monthly Allowance", "Scholarship", "Other Income")
CREATE TABLE income_categories (
  income_category_id  SMALLINT UNSIGNED NOT NULL AUTO_INCREMENT,
  code                VARCHAR(30)       NOT NULL,
  name                VARCHAR(60)       NOT NULL,
  applies_to          ENUM('employee','student','both') NOT NULL,
  sort_order          TINYINT UNSIGNED  NOT NULL DEFAULT 0,
  is_active           TINYINT(1)        NOT NULL DEFAULT 1,
  PRIMARY KEY (income_category_id),
  UNIQUE KEY uq_ic_code (code),
  UNIQUE KEY uq_ic_name (name)
) ENGINE=InnoDB;

-- [UI] Expense lines. user_id NULL = system default; user_id set = the user's
-- own "+ Add Custom Line". `nature` is NOT in the UI (UI calls every line
-- "essential"); it exists so essential-vs-discretionary analytics are possible.
CREATE TABLE expense_categories (
  category_id  INT UNSIGNED  NOT NULL AUTO_INCREMENT,
  user_id      BIGINT UNSIGNED NULL,                       -- FK added after users table
  code         VARCHAR(40)   NULL,                         -- stable key for system rows, NULL for custom
  name         VARCHAR(80)   NOT NULL,
  nature       ENUM('essential','discretionary') NOT NULL DEFAULT 'essential',
  is_active    TINYINT(1)    NOT NULL DEFAULT 1,           -- soft-delete: never hard-delete a used category
  owner_scope  BIGINT UNSIGNED GENERATED ALWAYS AS (IFNULL(user_id, 0)) VIRTUAL,
  created_at   TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (category_id),
  UNIQUE KEY uq_ec_owner_name (owner_scope, name),          -- unique names per owner (system = scope 0)
  UNIQUE KEY uq_ec_code (code),                             -- NULLs allowed multiple times
  KEY ix_ec_user (user_id)
) ENGINE=InnoDB;

-- [UI] Which system categories each role sees, under which heading, in what order
CREATE TABLE role_expense_categories (
  role         ENUM('employee','student') NOT NULL,
  category_id  INT UNSIGNED      NOT NULL,
  group_id     TINYINT UNSIGNED  NOT NULL,
  sort_order   TINYINT UNSIGNED  NOT NULL DEFAULT 0,
  PRIMARY KEY (role, category_id),
  CONSTRAINT fk_rec_category FOREIGN KEY (category_id) REFERENCES expense_categories(category_id),
  CONSTRAINT fk_rec_group    FOREIGN KEY (group_id)    REFERENCES expense_category_groups(group_id)
) ENGINE=InnoDB;

-- [UI] The 10 goal cards. "No Specific Goal" is NOT a row: it means "user has no goal rows".
CREATE TABLE goal_types (
  goal_type_id  TINYINT UNSIGNED NOT NULL AUTO_INCREMENT,
  code          VARCHAR(20)      NOT NULL,
  name          VARCHAR(60)      NOT NULL,
  icon          VARCHAR(8)       NULL,
  sort_order    TINYINT UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (goal_type_id),
  UNIQUE KEY uq_gt_code (code)
) ENGINE=InnoDB;

-- [UI] "Lifestyle interests" and "Financial preferences" chips
CREATE TABLE interest_options (
  interest_id  SMALLINT UNSIGNED NOT NULL AUTO_INCREMENT,
  kind         ENUM('lifestyle','financial') NOT NULL,
  name         VARCHAR(40)       NOT NULL,
  sort_order   TINYINT UNSIGNED  NOT NULL DEFAULT 0,
  PRIMARY KEY (interest_id),
  UNIQUE KEY uq_io_kind_name (kind, name)
) ENGINE=InnoDB;

-- [UI] The 9 allocation buckets (Savings, Fixed Deposit, ... Others).
-- bucket_group is a DB-side classification used by the dashboard queries.
CREATE TABLE allocation_buckets (
  bucket_id     TINYINT UNSIGNED NOT NULL AUTO_INCREMENT,
  code          VARCHAR(20)      NOT NULL,
  name          VARCHAR(40)      NOT NULL,
  description   VARCHAR(120)     NULL,
  color_hex     CHAR(7)          NOT NULL,
  bucket_group  ENUM('saving','investment','lifestyle','other') NOT NULL,
  sort_order    TINYINT UNSIGNED NOT NULL,
  PRIMARY KEY (bucket_id),
  UNIQUE KEY uq_ab_code (code),
  CONSTRAINT ck_ab_color CHECK (color_hex REGEXP '^#[0-9A-Fa-f]{6}$')
) ENGINE=InnoDB;

-- [UI] Conservative / Balanced / Accelerated Goal strategies
CREATE TABLE strategies (
  strategy_id  TINYINT UNSIGNED NOT NULL AUTO_INCREMENT,
  code         VARCHAR(20)      NOT NULL,
  name         VARCHAR(60)      NOT NULL,
  description  VARCHAR(200)     NOT NULL,
  PRIMARY KEY (strategy_id),
  UNIQUE KEY uq_st_code (code)
) ENGINE=InnoDB;

-- [UI] Baseline % per bucket per strategy (each strategy must sum to 100: see test_database.sql)
CREATE TABLE strategy_bucket_weights (
  strategy_id  TINYINT UNSIGNED NOT NULL,
  bucket_id    TINYINT UNSIGNED NOT NULL,
  weight_pct   DECIMAL(5,2)     NOT NULL,
  PRIMARY KEY (strategy_id, bucket_id),
  CONSTRAINT fk_sbw_strategy FOREIGN KEY (strategy_id) REFERENCES strategies(strategy_id),
  CONSTRAINT fk_sbw_bucket   FOREIGN KEY (bucket_id)   REFERENCES allocation_buckets(bucket_id),
  CONSTRAINT ck_sbw_pct CHECK (weight_pct BETWEEN 0 AND 100)
) ENGINE=InnoDB;

-- [UI] "Why did Cortex AI suggest this?" bullet points
CREATE TABLE strategy_rationales (
  strategy_id  TINYINT UNSIGNED NOT NULL,
  sort_order   TINYINT UNSIGNED NOT NULL,
  rationale    VARCHAR(250)     NOT NULL,
  PRIMARY KEY (strategy_id, sort_order),
  CONSTRAINT fk_sr_strategy FOREIGN KEY (strategy_id) REFERENCES strategies(strategy_id)
) ENGINE=InnoDB;

-- [UI] Next Month page: Continue / Modify / Review-Reduce
CREATE TABLE next_month_actions (
  action_id    TINYINT UNSIGNED NOT NULL AUTO_INCREMENT,
  code         VARCHAR(20)      NOT NULL,
  title        VARCHAR(40)      NOT NULL,
  badge        VARCHAR(20)      NOT NULL,
  description  VARCHAR(250)     NOT NULL,
  PRIMARY KEY (action_id),
  UNIQUE KEY uq_nma_code (code)
) ENGINE=InnoDB;

-- [UI] +/- percentage-point tweak each action applies to each bucket
CREATE TABLE next_month_action_tweaks (
  action_id  TINYINT UNSIGNED NOT NULL,
  bucket_id  TINYINT UNSIGNED NOT NULL,
  tweak_pct  DECIMAL(5,2)     NOT NULL DEFAULT 0,
  PRIMARY KEY (action_id, bucket_id),
  CONSTRAINT fk_nmat_action FOREIGN KEY (action_id) REFERENCES next_month_actions(action_id),
  CONSTRAINT fk_nmat_bucket FOREIGN KEY (bucket_id) REFERENCES allocation_buckets(bucket_id),
  CONSTRAINT ck_nmat_tweak CHECK (tweak_pct BETWEEN -100 AND 100)
) ENGINE=InnoDB;

-- =====================================================================
-- SECTION 2 — USERS, PROFILE, PREFERENCES, SESSIONS
-- =====================================================================

-- [UI] Login / Create Account / Profile (name, email, Student|Employee)
CREATE TABLE users (
  user_id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  public_id            CHAR(36)        NOT NULL DEFAULT (UUID()),      -- expose THIS in APIs/URLs, never user_id
  email                VARCHAR(254)    NOT NULL,
  password_hash        VARCHAR(255)    NOT NULL,                        -- argon2id or bcrypt hash ONLY
  full_name            VARCHAR(100)    NOT NULL,
  role                 ENUM('employee','student') NOT NULL,
  status               ENUM('active','suspended','pending_deletion') NOT NULL DEFAULT 'active',
  is_demo              TINYINT(1)      NOT NULL DEFAULT 0,              -- 1 = fictional demo account (seed.sql)
  email_verified_at    TIMESTAMP       NULL,
  failed_login_count   TINYINT UNSIGNED NOT NULL DEFAULT 0,
  locked_until         TIMESTAMP       NULL,
  last_login_at        TIMESTAMP       NULL,
  deletion_requested_at TIMESTAMP      NULL,
  created_at           TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at           TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (user_id),
  UNIQUE KEY uq_users_email (email),
  UNIQUE KEY uq_users_public_id (public_id),
  KEY ix_users_status (status, deletion_requested_at),
  CONSTRAINT ck_users_email CHECK (email REGEXP '^[^@[:space:]]+@[^@[:space:]]+\\.[^@[:space:]]+$'),
  CONSTRAINT ck_users_name  CHECK (CHAR_LENGTH(TRIM(full_name)) > 0),
  CONSTRAINT ck_users_pwhash CHECK (CHAR_LENGTH(password_hash) >= 50)  -- rejects obvious plaintext passwords
) ENGINE=InnoDB;

ALTER TABLE expense_categories
  ADD CONSTRAINT fk_ec_user FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE;

-- [UI] Money, Goals & Interests page: risk cards, lifestyle slider, chosen strategy
CREATE TABLE user_profiles (
  user_id               BIGINT UNSIGNED  NOT NULL,
  risk_preference       ENUM('conservative','moderate','aggressive') NOT NULL DEFAULT 'moderate',
  lifestyle_pct         TINYINT UNSIGNED NOT NULL DEFAULT 15,          -- slider 0..60
  preferred_strategy_id TINYINT UNSIGNED NOT NULL DEFAULT 2,           -- 2 = balanced (see reference data)
  updated_at            TIMESTAMP        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (user_id),
  CONSTRAINT fk_up_user     FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
  CONSTRAINT fk_up_strategy FOREIGN KEY (preferred_strategy_id) REFERENCES strategies(strategy_id),
  CONSTRAINT ck_up_lifestyle CHECK (lifestyle_pct BETWEEN 0 AND 60)
) ENGINE=InnoDB;

-- [UI] Settings > Appearance (today kept in browser localStorage 'cortexAppearance')
CREATE TABLE user_preferences (
  user_id        BIGINT UNSIGNED NOT NULL,
  theme_mode     ENUM('dark','light','system')            NOT NULL DEFAULT 'dark',
  accent         ENUM('pink','blue','purple','cyan')      NOT NULL DEFAULT 'pink',
  font_size      ENUM('small','medium','large')           NOT NULL DEFAULT 'medium',
  card_style     ENUM('glass','solid')                    NOT NULL DEFAULT 'glass',
  text_contrast  ENUM('normal','enhanced','maximum')      NOT NULL DEFAULT 'normal',
  high_contrast  TINYINT(1) NOT NULL DEFAULT 0,
  sparks         TINYINT(1) NOT NULL DEFAULT 1,
  glow           TINYINT(1) NOT NULL DEFAULT 1,
  reduce_motion  TINYINT(1) NOT NULL DEFAULT 0,
  updated_at     TIMESTAMP  NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (user_id),
  CONSTRAINT fk_upref_user FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- [UI] many-to-many: users <-> interest chips
CREATE TABLE user_interests (
  user_id      BIGINT UNSIGNED   NOT NULL,
  interest_id  SMALLINT UNSIGNED NOT NULL,
  PRIMARY KEY (user_id, interest_id),
  CONSTRAINT fk_ui_user     FOREIGN KEY (user_id)     REFERENCES users(user_id) ON DELETE CASCADE,
  CONSTRAINT fk_ui_interest FOREIGN KEY (interest_id) REFERENCES interest_options(interest_id)
) ENGINE=InnoDB;

-- [UI] Replaces sessionStorage 'cortexSession'. Store only a HASH of the refresh token.
CREATE TABLE user_sessions (
  session_id          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id             BIGINT UNSIGNED NOT NULL,
  refresh_token_hash  CHAR(64)        NOT NULL,                       -- SHA-256 hex of the token
  user_agent          VARCHAR(255)    NULL,
  ip_address          VARCHAR(45)     NULL,
  created_at          TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
  expires_at          TIMESTAMP       NOT NULL,
  revoked_at          TIMESTAMP       NULL,
  PRIMARY KEY (session_id),
  UNIQUE KEY uq_us_token (refresh_token_hash),
  KEY ix_us_user (user_id, revoked_at, expires_at),
  CONSTRAINT fk_us_user FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- [UI] "Forgot password?" link (backend sends the email; DB stores only the hash)
CREATE TABLE password_reset_tokens (
  token_id    BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id     BIGINT UNSIGNED NOT NULL,
  token_hash  CHAR(64)        NOT NULL,
  created_at  TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
  expires_at  TIMESTAMP       NOT NULL,
  used_at     TIMESTAMP       NULL,
  PRIMARY KEY (token_id),
  UNIQUE KEY uq_prt_token (token_hash),
  KEY ix_prt_user (user_id),
  CONSTRAINT fk_prt_user FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- =====================================================================
-- SECTION 3 — MONTHLY BUDGET (income & essential-expense lines)
-- =====================================================================

-- [UI] One row per user per calendar month. The frontend has no month picker yet,
-- but "Monthly Analysis", "Financial History" and the trend chart need a month axis.
CREATE TABLE monthly_budgets (
  budget_id     BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id       BIGINT UNSIGNED NOT NULL,
  budget_month  DATE            NOT NULL,                         -- always the 1st of the month
  created_at    TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at    TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (budget_id),
  UNIQUE KEY uq_mb_user_month (user_id, budget_month),
  CONSTRAINT fk_mb_user FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
  CONSTRAINT ck_mb_first_of_month CHECK (DAYOFMONTH(budget_month) = 1)
) ENGINE=InnoDB;

-- [UI] "Income" card: one amount per income source per month
CREATE TABLE income_entries (
  entry_id            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  budget_id           BIGINT UNSIGNED NOT NULL,
  income_category_id  SMALLINT UNSIGNED NOT NULL,
  amount              DECIMAL(12,2)   NOT NULL DEFAULT 0.00,
  PRIMARY KEY (entry_id),
  UNIQUE KEY uq_ie_budget_cat (budget_id, income_category_id),
  KEY ix_ie_cat (income_category_id),
  CONSTRAINT fk_ie_budget   FOREIGN KEY (budget_id)          REFERENCES monthly_budgets(budget_id) ON DELETE CASCADE,
  CONSTRAINT fk_ie_category FOREIGN KEY (income_category_id) REFERENCES income_categories(income_category_id),
  CONSTRAINT ck_ie_amount CHECK (amount >= 0 AND amount <= 9999999999.99)
) ENGINE=InnoDB;

-- [UI] "Essential Expenses" card: amount + Flexible toggle + Due day (1-31) per line
CREATE TABLE expense_entries (
  entry_id     BIGINT UNSIGNED  NOT NULL AUTO_INCREMENT,
  budget_id    BIGINT UNSIGNED  NOT NULL,
  category_id  INT UNSIGNED     NOT NULL,
  amount       DECIMAL(12,2)    NOT NULL DEFAULT 0.00,
  is_flexible  TINYINT(1)       NOT NULL DEFAULT 0,
  due_day      TINYINT UNSIGNED NULL,
  PRIMARY KEY (entry_id),
  UNIQUE KEY uq_ee_budget_cat (budget_id, category_id),
  KEY ix_ee_cat (category_id),
  CONSTRAINT fk_ee_budget   FOREIGN KEY (budget_id)   REFERENCES monthly_budgets(budget_id) ON DELETE CASCADE,
  CONSTRAINT fk_ee_category FOREIGN KEY (category_id) REFERENCES expense_categories(category_id),
  CONSTRAINT ck_ee_amount CHECK (amount >= 0 AND amount <= 9999999999.99),
  CONSTRAINT ck_ee_due_day CHECK (due_day IS NULL OR due_day BETWEEN 1 AND 31)
) ENGINE=InnoDB;

-- =====================================================================
-- SECTION 4 — GOALS
-- =====================================================================

-- [UI] Goal cards + Target (₹) + Deadline + Priority (1-5). One goal per type per user,
-- exactly as the UI works today (see data_dictionary.md for how to relax this later).
CREATE TABLE financial_goals (
  goal_id        BIGINT UNSIGNED  NOT NULL AUTO_INCREMENT,
  user_id        BIGINT UNSIGNED  NOT NULL,
  goal_type_id   TINYINT UNSIGNED NOT NULL,
  target_amount  DECIMAL(12,2)    NULL,                           -- UI allows a blank target
  deadline       DATE             NULL,                           -- UI allows a blank deadline
  priority       TINYINT UNSIGNED NOT NULL DEFAULT 3,
  status         ENUM('active','achieved','paused','cancelled') NOT NULL DEFAULT 'active',
  created_at     TIMESTAMP        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at     TIMESTAMP        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (goal_id),
  UNIQUE KEY uq_fg_user_type (user_id, goal_type_id),
  KEY ix_fg_type (goal_type_id),
  CONSTRAINT fk_fg_user FOREIGN KEY (user_id)      REFERENCES users(user_id) ON DELETE CASCADE,
  CONSTRAINT fk_fg_type FOREIGN KEY (goal_type_id) REFERENCES goal_types(goal_type_id),
  CONSTRAINT ck_fg_target   CHECK (target_amount IS NULL OR (target_amount > 0 AND target_amount <= 9999999999.99)),
  CONSTRAINT ck_fg_priority CHECK (priority BETWEEN 1 AND 5)
) ENGINE=InnoDB;

-- [PHASE-2] The UI has no "amount saved so far" field, so goal PROGRESS cannot be computed
-- from today's frontend. This table makes progress possible once the UI records deposits.
CREATE TABLE goal_contributions (
  contribution_id  BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  goal_id          BIGINT UNSIGNED NOT NULL,
  amount           DECIMAL(12,2)   NOT NULL,
  contributed_on   DATE            NOT NULL,
  note             VARCHAR(200)    NULL,
  created_at       TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (contribution_id),
  KEY ix_gc_goal_date (goal_id, contributed_on),
  CONSTRAINT fk_gc_goal FOREIGN KEY (goal_id) REFERENCES financial_goals(goal_id) ON DELETE CASCADE,
  CONSTRAINT ck_gc_amount CHECK (amount > 0 AND amount <= 9999999999.99)
) ENGINE=InnoDB;

-- [PHASE-2] The UI has NO per-transaction entry (only monthly totals per category).
-- This optional ledger supports "transaction history / recent transactions".
CREATE TABLE transactions (
  txn_id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id             BIGINT UNSIGNED NOT NULL,
  txn_type            ENUM('income','expense') NOT NULL,
  income_category_id  SMALLINT UNSIGNED NULL,
  category_id         INT UNSIGNED      NULL,
  amount              DECIMAL(12,2)   NOT NULL,
  txn_date            DATE            NOT NULL,
  description         VARCHAR(200)    NULL,
  created_at          TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (txn_id),
  KEY ix_tx_user_date (user_id, txn_date),
  KEY ix_tx_category (category_id),
  KEY ix_tx_income_category (income_category_id),
  CONSTRAINT fk_tx_user    FOREIGN KEY (user_id)            REFERENCES users(user_id) ON DELETE CASCADE,
  CONSTRAINT fk_tx_expcat  FOREIGN KEY (category_id)        REFERENCES expense_categories(category_id),
  CONSTRAINT fk_tx_inccat  FOREIGN KEY (income_category_id) REFERENCES income_categories(income_category_id),
  CONSTRAINT ck_tx_amount  CHECK (amount > 0 AND amount <= 9999999999.99),
  CONSTRAINT ck_tx_type_cat CHECK (
       (txn_type = 'income'  AND income_category_id IS NOT NULL AND category_id IS NULL)
    OR (txn_type = 'expense' AND category_id IS NOT NULL AND income_category_id IS NULL))
) ENGINE=InnoDB;

-- =====================================================================
-- SECTION 5 — RECOMMENDATIONS (history of what Cortex AI suggested)
-- =====================================================================

-- [UI] Each time the user opens "Cortex AI Recommendations" one row is produced.
-- remaining_money is a SNAPSHOT of the financial base used (income - expenses, floored at 0).
CREATE TABLE recommendations (
  recommendation_id  BIGINT UNSIGNED  NOT NULL AUTO_INCREMENT,
  user_id            BIGINT UNSIGNED  NOT NULL,
  budget_id          BIGINT UNSIGNED  NULL,
  strategy_id        TINYINT UNSIGNED NOT NULL,
  risk_preference    ENUM('conservative','moderate','aggressive') NOT NULL,
  lifestyle_pct      TINYINT UNSIGNED NOT NULL,
  remaining_money    DECIMAL(12,2)    NOT NULL,
  input_snapshot     JSON             NULL,                       -- goals / interests / preferences used
  engine_version     VARCHAR(40)      NOT NULL DEFAULT 'rules-v1',
  status             ENUM('generated','applied','dismissed') NOT NULL DEFAULT 'generated',
  created_at         TIMESTAMP        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  applied_at         TIMESTAMP        NULL,
  PRIMARY KEY (recommendation_id),
  KEY ix_rec_user_created (user_id, created_at),
  KEY ix_rec_budget (budget_id),
  KEY ix_rec_strategy (strategy_id),
  CONSTRAINT fk_rec_user     FOREIGN KEY (user_id)     REFERENCES users(user_id) ON DELETE CASCADE,
  CONSTRAINT fk_rec_budget   FOREIGN KEY (budget_id)   REFERENCES monthly_budgets(budget_id) ON DELETE SET NULL,
  CONSTRAINT fk_rec_strategy FOREIGN KEY (strategy_id) REFERENCES strategies(strategy_id),
  CONSTRAINT ck_rec_money    CHECK (remaining_money >= 0),
  CONSTRAINT ck_rec_lifestyle CHECK (lifestyle_pct BETWEEN 0 AND 60)
) ENGINE=InnoDB;

-- [UI] "Allocation manifest" + donut chart
CREATE TABLE recommendation_allocations (
  recommendation_id  BIGINT UNSIGNED  NOT NULL,
  bucket_id          TINYINT UNSIGNED NOT NULL,
  weight_pct         DECIMAL(5,2)     NOT NULL,
  amount             DECIMAL(12,2)    NOT NULL,
  PRIMARY KEY (recommendation_id, bucket_id),
  KEY ix_ra_bucket (bucket_id),
  CONSTRAINT fk_ra_rec    FOREIGN KEY (recommendation_id) REFERENCES recommendations(recommendation_id) ON DELETE CASCADE,
  CONSTRAINT fk_ra_bucket FOREIGN KEY (bucket_id)         REFERENCES allocation_buckets(bucket_id),
  CONSTRAINT ck_ra_weight CHECK (weight_pct BETWEEN 0 AND 100),
  CONSTRAINT ck_ra_amount CHECK (amount >= 0)
) ENGINE=InnoDB;

-- [UI] "Why this recommendation?" bars (Goal 30 / Risk 25 / Budget 20 / Performance 15 / Interest 10)
CREATE TABLE recommendation_factors (
  recommendation_id  BIGINT UNSIGNED NOT NULL,
  factor             ENUM('financial_goal','risk_compatibility','available_budget','previous_performance','user_interest') NOT NULL,
  weight_pct         DECIMAL(5,2)    NOT NULL,
  PRIMARY KEY (recommendation_id, factor),
  CONSTRAINT fk_rf_rec FOREIGN KEY (recommendation_id) REFERENCES recommendations(recommendation_id) ON DELETE CASCADE,
  CONSTRAINT ck_rf_weight CHECK (weight_pct BETWEEN 0 AND 100)
) ENGINE=InnoDB;

-- [UI] "Cortex Insight" cards
CREATE TABLE recommendation_insights (
  insight_id         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  recommendation_id  BIGINT UNSIGNED NOT NULL,
  insight_type       ENUM('spending','goal','performance','risk','next_month') NOT NULL,
  title              VARCHAR(80)     NOT NULL,
  body               VARCHAR(500)    NOT NULL,
  PRIMARY KEY (insight_id),
  KEY ix_ri_rec (recommendation_id),
  CONSTRAINT fk_ri_rec FOREIGN KEY (recommendation_id) REFERENCES recommendations(recommendation_id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- =====================================================================
-- SECTION 6 — MONTHLY PLANS ("Allocation Manifest & Planner", Lock & Execute)
-- =====================================================================

-- [UI] One plan per user per TARGET month. remaining_money = the allocation base
-- (disposable income). Allocations are calculated from it, NOT from gross income.
CREATE TABLE monthly_plans (
  plan_id               BIGINT UNSIGNED  NOT NULL AUTO_INCREMENT,
  user_id               BIGINT UNSIGNED  NOT NULL,
  budget_id             BIGINT UNSIGNED  NULL,                    -- the month the base was calculated from
  recommendation_id     BIGINT UNSIGNED  NULL,
  strategy_id           TINYINT UNSIGNED NOT NULL,
  next_month_action_id  TINYINT UNSIGNED NULL,                    -- Continue / Modify / Review
  plan_month            DATE             NOT NULL,                -- 1st of the month the plan will run
  remaining_money       DECIMAL(12,2)    NOT NULL,
  risk_preference       ENUM('conservative','moderate','aggressive') NOT NULL,
  lifestyle_pct         TINYINT UNSIGNED NOT NULL DEFAULT 15,
  is_customized         TINYINT(1)       NOT NULL DEFAULT 0,
  status                ENUM('draft','locked','executed','cancelled') NOT NULL DEFAULT 'draft',
  locked_at             TIMESTAMP        NULL,
  created_at            TIMESTAMP        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at            TIMESTAMP        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (plan_id),
  UNIQUE KEY uq_mp_user_month (user_id, plan_month),
  KEY ix_mp_budget (budget_id),
  KEY ix_mp_rec (recommendation_id),
  KEY ix_mp_strategy (strategy_id),
  KEY ix_mp_action (next_month_action_id),
  CONSTRAINT fk_mp_user     FOREIGN KEY (user_id)              REFERENCES users(user_id) ON DELETE CASCADE,
  CONSTRAINT fk_mp_budget   FOREIGN KEY (budget_id)            REFERENCES monthly_budgets(budget_id) ON DELETE SET NULL,
  CONSTRAINT fk_mp_rec      FOREIGN KEY (recommendation_id)    REFERENCES recommendations(recommendation_id) ON DELETE SET NULL,
  CONSTRAINT fk_mp_strategy FOREIGN KEY (strategy_id)          REFERENCES strategies(strategy_id),
  CONSTRAINT fk_mp_action   FOREIGN KEY (next_month_action_id) REFERENCES next_month_actions(action_id),
  CONSTRAINT ck_mp_first_of_month CHECK (DAYOFMONTH(plan_month) = 1),
  CONSTRAINT ck_mp_money     CHECK (remaining_money >= 0),
  CONSTRAINT ck_mp_lifestyle CHECK (lifestyle_pct BETWEEN 0 AND 60)
) ENGINE=InnoDB;

-- [UI] Planner table: Category | Baseline | AI Adjustment | Proposed Total | Priority
-- Proposed % is derived: allocated_amount / monthly_plans.remaining_money.
CREATE TABLE plan_allocations (
  plan_id           BIGINT UNSIGNED  NOT NULL,
  bucket_id         TINYINT UNSIGNED NOT NULL,
  baseline_pct      DECIMAL(5,2)     NOT NULL,
  adjustment_pct    DECIMAL(5,2)     NOT NULL DEFAULT 0.00,
  allocated_amount  DECIMAL(12,2)    NOT NULL,
  priority          ENUM('High','Medium','Low') NOT NULL DEFAULT 'Medium',
  PRIMARY KEY (plan_id, bucket_id),
  KEY ix_pa_bucket (bucket_id),
  CONSTRAINT fk_pa_plan   FOREIGN KEY (plan_id)   REFERENCES monthly_plans(plan_id) ON DELETE CASCADE,
  CONSTRAINT fk_pa_bucket FOREIGN KEY (bucket_id) REFERENCES allocation_buckets(bucket_id),
  CONSTRAINT ck_pa_baseline CHECK (baseline_pct BETWEEN 0 AND 100),
  CONSTRAINT ck_pa_adjust   CHECK (adjustment_pct BETWEEN -100 AND 100),
  CONSTRAINT ck_pa_amount   CHECK (allocated_amount >= 0)
) ENGINE=InnoDB;

-- [UI] Financial History page: Amount | Previous Value | Current Value | Result.
-- closing_value stays NULL for spend buckets (Entertainment, Shopping, Others) -> UI shows "Expense".
CREATE TABLE allocation_valuations (
  plan_id        BIGINT UNSIGNED  NOT NULL,
  bucket_id      TINYINT UNSIGNED NOT NULL,
  opening_value  DECIMAL(12,2)    NOT NULL,
  closing_value  DECIMAL(12,2)    NULL,
  valued_on      DATE             NULL,
  PRIMARY KEY (plan_id, bucket_id),
  CONSTRAINT fk_av_alloc FOREIGN KEY (plan_id, bucket_id) REFERENCES plan_allocations(plan_id, bucket_id) ON DELETE CASCADE,
  CONSTRAINT ck_av_values CHECK (opening_value >= 0 AND (closing_value IS NULL OR closing_value >= 0))
) ENGINE=InnoDB;

-- =====================================================================
-- SECTION 7 — AUDIT LOG (security-relevant events; written by triggers + backend)
-- =====================================================================
CREATE TABLE audit_logs (
  log_id       BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id      BIGINT UNSIGNED NULL,
  action       VARCHAR(50)     NOT NULL,            -- e.g. LOGIN_FAILED, PLAN_LOCKED, ACCOUNT_DELETION_REQUESTED
  entity_type  VARCHAR(40)     NULL,
  entity_id    BIGINT UNSIGNED NULL,
  details      JSON            NULL,                -- never put passwords/tokens in here
  ip_address   VARCHAR(45)     NULL,
  created_at   TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (log_id),
  KEY ix_al_user_created (user_id, created_at),
  KEY ix_al_action_created (action, created_at),
  CONSTRAINT fk_al_user FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE SET NULL
) ENGINE=InnoDB;

-- =====================================================================
-- SECTION 8 — INTEGRITY TRIGGERS & PROCEDURES
-- Only rules that plain constraints cannot express are implemented here:
--  (a) cross-table USER ISOLATION (a row may only reference the same user's data)
--  (b) plan lifecycle (draft -> locked -> executed) and "locked plans are immutable"
-- Cascaded FK deletes do NOT fire triggers in MySQL, so account deletion is unaffected.
-- =====================================================================
DELIMITER $$

-- (a1) expense category must be a system category valid for the user's role, or the user's own custom one
CREATE PROCEDURE sp_assert_expense_category_access(IN p_user_id BIGINT UNSIGNED, IN p_category_id INT UNSIGNED)
BEGIN
  DECLARE v_owner BIGINT UNSIGNED;
  DECLARE v_found INT DEFAULT 0;
  DECLARE v_role VARCHAR(10);
  SELECT COUNT(*), MAX(user_id) INTO v_found, v_owner FROM expense_categories WHERE category_id = p_category_id;
  IF v_found = 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Unknown expense category';
  END IF;
  IF v_owner IS NOT NULL THEN
    IF v_owner <> p_user_id THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Expense category belongs to another user';
    END IF;
  ELSE
    SELECT role INTO v_role FROM users WHERE user_id = p_user_id;
    IF NOT EXISTS (SELECT 1 FROM role_expense_categories WHERE role = v_role AND category_id = p_category_id) THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Expense category is not available for this user role';
    END IF;
  END IF;
END$$

-- (a2) income category must apply to the user's role
CREATE PROCEDURE sp_assert_income_category_access(IN p_user_id BIGINT UNSIGNED, IN p_income_category_id SMALLINT UNSIGNED)
BEGIN
  DECLARE v_role VARCHAR(10);
  SELECT role INTO v_role FROM users WHERE user_id = p_user_id;
  IF NOT EXISTS (SELECT 1 FROM income_categories
                 WHERE income_category_id = p_income_category_id AND applies_to IN ('both', v_role)) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Income category is not available for this user role';
  END IF;
END$$

CREATE TRIGGER trg_expense_entries_bi BEFORE INSERT ON expense_entries FOR EACH ROW
BEGIN
  DECLARE v_user BIGINT UNSIGNED;
  SELECT user_id INTO v_user FROM monthly_budgets WHERE budget_id = NEW.budget_id;
  CALL sp_assert_expense_category_access(v_user, NEW.category_id);
END$$
CREATE TRIGGER trg_expense_entries_bu BEFORE UPDATE ON expense_entries FOR EACH ROW
BEGIN
  DECLARE v_user BIGINT UNSIGNED;
  IF NEW.budget_id <> OLD.budget_id OR NEW.category_id <> OLD.category_id THEN
    SELECT user_id INTO v_user FROM monthly_budgets WHERE budget_id = NEW.budget_id;
    CALL sp_assert_expense_category_access(v_user, NEW.category_id);
  END IF;
END$$

CREATE TRIGGER trg_income_entries_bi BEFORE INSERT ON income_entries FOR EACH ROW
BEGIN
  DECLARE v_user BIGINT UNSIGNED;
  SELECT user_id INTO v_user FROM monthly_budgets WHERE budget_id = NEW.budget_id;
  CALL sp_assert_income_category_access(v_user, NEW.income_category_id);
END$$
CREATE TRIGGER trg_income_entries_bu BEFORE UPDATE ON income_entries FOR EACH ROW
BEGIN
  DECLARE v_user BIGINT UNSIGNED;
  IF NEW.budget_id <> OLD.budget_id OR NEW.income_category_id <> OLD.income_category_id THEN
    SELECT user_id INTO v_user FROM monthly_budgets WHERE budget_id = NEW.budget_id;
    CALL sp_assert_income_category_access(v_user, NEW.income_category_id);
  END IF;
END$$

CREATE TRIGGER trg_transactions_bi BEFORE INSERT ON transactions FOR EACH ROW
BEGIN
  IF NEW.txn_type = 'expense' THEN
    CALL sp_assert_expense_category_access(NEW.user_id, NEW.category_id);
  ELSE
    CALL sp_assert_income_category_access(NEW.user_id, NEW.income_category_id);
  END IF;
END$$
CREATE TRIGGER trg_transactions_bu BEFORE UPDATE ON transactions FOR EACH ROW
BEGIN
  IF NEW.user_id <> OLD.user_id THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'A transaction cannot be moved to another user';
  END IF;
  IF NEW.txn_type = 'expense' THEN
    CALL sp_assert_expense_category_access(NEW.user_id, NEW.category_id);
  ELSE
    CALL sp_assert_income_category_access(NEW.user_id, NEW.income_category_id);
  END IF;
END$$

-- (a3) recommendations may only point at the same user's budget
CREATE TRIGGER trg_recommendations_bi BEFORE INSERT ON recommendations FOR EACH ROW
BEGIN
  IF NEW.budget_id IS NOT NULL AND
     NOT EXISTS (SELECT 1 FROM monthly_budgets WHERE budget_id = NEW.budget_id AND user_id = NEW.user_id) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Budget belongs to another user';
  END IF;
END$$
CREATE TRIGGER trg_recommendations_bu BEFORE UPDATE ON recommendations FOR EACH ROW
BEGIN
  IF NEW.user_id <> OLD.user_id THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'A recommendation cannot be moved to another user';
  END IF;
  IF NEW.budget_id IS NOT NULL AND
     NOT EXISTS (SELECT 1 FROM monthly_budgets WHERE budget_id = NEW.budget_id AND user_id = NEW.user_id) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Budget belongs to another user';
  END IF;
END$$

-- (a3 + b) monthly plans: same-user references, valid status transitions, lock only if not over-allocated
CREATE TRIGGER trg_monthly_plans_bi BEFORE INSERT ON monthly_plans FOR EACH ROW
BEGIN
  IF NEW.status <> 'draft' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'New plans must start as draft (add allocations, then lock)';
  END IF;
  IF NEW.budget_id IS NOT NULL AND
     NOT EXISTS (SELECT 1 FROM monthly_budgets WHERE budget_id = NEW.budget_id AND user_id = NEW.user_id) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Budget belongs to another user';
  END IF;
  IF NEW.recommendation_id IS NOT NULL AND
     NOT EXISTS (SELECT 1 FROM recommendations WHERE recommendation_id = NEW.recommendation_id AND user_id = NEW.user_id) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Recommendation belongs to another user';
  END IF;
END$$

CREATE TRIGGER trg_monthly_plans_bu BEFORE UPDATE ON monthly_plans FOR EACH ROW
BEGIN
  DECLARE v_alloc DECIMAL(14,2);
  IF NEW.user_id <> OLD.user_id THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'A plan cannot be moved to another user';
  END IF;
  IF NEW.budget_id IS NOT NULL AND NOT (NEW.budget_id <=> OLD.budget_id) AND
     NOT EXISTS (SELECT 1 FROM monthly_budgets WHERE budget_id = NEW.budget_id AND user_id = NEW.user_id) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Budget belongs to another user';
  END IF;
  IF NEW.recommendation_id IS NOT NULL AND NOT (NEW.recommendation_id <=> OLD.recommendation_id) AND
     NOT EXISTS (SELECT 1 FROM recommendations WHERE recommendation_id = NEW.recommendation_id AND user_id = NEW.user_id) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Recommendation belongs to another user';
  END IF;
  -- locked / executed / cancelled plans cannot have their money base or month changed
  IF OLD.status <> 'draft' AND (NEW.remaining_money <> OLD.remaining_money OR NEW.plan_month <> OLD.plan_month
                                OR NEW.strategy_id <> OLD.strategy_id) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Locked plans are immutable: unlock (back to draft) before editing';
  END IF;
  IF NEW.status <> OLD.status THEN
    IF NOT ( (OLD.status = 'draft'  AND NEW.status IN ('locked','cancelled'))
          OR (OLD.status = 'locked' AND NEW.status IN ('draft','executed','cancelled')) ) THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invalid plan status transition';
    END IF;
    IF NEW.status = 'locked' THEN
      SELECT COALESCE(SUM(allocated_amount), 0) INTO v_alloc FROM plan_allocations WHERE plan_id = OLD.plan_id;
      IF v_alloc > NEW.remaining_money THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cannot lock: allocations exceed remaining money';
      END IF;
      SET NEW.locked_at = CURRENT_TIMESTAMP;
    END IF;
    IF NEW.status = 'draft' THEN
      SET NEW.locked_at = NULL;
    END IF;
  END IF;
END$$

CREATE TRIGGER trg_monthly_plans_au AFTER UPDATE ON monthly_plans FOR EACH ROW
BEGIN
  IF NEW.status <> OLD.status THEN
    INSERT INTO audit_logs (user_id, action, entity_type, entity_id, details)
    VALUES (NEW.user_id, CONCAT('PLAN_', UPPER(NEW.status)), 'monthly_plan', NEW.plan_id,
            JSON_OBJECT('from', OLD.status, 'to', NEW.status, 'plan_month', NEW.plan_month));
  END IF;
END$$

-- (b) allocation rows can only be edited while the parent plan is a draft
CREATE TRIGGER trg_plan_alloc_bi BEFORE INSERT ON plan_allocations FOR EACH ROW
BEGIN
  IF (SELECT status FROM monthly_plans WHERE plan_id = NEW.plan_id) <> 'draft' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Plan is locked: allocations cannot be added';
  END IF;
END$$
CREATE TRIGGER trg_plan_alloc_bu BEFORE UPDATE ON plan_allocations FOR EACH ROW
BEGIN
  IF NEW.plan_id <> OLD.plan_id THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'An allocation cannot move to another plan';
  END IF;
  IF (SELECT status FROM monthly_plans WHERE plan_id = OLD.plan_id) <> 'draft' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Plan is locked: allocations cannot be changed';
  END IF;
END$$
CREATE TRIGGER trg_plan_alloc_bd BEFORE DELETE ON plan_allocations FOR EACH ROW
BEGIN
  IF (SELECT status FROM monthly_plans WHERE plan_id = OLD.plan_id) <> 'draft' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Plan is locked: allocations cannot be deleted';
  END IF;
END$$

-- Makes a plain "DELETE FROM users WHERE user_id = ?" work. Without this, MySQL's cascade order can try to
-- delete a user's custom expense category BEFORE the entries that use it and fail with error 1451.
CREATE TRIGGER trg_users_bd BEFORE DELETE ON users FOR EACH ROW
BEGIN
  DELETE FROM transactions       WHERE user_id = OLD.user_id;
  DELETE FROM monthly_budgets    WHERE user_id = OLD.user_id;   -- cascades income/expense entries
  DELETE FROM expense_categories WHERE user_id = OLD.user_id;   -- now safe: nothing references them
END$$

-- ---------------------------------------------------------------------
-- Account deletion & data retention
-- Flow: backend calls sp_request_account_deletion -> user is locked out immediately ->
--       a scheduled job calls sp_purge_deleted_accounts(30) to erase after the grace period.
-- ---------------------------------------------------------------------
CREATE PROCEDURE sp_request_account_deletion(IN p_user_id BIGINT UNSIGNED)
BEGIN
  UPDATE users SET status = 'pending_deletion', deletion_requested_at = CURRENT_TIMESTAMP
   WHERE user_id = p_user_id AND status <> 'pending_deletion';
  UPDATE user_sessions SET revoked_at = CURRENT_TIMESTAMP WHERE user_id = p_user_id AND revoked_at IS NULL;
  DELETE FROM password_reset_tokens WHERE user_id = p_user_id;
  INSERT INTO audit_logs (user_id, action, entity_type, entity_id)
  VALUES (p_user_id, 'ACCOUNT_DELETION_REQUESTED', 'user', p_user_id);
END$$

-- Hard-deletes ONE user and ALL their data, in an order that never trips RESTRICT foreign keys.
CREATE PROCEDURE sp_delete_user_account(IN p_user_id BIGINT UNSIGNED)
BEGIN
  DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;
  START TRANSACTION;
  DELETE FROM transactions       WHERE user_id = p_user_id;
  DELETE FROM monthly_plans      WHERE user_id = p_user_id;   -- cascades allocations + valuations
  DELETE FROM recommendations    WHERE user_id = p_user_id;   -- cascades allocations, factors, insights
  DELETE FROM monthly_budgets    WHERE user_id = p_user_id;   -- cascades income/expense entries
  DELETE FROM expense_categories WHERE user_id = p_user_id;   -- the user's custom categories
  DELETE FROM users              WHERE user_id = p_user_id;   -- cascades profile, prefs, goals, sessions, tokens
  -- audit_logs rows are kept but anonymised automatically (FK is ON DELETE SET NULL)
  INSERT INTO audit_logs (user_id, action, entity_type, entity_id, details)
  VALUES (NULL, 'ACCOUNT_DELETED', 'user', p_user_id, JSON_OBJECT('purged_at', NOW()));
  COMMIT;
END$$

CREATE PROCEDURE sp_purge_deleted_accounts(IN p_retention_days INT)
BEGIN
  DECLARE v_done INT DEFAULT 0;
  DECLARE v_uid BIGINT UNSIGNED;
  DECLARE cur CURSOR FOR
    SELECT user_id FROM users
     WHERE status = 'pending_deletion'
       AND deletion_requested_at < (CURRENT_TIMESTAMP - INTERVAL p_retention_days DAY);
  DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = 1;
  OPEN cur;
  purge_loop: LOOP
    FETCH cur INTO v_uid;
    IF v_done = 1 THEN LEAVE purge_loop; END IF;
    CALL sp_delete_user_account(v_uid);
  END LOOP;
  CLOSE cur;
END$$

-- Housekeeping: remove expired/used tokens and old sessions (run daily) + trim audit log (run monthly)
CREATE PROCEDURE sp_purge_expired_security_data(IN p_audit_retention_days INT)
BEGIN
  DELETE FROM password_reset_tokens WHERE expires_at < CURRENT_TIMESTAMP OR used_at IS NOT NULL;
  DELETE FROM user_sessions WHERE expires_at < (CURRENT_TIMESTAMP - INTERVAL 7 DAY) OR revoked_at < (CURRENT_TIMESTAMP - INTERVAL 7 DAY);
  DELETE FROM audit_logs WHERE created_at < (CURRENT_TIMESTAMP - INTERVAL p_audit_retention_days DAY);
END$$

-- Convenience wrapper: lock a plan, but only if it belongs to p_user_id (authorization inside the call)
CREATE PROCEDURE sp_lock_plan(IN p_plan_id BIGINT UNSIGNED, IN p_user_id BIGINT UNSIGNED)
BEGIN
  IF NOT EXISTS (SELECT 1 FROM monthly_plans WHERE plan_id = p_plan_id AND user_id = p_user_id) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Plan not found for this user';
  END IF;
  UPDATE monthly_plans SET status = 'locked' WHERE plan_id = p_plan_id AND user_id = p_user_id;
END$$

DELIMITER ;

-- =====================================================================
-- SECTION 9 — VIEWS (read-only helpers; they do NOT enforce user isolation:
--             the backend must ALWAYS add WHERE user_id = <authenticated user>)
-- =====================================================================

-- Income, expenses, remaining money and deficit per user-month.
-- remaining_money mirrors the frontend: Math.max(0, income - expenses).
CREATE VIEW v_monthly_summary AS
SELECT b.budget_id, b.user_id, b.budget_month,
       COALESCE(i.total_income, 0)   AS total_income,
       COALESCE(e.total_expenses, 0) AS total_expenses,
       GREATEST(COALESCE(i.total_income, 0) - COALESCE(e.total_expenses, 0), 0) AS remaining_money,
       GREATEST(COALESCE(e.total_expenses, 0) - COALESCE(i.total_income, 0), 0) AS deficit
  FROM monthly_budgets b
  LEFT JOIN (SELECT budget_id, SUM(amount) AS total_income   FROM income_entries  GROUP BY budget_id) i ON i.budget_id = b.budget_id
  LEFT JOIN (SELECT budget_id, SUM(amount) AS total_expenses FROM expense_entries GROUP BY budget_id) e ON e.budget_id = b.budget_id;

-- Planner "Allocated ₹X / ₹Y" live bar
CREATE VIEW v_plan_allocation_totals AS
SELECT p.plan_id, p.user_id, p.plan_month, p.status, p.remaining_money,
       COALESCE(SUM(a.allocated_amount), 0)                       AS allocated_total,
       p.remaining_money - COALESCE(SUM(a.allocated_amount), 0)   AS unallocated,
       CASE WHEN p.remaining_money > 0
            THEN ROUND(100 * COALESCE(SUM(a.allocated_amount), 0) / p.remaining_money, 2) ELSE 0 END AS allocated_pct
  FROM monthly_plans p
  LEFT JOIN plan_allocations a ON a.plan_id = p.plan_id
 GROUP BY p.plan_id, p.user_id, p.plan_month, p.status, p.remaining_money;

-- =====================================================================
-- SECTION 10 — REFERENCE DATA (needed for the app to work; contains no user data)
-- IDs are fixed on purpose: user_profiles.preferred_strategy_id defaults to 2 (balanced).
-- =====================================================================
INSERT INTO strategies (strategy_id, code, name, description) VALUES
 (1,'conservative','Conservative Strategy','Prioritizes essentials and aggressive debt reduction.'),
 (2,'balanced','Balanced Strategy','Applies a standard split across essentials, savings, and personal goals.'),
 (3,'accelerated','Accelerated Goal Strategy','Aggressively cuts discretionary spend to fund high-priority goals.');

INSERT INTO allocation_buckets (bucket_id, code, name, description, color_hex, bucket_group, sort_order) VALUES
 (1,'savings','Savings','Liquid emergency buffer','#3B82F6','saving',1),
 (2,'fd','Fixed Deposit','Locked-in, low-risk growth','#22D3EE','investment',2),
 (3,'rd','Recurring Deposit','Disciplined monthly investing','#5EEAD4','saving',3),
 (4,'stocks','Stocks','Market-linked, higher risk','#F92E92','investment',4),
 (5,'crypto','Crypto','High-risk, high-volatility','#A855F7','investment',5),
 (6,'chits','Chits','Community pooled savings','#818CF8','saving',6),
 (7,'entertainment','Entertainment','Movies, dining, leisure','#FBBF24','lifestyle',7),
 (8,'shopping','Shopping','Lifestyle & personal purchases','#C084FC','lifestyle',8),
 (9,'others','Others','Miscellaneous / uncategorized','#94A3B8','other',9);

-- weights in bucket order: savings, fd, rd, stocks, crypto, chits, entertainment, shopping, others
INSERT INTO strategy_bucket_weights (strategy_id, bucket_id, weight_pct) VALUES
 (1,1,30),(1,2,20),(1,3,10),(1,4,5),(1,5,0),(1,6,5),(1,7,10),(1,8,10),(1,9,10),
 (2,1,20),(2,2,15),(2,3,10),(2,4,15),(2,5,5),(2,6,5),(2,7,12),(2,8,13),(2,9,5),
 (3,1,35),(3,2,10),(3,3,5),(3,4,20),(3,5,10),(3,6,0),(3,7,5),(3,8,5),(3,9,10);

INSERT INTO strategy_rationales (strategy_id, sort_order, rationale) VALUES
 (1,1,'Boosts Savings and Fixed Deposit to build a safety net first.'),
 (1,2,'Trims discretionary Shopping and Entertainment to speed up debt payoff.'),
 (1,3,'Keeps Crypto exposure at zero to avoid volatility.'),
 (2,1,'Spreads money evenly across safety, growth and lifestyle buckets.'),
 (2,2,'Keeps a modest Crypto and Stocks exposure for long-term growth.'),
 (2,3,'Leaves room for day-to-day discretionary spending.'),
 (3,1,'Shifts a larger share into Savings and Stocks to fund your top-priority goal faster.'),
 (3,2,'Temporarily trims Entertainment and Shopping to free up more money.'),
 (3,3,'Adds Crypto exposure for higher (riskier) growth potential.');

INSERT INTO next_month_actions (action_id, code, title, badge, description) VALUES
 (1,'continue','Continue','Recommended','Your previous allocation performed positively. You may consider maintaining a similar allocation next month.'),
 (2,'modify','Modify','Rebalance','One allocation was roughly flat. A small shift toward your top goal could help next month.'),
 (3,'review','Review / Reduce','Caution','This allocation experienced a decline. Consider reviewing it before making a similar decision.');

-- tweaks in bucket order (1..9)
INSERT INTO next_month_action_tweaks (action_id, bucket_id, tweak_pct) VALUES
 (1,1,0),(1,2,0),(1,3,0),(1,4,0),(1,5,0),(1,6,0),(1,7,0),(1,8,0),(1,9,0),
 (2,1,5),(2,2,5),(2,3,0),(2,4,-5),(2,5,0),(2,6,0),(2,7,-5),(2,8,0),(2,9,0),
 (3,1,10),(3,2,5),(3,3,0),(3,4,-15),(3,5,-5),(3,6,0),(3,7,0),(3,8,0),(3,9,5);

INSERT INTO expense_category_groups (group_id, name, sort_order) VALUES
 (1,'Regular Bills',1),(2,'Debt & Obligations',2),(3,'Subscriptions & Insurance',3),(4,'Student Essentials',4);

INSERT INTO income_categories (income_category_id, code, name, applies_to, sort_order) VALUES
 (1,'salary','Monthly Salary','employee',1),
 (2,'allowance','Monthly Allowance','student',1),
 (3,'scholarship','Scholarship','student',2),
 (4,'other_income','Other Income','both',9);

-- System expense categories (user_id NULL). Only 'entertainment' is classed discretionary.
INSERT INTO expense_categories (category_id, user_id, code, name, nature) VALUES
 (1,NULL,'rent','Rent','essential'),
 (2,NULL,'electricity','Electricity','essential'),
 (3,NULL,'water','Water','essential'),
 (4,NULL,'food','Food','essential'),
 (5,NULL,'transport','Transportation','essential'),
 (6,NULL,'insurance_emi','Insurance / EMI','essential'),
 (7,NULL,'other_regular','Other Regular Bills','essential'),
 (8,NULL,'credit_card','Credit Card Bills','essential'),
 (9,NULL,'student_loan','Student Loans','essential'),
 (10,NULL,'gas','Gas','essential'),
 (11,NULL,'groceries','Groceries','essential'),
 (12,NULL,'recharges','Recharges (Mobile, Wi-Fi, TV)','essential'),
 (13,NULL,'auto_insurance','Auto Insurance','essential'),
 (14,NULL,'health_insurance','Health Insurance','essential'),
 (15,NULL,'home_insurance','Home Insurance','essential'),
 (16,NULL,'education','Education','essential'),
 (17,NULL,'travel','Travel','essential'),
 (18,NULL,'entertainment','Entertainment','discretionary'),
 (19,NULL,'personal_needs','Personal Needs','essential'),
 (20,NULL,'other_expenses','Other Expenses','essential');

INSERT INTO role_expense_categories (role, category_id, group_id, sort_order) VALUES
 ('employee',1,1,1),('employee',2,1,2),('employee',3,1,3),('employee',4,1,4),('employee',5,1,5),('employee',6,1,6),('employee',7,1,7),
 ('employee',8,2,1),('employee',9,2,2),('employee',10,2,3),('employee',11,2,4),('employee',12,2,5),
 ('employee',13,3,1),('employee',14,3,2),('employee',15,3,3),
 ('student',16,4,1),('student',4,4,2),('student',17,4,3),('student',18,4,4),('student',19,4,5),('student',20,4,6),
 ('student',8,2,1),('student',9,2,2),('student',10,2,3),('student',11,2,4),('student',12,2,5),
 ('student',13,3,1),('student',14,3,2),('student',15,3,3);

INSERT INTO goal_types (goal_type_id, code, name, icon, sort_order) VALUES
 (1,'education','Education','🎓',1),(2,'vacation','Vacation / Travel','✈️',2),(3,'purchase','Major Purchase','🛍️',3),
 (4,'emergency','Emergency Fund','🛟',4),(5,'longterm','Long-Term Savings','🌱',5),(6,'investment','Investment Portfolio','📈',6),
 (7,'skill','Skill Development','🧠',7),(8,'buying','Buying (Home / Car / Plot)','🏠',8),(9,'others','Others','✳️',9);

INSERT INTO interest_options (kind, name, sort_order) VALUES
 ('lifestyle','Shopping',1),('lifestyle','Movies',2),('lifestyle','Entertainment',3),
 ('lifestyle','Travel',4),('lifestyle','Lifestyle',5),('lifestyle','Personal Needs',6),
 ('financial','Savings',1),('financial','Fixed Deposit',2),('financial','Recurring Deposit',3),
 ('financial','Stocks',4),('financial','Cryptocurrency',5),('financial','Other Financial Goals',6);

INSERT INTO schema_migrations (version, description) VALUES ('001','Initial schema, triggers, views and reference data');

-- ---------------------------------------------------------------------
-- Initial configuration notes
--  * Recommended server sql_mode (default in MySQL 8): STRICT_TRANS_TABLES,ONLY_FULL_GROUP_BY,... keep it ON.
--  * Run the app connection with time_zone='+00:00' so TIMESTAMPs are UTC.
--  * Application users/roles are created by security.sql (run separately, as admin).
-- ---------------------------------------------------------------------
SELECT 'cortex_ai schema created' AS status,
       (SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='cortex_ai' AND table_type='BASE TABLE') AS tables_created;
