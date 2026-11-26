# Cortex AI — Data Dictionary

Generated from the live `cortex_ai` MySQL 8.0 database (schema.sql version 001). Every table and column is listed.

Legend: **[UI]** = used by the current frontend · **[PHASE-2]** = not in the current frontend, needed for transaction history / goal progress · *Reference* = managed by DBA/migrations, read-only for the app.

All money columns are `DECIMAL(12,2)` (rupees). All timestamps are UTC. All tables: InnoDB, utf8mb4 / utf8mb4_0900_ai_ci.

## Contents

- [`allocation_buckets`](#allocation_buckets) — Reference
- [`expense_category_groups`](#expense_category_groups) — Reference
- [`goal_types`](#goal_types) — Reference
- [`income_categories`](#income_categories) — Reference
- [`interest_options`](#interest_options) — Reference
- [`next_month_action_tweaks`](#next_month_action_tweaks) — Reference
- [`next_month_actions`](#next_month_actions) — Reference
- [`role_expense_categories`](#role_expense_categories) — Reference
- [`strategies`](#strategies) — Reference
- [`strategy_bucket_weights`](#strategy_bucket_weights) — Reference
- [`strategy_rationales`](#strategy_rationales) — Reference
- [`expense_categories`](#expense_categories) — Reference + user
- [`user_interests`](#user_interests) — User
- [`user_preferences`](#user_preferences) — User
- [`user_profiles`](#user_profiles) — User
- [`users`](#users) — User
- [`audit_logs`](#audit_logs) — Security
- [`password_reset_tokens`](#password_reset_tokens) — Security
- [`user_sessions`](#user_sessions) — Security
- [`schema_migrations`](#schema_migrations) — System
- [`allocation_valuations`](#allocation_valuations) — Financial
- [`expense_entries`](#expense_entries) — Financial
- [`financial_goals`](#financial_goals) — Financial
- [`income_entries`](#income_entries) — Financial
- [`monthly_budgets`](#monthly_budgets) — Financial
- [`monthly_plans`](#monthly_plans) — Financial
- [`plan_allocations`](#plan_allocations) — Financial
- [`goal_contributions`](#goal_contributions) — Financial [PHASE-2]
- [`transactions`](#transactions) — Financial [PHASE-2]
- [`recommendation_allocations`](#recommendation_allocations) — AI
- [`recommendation_factors`](#recommendation_factors) — AI
- [`recommendation_insights`](#recommendation_insights) — AI
- [`recommendations`](#recommendations) — AI

---

## `allocation_buckets`

**Area:** Reference  
**Purpose:** The 9 places money can be allocated (Savings, Fixed Deposit ... Others).  
**Frontend source:** Allocation Manifest, planner, history

| Column | Type | Null | Default | Key | Description |
|---|---|---|---|---|---|
| `bucket_id` | `tinyint unsigned` | NO | auto-increment | PK | Primary key. |
| `code` | `varchar(20)` | NO | — |  | Stable machine-readable key (never shown to users; safe for code to reference). |
| `name` | `varchar(40)` | NO | — |  | Display name shown in the UI. |
| `description` | `varchar(120)` | YES | — |  | Short descriptive text. |
| `color_hex` | `char(7)` | NO | — |  | Chart colour, #RRGGBB. |
| `bucket_group` | `enum('saving','investment','lifestyle','other')` | NO | — |  | saving / investment / lifestyle / other. DB-side classification used by dashboard queries. |
| `sort_order` | `tinyint unsigned` | NO | — |  | Display order in the UI. |

**Primary key:** (bucket_id)  
**Unique constraints:** `uq_ab_code` (code)  

**CHECK constraints**

- `ck_ab_color`: `regexp_like(`color_hex`,_utf8mb4\\'^#[0-9A-Fa-f]{6}$\\')`

---

## `expense_category_groups`

**Area:** Reference  
**Purpose:** Headings that group expense lines (Regular Bills, Debt & Obligations, ...).  
**Frontend source:** Income & Expenses page

| Column | Type | Null | Default | Key | Description |
|---|---|---|---|---|---|
| `group_id` | `tinyint unsigned` | NO | auto-increment | PK | Primary key. |
| `name` | `varchar(60)` | NO | — |  | Display name shown in the UI. |
| `sort_order` | `tinyint unsigned` | NO | 0 |  | Display order in the UI. |

**Primary key:** (group_id)  
**Unique constraints:** `uq_ecg_name` (name)  

---

## `goal_types`

**Area:** Reference  
**Purpose:** The goal cards a user can pick (Education, Vacation, Emergency Fund ...).  
**Frontend source:** Money, Goals & Interests page

| Column | Type | Null | Default | Key | Description |
|---|---|---|---|---|---|
| `goal_type_id` | `tinyint unsigned` | NO | auto-increment | PK | Primary key. |
| `code` | `varchar(20)` | NO | — |  | Stable machine-readable key (never shown to users; safe for code to reference). |
| `name` | `varchar(60)` | NO | — |  | Display name shown in the UI. |
| `icon` | `varchar(8)` | YES | — |  | Emoji shown on the goal card. |
| `sort_order` | `tinyint unsigned` | NO | 0 |  | Display order in the UI. |

**Primary key:** (goal_type_id)  
**Unique constraints:** `uq_gt_code` (code)  

---

## `income_categories`

**Area:** Reference  
**Purpose:** Income sources a user can enter (salary, allowance, scholarship, other).  
**Frontend source:** Income card

| Column | Type | Null | Default | Key | Description |
|---|---|---|---|---|---|
| `income_category_id` | `smallint unsigned` | NO | auto-increment | PK | Primary key. |
| `code` | `varchar(30)` | NO | — |  | Stable machine-readable key (never shown to users; safe for code to reference). |
| `name` | `varchar(60)` | NO | — |  | Display name shown in the UI. |
| `applies_to` | `enum('employee','student','both')` | NO | — |  | Role this income source is shown to: employee, student or both. |
| `sort_order` | `tinyint unsigned` | NO | 0 |  | Display order in the UI. |
| `is_active` | `tinyint(1)` | NO | 1 |  | 0 = hidden. |

**Primary key:** (income_category_id)  
**Unique constraints:** `uq_ic_code` (code); `uq_ic_name` (name)  

---

## `interest_options`

**Area:** Reference  
**Purpose:** Lifestyle-interest and financial-preference chips.  
**Frontend source:** Money, Goals & Interests page

| Column | Type | Null | Default | Key | Description |
|---|---|---|---|---|---|
| `interest_id` | `smallint unsigned` | NO | auto-increment | PK | Primary key. |
| `kind` | `enum('lifestyle','financial')` | NO | — |  | lifestyle or financial. |
| `name` | `varchar(40)` | NO | — |  | Display name shown in the UI. |
| `sort_order` | `tinyint unsigned` | NO | 0 |  | Display order in the UI. |

**Primary key:** (interest_id)  
**Unique constraints:** `uq_io_kind_name` (kind, name)  

---

## `next_month_action_tweaks`

**Area:** Reference  
**Purpose:** Percentage-point shift each action applies to each bucket.  
**Frontend source:** Next Month page

| Column | Type | Null | Default | Key | Description |
|---|---|---|---|---|---|
| `action_id` | `tinyint unsigned` | NO | — | PK, FK | Action. |
| `bucket_id` | `tinyint unsigned` | NO | — | PK, FK | Bucket. |
| `tweak_pct` | `decimal(5,2)` | NO | 0.00 |  | Signed percentage-point change (-100..100). |

**Foreign keys & delete behaviour**

- `action_id` → `next_month_actions.action_id` — ON DELETE **NO ACTION** (parent cannot be deleted while referenced (same as RESTRICT)); ON UPDATE RESTRICT (surrogate keys never change)
- `bucket_id` → `allocation_buckets.bucket_id` — ON DELETE **NO ACTION** (parent cannot be deleted while referenced (same as RESTRICT)); ON UPDATE RESTRICT (surrogate keys never change)

**Primary key:** (action_id, bucket_id)  
**Indexes:** `fk_nmat_bucket` (bucket_id)  

**CHECK constraints**

- `ck_nmat_tweak`: `(`tweak_pct` between -(100) and 100)`

---

## `next_month_actions`

**Area:** Reference  
**Purpose:** Continue / Modify / Review-Reduce choices.  
**Frontend source:** Next Month page

| Column | Type | Null | Default | Key | Description |
|---|---|---|---|---|---|
| `action_id` | `tinyint unsigned` | NO | auto-increment | PK | Primary key. |
| `code` | `varchar(20)` | NO | — |  | Stable machine-readable key (never shown to users; safe for code to reference). |
| `title` | `varchar(40)` | NO | — |  | Card title. |
| `badge` | `varchar(20)` | NO | — |  | Small label (Recommended / Rebalance / Caution). |
| `description` | `varchar(250)` | NO | — |  | Short descriptive text. |

**Primary key:** (action_id)  
**Unique constraints:** `uq_nma_code` (code)  

---

## `role_expense_categories`

**Area:** Reference  
**Purpose:** Which system expense lines each role sees, under which heading and in what order.  
**Frontend source:** Student vs Employee expense lists

| Column | Type | Null | Default | Key | Description |
|---|---|---|---|---|---|
| `role` | `enum('employee','student')` | NO | — | PK | employee or student. |
| `category_id` | `int unsigned` | NO | — | PK, FK | System expense category. |
| `group_id` | `tinyint unsigned` | NO | — | FK | Heading the category appears under for this role (Food is under Regular Bills for employees, Student Essentials for students). |
| `sort_order` | `tinyint unsigned` | NO | 0 |  | Display order in the UI. |

**Foreign keys & delete behaviour**

- `category_id` → `expense_categories.category_id` — ON DELETE **NO ACTION** (parent cannot be deleted while referenced (same as RESTRICT)); ON UPDATE RESTRICT (surrogate keys never change)
- `group_id` → `expense_category_groups.group_id` — ON DELETE **NO ACTION** (parent cannot be deleted while referenced (same as RESTRICT)); ON UPDATE RESTRICT (surrogate keys never change)

**Primary key:** (role, category_id)  
**Indexes:** `fk_rec_category` (category_id); `fk_rec_group` (group_id)  

---

## `strategies`

**Area:** Reference  
**Purpose:** The three recommendation strategies (Conservative, Balanced, Accelerated Goal).  
**Frontend source:** Cortex AI Recommendations

| Column | Type | Null | Default | Key | Description |
|---|---|---|---|---|---|
| `strategy_id` | `tinyint unsigned` | NO | auto-increment | PK | Primary key (2 = balanced is the profile default). |
| `code` | `varchar(20)` | NO | — |  | Stable machine-readable key (never shown to users; safe for code to reference). |
| `name` | `varchar(60)` | NO | — |  | Display name shown in the UI. |
| `description` | `varchar(200)` | NO | — |  | Short descriptive text. |

**Primary key:** (strategy_id)  
**Unique constraints:** `uq_st_code` (code)  

---

## `strategy_bucket_weights`

**Area:** Reference  
**Purpose:** Baseline % each strategy gives each bucket. Must sum to 100 per strategy.  
**Frontend source:** Recommendation engine

| Column | Type | Null | Default | Key | Description |
|---|---|---|---|---|---|
| `strategy_id` | `tinyint unsigned` | NO | — | PK, FK | Strategy. |
| `bucket_id` | `tinyint unsigned` | NO | — | PK, FK | Bucket. |
| `weight_pct` | `decimal(5,2)` | NO | — |  | Baseline percentage (0-100). Each strategy sums to 100. |

**Foreign keys & delete behaviour**

- `bucket_id` → `allocation_buckets.bucket_id` — ON DELETE **NO ACTION** (parent cannot be deleted while referenced (same as RESTRICT)); ON UPDATE RESTRICT (surrogate keys never change)
- `strategy_id` → `strategies.strategy_id` — ON DELETE **NO ACTION** (parent cannot be deleted while referenced (same as RESTRICT)); ON UPDATE RESTRICT (surrogate keys never change)

**Primary key:** (strategy_id, bucket_id)  
**Indexes:** `fk_sbw_bucket` (bucket_id)  

**CHECK constraints**

- `ck_sbw_pct`: `(`weight_pct` between 0 and 100)`

---

## `strategy_rationales`

**Area:** Reference  
**Purpose:** "Why did Cortex AI suggest this?" bullet text per strategy.  
**Frontend source:** Recommendation page

| Column | Type | Null | Default | Key | Description |
|---|---|---|---|---|---|
| `strategy_id` | `tinyint unsigned` | NO | — | PK, FK | Strategy. |
| `sort_order` | `tinyint unsigned` | NO | — | PK | Display order in the UI. |
| `rationale` | `varchar(250)` | NO | — |  | One bullet of explanation text. |

**Foreign keys & delete behaviour**

- `strategy_id` → `strategies.strategy_id` — ON DELETE **NO ACTION** (parent cannot be deleted while referenced (same as RESTRICT)); ON UPDATE RESTRICT (surrogate keys never change)

**Primary key:** (strategy_id, sort_order)  

---

## `expense_categories`

**Area:** Reference + user  
**Purpose:** System expense lines (user_id NULL) and each user's own custom lines.  
**Frontend source:** Essential Expenses card, "+ Add Custom Line"

| Column | Type | Null | Default | Key | Description |
|---|---|---|---|---|---|
| `category_id` | `int unsigned` | NO | auto-increment | PK | Surrogate primary key. |
| `user_id` | `bigint unsigned` | YES | — | FK | NULL = system category; otherwise the owning user (custom line). |
| `code` | `varchar(40)` | YES | — |  | Stable key for system rows (rent, food ...); NULL for custom lines. |
| `name` | `varchar(80)` | NO | — |  | Display name shown in the UI. |
| `nature` | `enum('essential','discretionary')` | NO | essential |  | essential or discretionary. NOT in the UI (it calls every line essential); used by analytics. Only Entertainment is discretionary. |
| `is_active` | `tinyint(1)` | NO | 1 |  | 0 = hidden/retired. Used instead of deleting a category that has history. |
| `owner_scope` | `bigint unsigned` | YES | generated |  | Generated: user_id or 0. Makes (owner, name) unique even for system rows. |
| `created_at` | `timestamp` | NO | CURRENT_TIMESTAMP |  | When the row was created (UTC). |

**Foreign keys & delete behaviour**

- `user_id` → `users.user_id` — ON DELETE **CASCADE** (child rows are deleted with the parent); ON UPDATE RESTRICT (surrogate keys never change)

**Primary key:** (category_id)  
**Unique constraints:** `uq_ec_code` (code); `uq_ec_owner_name` (owner_scope, name)  
**Indexes:** `ix_ec_user` (user_id)  

---

## `user_interests`

**Area:** User  
**Purpose:** Which interest chips a user selected (many-to-many).  
**Frontend source:** Money, Goals & Interests page

| Column | Type | Null | Default | Key | Description |
|---|---|---|---|---|---|
| `user_id` | `bigint unsigned` | NO | — | PK, FK | User. |
| `interest_id` | `smallint unsigned` | NO | — | PK, FK | Chosen chip. |

**Foreign keys & delete behaviour**

- `interest_id` → `interest_options.interest_id` — ON DELETE **NO ACTION** (parent cannot be deleted while referenced (same as RESTRICT)); ON UPDATE RESTRICT (surrogate keys never change)
- `user_id` → `users.user_id` — ON DELETE **CASCADE** (child rows are deleted with the parent); ON UPDATE RESTRICT (surrogate keys never change)

**Primary key:** (user_id, interest_id)  
**Indexes:** `fk_ui_interest` (interest_id)  

---

## `user_preferences`

**Area:** User  
**Purpose:** Appearance settings (1:1 with users). Today stored in browser localStorage.  
**Frontend source:** Settings > Appearance

| Column | Type | Null | Default | Key | Description |
|---|---|---|---|---|---|
| `user_id` | `bigint unsigned` | NO | — | PK, FK | Owner (1:1 with users). |
| `theme_mode` | `enum('dark','light','system')` | NO | dark |  | dark / light / system. |
| `accent` | `enum('pink','blue','purple','cyan')` | NO | pink |  | pink / blue / purple / cyan. |
| `font_size` | `enum('small','medium','large')` | NO | medium |  | small / medium / large. |
| `card_style` | `enum('glass','solid')` | NO | glass |  | glass / solid. |
| `text_contrast` | `enum('normal','enhanced','maximum')` | NO | normal |  | normal / enhanced / maximum. |
| `high_contrast` | `tinyint(1)` | NO | 0 |  | High-contrast mode on/off. |
| `sparks` | `tinyint(1)` | NO | 1 |  | Spark animation on/off. |
| `glow` | `tinyint(1)` | NO | 1 |  | Glow effect on/off. |
| `reduce_motion` | `tinyint(1)` | NO | 0 |  | Reduce-motion on/off. |
| `updated_at` | `timestamp` | NO | CURRENT_TIMESTAMP (auto-updates) |  | When the row was last changed (UTC, automatic). |

**Foreign keys & delete behaviour**

- `user_id` → `users.user_id` — ON DELETE **CASCADE** (child rows are deleted with the parent); ON UPDATE RESTRICT (surrogate keys never change)

**Primary key:** (user_id)  

---

## `user_profiles`

**Area:** User  
**Purpose:** Risk preference, lifestyle slider and chosen strategy (1:1 with users).  
**Frontend source:** Money, Goals & Interests page

| Column | Type | Null | Default | Key | Description |
|---|---|---|---|---|---|
| `user_id` | `bigint unsigned` | NO | — | PK, FK | Owner (1:1 with users). |
| `risk_preference` | `enum('conservative','moderate','aggressive')` | NO | moderate |  | conservative / moderate / aggressive. |
| `lifestyle_pct` | `tinyint unsigned` | NO | 15 |  | Lifestyle slider value, 0-60 (%). |
| `preferred_strategy_id` | `tinyint unsigned` | NO | 2 | FK | Strategy selected on the profile page. |
| `updated_at` | `timestamp` | NO | CURRENT_TIMESTAMP (auto-updates) |  | When the row was last changed (UTC, automatic). |

**Foreign keys & delete behaviour**

- `preferred_strategy_id` → `strategies.strategy_id` — ON DELETE **NO ACTION** (parent cannot be deleted while referenced (same as RESTRICT)); ON UPDATE RESTRICT (surrogate keys never change)
- `user_id` → `users.user_id` — ON DELETE **CASCADE** (child rows are deleted with the parent); ON UPDATE RESTRICT (surrogate keys never change)

**Primary key:** (user_id)  
**Indexes:** `fk_up_strategy` (preferred_strategy_id)  

**CHECK constraints**

- `ck_up_lifestyle`: `(`lifestyle_pct` between 0 and 60)`

---

## `users`

**Area:** User  
**Purpose:** One row per account: login identity, role, lifecycle status.  
**Frontend source:** Login, Create Account, Profile

| Column | Type | Null | Default | Key | Description |
|---|---|---|---|---|---|
| `user_id` | `bigint unsigned` | NO | auto-increment | PK | Internal primary key. Never expose in URLs/APIs. |
| `public_id` | `char(36)` | NO | UUID() |  | Random UUID safe to expose in APIs/URLs. |
| `email` | `varchar(254)` | NO | — |  | Login email, unique case-insensitively. |
| `password_hash` | `varchar(255)` | NO | — |  | argon2id/bcrypt hash produced by the backend. Never a plaintext password. |
| `full_name` | `varchar(100)` | NO | — |  | Display name. |
| `role` | `enum('employee','student')` | NO | — |  | employee or student. Decides which income/expense fields the user sees. |
| `status` | `enum('active','suspended','pending_deletion')` | NO | active |  | active, suspended or pending_deletion. |
| `is_demo` | `tinyint(1)` | NO | 0 |  | 1 = fictional demo account from seed.sql. Delete before production. |
| `email_verified_at` | `timestamp` | YES | — |  | When the email was verified (NULL = not verified). |
| `failed_login_count` | `tinyint unsigned` | NO | 0 |  | Consecutive failed logins (reset on success). |
| `locked_until` | `timestamp` | YES | — |  | Login blocked until this time after too many failures. |
| `last_login_at` | `timestamp` | YES | — |  | Most recent successful login. |
| `deletion_requested_at` | `timestamp` | YES | — |  | When the user asked to delete their account (starts the retention clock). |
| `created_at` | `timestamp` | NO | CURRENT_TIMESTAMP |  | When the row was created (UTC). |
| `updated_at` | `timestamp` | NO | CURRENT_TIMESTAMP (auto-updates) |  | When the row was last changed (UTC, automatic). |

**Primary key:** (user_id)  
**Unique constraints:** `uq_users_email` (email); `uq_users_public_id` (public_id)  
**Indexes:** `ix_users_status` (status, deletion_requested_at)  

**CHECK constraints**

- `ck_users_email`: `regexp_like(`email`,_utf8mb4\\'^[^@[:space:]]+@[^@[:space:]]+\\\\\\\\.[^@[:space:]]+$\\')`
- `ck_users_name`: `(char_length(trim(`full_name`)) > 0)`
- `ck_users_pwhash`: `(char_length(`password_hash`) >= 50)`

---

## `audit_logs`

**Area:** Security  
**Purpose:** Append-only record of security-relevant events.  
**Frontend source:** —  (backend + triggers)

| Column | Type | Null | Default | Key | Description |
|---|---|---|---|---|---|
| `log_id` | `bigint unsigned` | NO | auto-increment | PK | Primary key. |
| `user_id` | `bigint unsigned` | YES | — | FK | Actor; becomes NULL when the account is deleted (anonymised). |
| `action` | `varchar(50)` | NO | — |  | Event name, e.g. PLAN_LOCKED. |
| `entity_type` | `varchar(40)` | YES | — |  | Kind of object affected. |
| `entity_id` | `bigint unsigned` | YES | — |  | Id of that object. |
| `details` | `json` | YES | — |  | JSON detail. Never put passwords or tokens here. |
| `ip_address` | `varchar(45)` | YES | — |  | Client IP if known. |
| `created_at` | `timestamp` | NO | CURRENT_TIMESTAMP |  | When the row was created (UTC). |

**Foreign keys & delete behaviour**

- `user_id` → `users.user_id` — ON DELETE **SET NULL** (column becomes NULL, row is kept); ON UPDATE RESTRICT (surrogate keys never change)

**Primary key:** (log_id)  
**Indexes:** `ix_al_action_created` (action, created_at); `ix_al_user_created` (user_id, created_at)  

---

## `password_reset_tokens`

**Area:** Security  
**Purpose:** One-time password-reset tokens (hashed).  
**Frontend source:** "Forgot password?" link

| Column | Type | Null | Default | Key | Description |
|---|---|---|---|---|---|
| `token_id` | `bigint unsigned` | NO | auto-increment | PK | Primary key. |
| `user_id` | `bigint unsigned` | NO | — | FK | Account being reset. |
| `token_hash` | `char(64)` | NO | — |  | SHA-256 hex of the emailed token. |
| `created_at` | `timestamp` | NO | CURRENT_TIMESTAMP |  | When the row was created (UTC). |
| `expires_at` | `timestamp` | NO | — |  | Token expiry. |
| `used_at` | `timestamp` | YES | — |  | Set when consumed (single use). |

**Foreign keys & delete behaviour**

- `user_id` → `users.user_id` — ON DELETE **CASCADE** (child rows are deleted with the parent); ON UPDATE RESTRICT (surrogate keys never change)

**Primary key:** (token_id)  
**Unique constraints:** `uq_prt_token` (token_hash)  
**Indexes:** `ix_prt_user` (user_id)  

---

## `user_sessions`

**Area:** Security  
**Purpose:** Server-side login sessions; only a hash of the refresh token is stored.  
**Frontend source:** Replaces sessionStorage "cortexSession"

| Column | Type | Null | Default | Key | Description |
|---|---|---|---|---|---|
| `session_id` | `bigint unsigned` | NO | auto-increment | PK | Primary key. |
| `user_id` | `bigint unsigned` | NO | — | FK | Session owner. |
| `refresh_token_hash` | `char(64)` | NO | — |  | SHA-256 hex of the refresh token (the token itself is never stored). |
| `user_agent` | `varchar(255)` | YES | — |  | Browser/device string. |
| `ip_address` | `varchar(45)` | YES | — |  | Client IP (IPv4/IPv6). |
| `created_at` | `timestamp` | NO | CURRENT_TIMESTAMP |  | When the row was created (UTC). |
| `expires_at` | `timestamp` | NO | — |  | Session expiry. |
| `revoked_at` | `timestamp` | YES | — |  | Set on logout / revoke. |

**Foreign keys & delete behaviour**

- `user_id` → `users.user_id` — ON DELETE **CASCADE** (child rows are deleted with the parent); ON UPDATE RESTRICT (surrogate keys never change)

**Primary key:** (session_id)  
**Unique constraints:** `uq_us_token` (refresh_token_hash)  
**Indexes:** `ix_us_user` (user_id, revoked_at, expires_at)  

---

## `schema_migrations`

**Area:** System  
**Purpose:** Records which database migration files have been applied.  
**Frontend source:** —  (deployment tooling)

| Column | Type | Null | Default | Key | Description |
|---|---|---|---|---|---|
| `version` | `varchar(20)` | NO | — | PK | Migration number, e.g. 001. |
| `description` | `varchar(200)` | NO | — |  | Short descriptive text. |
| `applied_at` | `timestamp` | NO | CURRENT_TIMESTAMP |  | When it was applied. |

**Primary key:** (version)  

---

## `allocation_valuations`

**Area:** Financial  
**Purpose:** Opening and closing value of an allocation after the month ends.  
**Frontend source:** Financial History page

| Column | Type | Null | Default | Key | Description |
|---|---|---|---|---|---|
| `plan_id` | `bigint unsigned` | NO | — | PK, FK | Plan. |
| `bucket_id` | `tinyint unsigned` | NO | — | PK, FK | Bucket. |
| `opening_value` | `decimal(12,2)` | NO | — |  | Value at start of the month (normally = allocated_amount). |
| `closing_value` | `decimal(12,2)` | YES | — |  | Value at month end; NULL for spend buckets (UI shows "Expense"). |
| `valued_on` | `date` | YES | — |  | Date the closing value was recorded. |

**Foreign keys & delete behaviour**

- `plan_id` → `plan_allocations.plan_id` — ON DELETE **CASCADE** (child rows are deleted with the parent); ON UPDATE RESTRICT (surrogate keys never change)
- `bucket_id` → `plan_allocations.bucket_id` — ON DELETE **CASCADE** (child rows are deleted with the parent); ON UPDATE RESTRICT (surrogate keys never change)

**Primary key:** (plan_id, bucket_id)  

**CHECK constraints**

- `ck_av_values`: `((`opening_value` >= 0) and ((`closing_value` is null) or (`closing_value` >= 0)))`

---

## `expense_entries`

**Area:** Financial  
**Purpose:** Amount, flexible flag and due day per expense line per month.  
**Frontend source:** Essential Expenses card

| Column | Type | Null | Default | Key | Description |
|---|---|---|---|---|---|
| `entry_id` | `bigint unsigned` | NO | auto-increment | PK | Primary key. |
| `budget_id` | `bigint unsigned` | NO | — | FK | Month. |
| `category_id` | `int unsigned` | NO | — | FK | Expense line. |
| `amount` | `decimal(12,2)` | NO | 0.00 |  | Rupees for the month (>= 0). |
| `is_flexible` | `tinyint(1)` | NO | 0 |  | 1 = the "Flexible" toggle is on (amount can be reduced). |
| `due_day` | `tinyint unsigned` | YES | — |  | Day of month the bill is due (1-31) or NULL. |

**Foreign keys & delete behaviour**

- `budget_id` → `monthly_budgets.budget_id` — ON DELETE **CASCADE** (child rows are deleted with the parent); ON UPDATE RESTRICT (surrogate keys never change)
- `category_id` → `expense_categories.category_id` — ON DELETE **NO ACTION** (parent cannot be deleted while referenced (same as RESTRICT)); ON UPDATE RESTRICT (surrogate keys never change)

**Primary key:** (entry_id)  
**Unique constraints:** `uq_ee_budget_cat` (budget_id, category_id)  
**Indexes:** `ix_ee_cat` (category_id)  

**CHECK constraints**

- `ck_ee_amount`: `((`amount` >= 0) and (`amount` <= 9999999999.99))`
- `ck_ee_due_day`: `((`due_day` is null) or (`due_day` between 1 and 31))`

---

## `financial_goals`

**Area:** Financial  
**Purpose:** A user's goals with target, deadline, priority.  
**Frontend source:** Money, Goals & Interests page

| Column | Type | Null | Default | Key | Description |
|---|---|---|---|---|---|
| `goal_id` | `bigint unsigned` | NO | auto-increment | PK | Primary key. |
| `user_id` | `bigint unsigned` | NO | — | FK | Owner. |
| `goal_type_id` | `tinyint unsigned` | NO | — | FK | Which goal card. One per type per user. |
| `target_amount` | `decimal(12,2)` | YES | — |  | Target in rupees; NULL if the user left it blank. |
| `deadline` | `date` | YES | — |  | Target date; NULL if blank. |
| `priority` | `tinyint unsigned` | NO | 3 |  | 1 (lowest) to 5 (highest). |
| `status` | `enum('active','achieved','paused','cancelled')` | NO | active |  | active / achieved / paused / cancelled. |
| `created_at` | `timestamp` | NO | CURRENT_TIMESTAMP |  | When the row was created (UTC). |
| `updated_at` | `timestamp` | NO | CURRENT_TIMESTAMP (auto-updates) |  | When the row was last changed (UTC, automatic). |

**Foreign keys & delete behaviour**

- `goal_type_id` → `goal_types.goal_type_id` — ON DELETE **NO ACTION** (parent cannot be deleted while referenced (same as RESTRICT)); ON UPDATE RESTRICT (surrogate keys never change)
- `user_id` → `users.user_id` — ON DELETE **CASCADE** (child rows are deleted with the parent); ON UPDATE RESTRICT (surrogate keys never change)

**Primary key:** (goal_id)  
**Unique constraints:** `uq_fg_user_type` (user_id, goal_type_id)  
**Indexes:** `ix_fg_type` (goal_type_id)  

**CHECK constraints**

- `ck_fg_priority`: `(`priority` between 1 and 5)`
- `ck_fg_target`: `((`target_amount` is null) or ((`target_amount` > 0) and (`target_amount` <= 9999999999.99)))`

---

## `income_entries`

**Area:** Financial  
**Purpose:** Amount per income source per month.  
**Frontend source:** Income card

| Column | Type | Null | Default | Key | Description |
|---|---|---|---|---|---|
| `entry_id` | `bigint unsigned` | NO | auto-increment | PK | Primary key. |
| `budget_id` | `bigint unsigned` | NO | — | FK | Month this income belongs to. |
| `income_category_id` | `smallint unsigned` | NO | — | FK | Income source. |
| `amount` | `decimal(12,2)` | NO | 0.00 |  | Rupees for the month (>= 0). |

**Foreign keys & delete behaviour**

- `budget_id` → `monthly_budgets.budget_id` — ON DELETE **CASCADE** (child rows are deleted with the parent); ON UPDATE RESTRICT (surrogate keys never change)
- `income_category_id` → `income_categories.income_category_id` — ON DELETE **NO ACTION** (parent cannot be deleted while referenced (same as RESTRICT)); ON UPDATE RESTRICT (surrogate keys never change)

**Primary key:** (entry_id)  
**Unique constraints:** `uq_ie_budget_cat` (budget_id, income_category_id)  
**Indexes:** `ix_ie_cat` (income_category_id)  

**CHECK constraints**

- `ck_ie_amount`: `((`amount` >= 0) and (`amount` <= 9999999999.99))`

---

## `monthly_budgets`

**Area:** Financial  
**Purpose:** One row per user per month; parent of that month's income and expense lines.  
**Frontend source:** Income & Expenses, Monthly Analysis

| Column | Type | Null | Default | Key | Description |
|---|---|---|---|---|---|
| `budget_id` | `bigint unsigned` | NO | auto-increment | PK | Primary key. |
| `user_id` | `bigint unsigned` | NO | — | FK | Owner. |
| `budget_month` | `date` | NO | — |  | First day of the month. |
| `created_at` | `timestamp` | NO | CURRENT_TIMESTAMP |  | When the row was created (UTC). |
| `updated_at` | `timestamp` | NO | CURRENT_TIMESTAMP (auto-updates) |  | When the row was last changed (UTC, automatic). |

**Foreign keys & delete behaviour**

- `user_id` → `users.user_id` — ON DELETE **CASCADE** (child rows are deleted with the parent); ON UPDATE RESTRICT (surrogate keys never change)

**Primary key:** (budget_id)  
**Unique constraints:** `uq_mb_user_month` (user_id, budget_month)  

**CHECK constraints**

- `ck_mb_first_of_month`: `(dayofmonth(`budget_month`) = 1)`

---

## `monthly_plans`

**Area:** Financial  
**Purpose:** The user's plan for a target month (draft -> locked -> executed).  
**Frontend source:** Allocation Manifest & Planner, Lock & Execute

| Column | Type | Null | Default | Key | Description |
|---|---|---|---|---|---|
| `plan_id` | `bigint unsigned` | NO | auto-increment | PK | Primary key. |
| `user_id` | `bigint unsigned` | NO | — | FK | Owner. |
| `budget_id` | `bigint unsigned` | YES | — | FK | Month the base was calculated from (NULL if deleted). |
| `recommendation_id` | `bigint unsigned` | YES | — | FK | Recommendation this plan came from (NULL if none/deleted). |
| `strategy_id` | `tinyint unsigned` | NO | — | FK | Base strategy. |
| `next_month_action_id` | `tinyint unsigned` | YES | — | FK | Continue / Modify / Review choice, if used. |
| `plan_month` | `date` | NO | — |  | First day of the month the plan runs in. |
| `remaining_money` | `decimal(12,2)` | NO | — |  | THE ALLOCATION BASE: disposable income (income - expenses, floored at 0) frozen when the plan was made. |
| `risk_preference` | `enum('conservative','moderate','aggressive')` | NO | — |  | Risk preference used. |
| `lifestyle_pct` | `tinyint unsigned` | NO | 15 |  | Lifestyle slider used. |
| `is_customized` | `tinyint(1)` | NO | 0 |  | 1 = user changed allocations by hand. |
| `status` | `enum('draft','locked','executed','cancelled')` | NO | draft |  | draft -> locked -> executed (or cancelled). Locked/executed plans are immutable. |
| `locked_at` | `timestamp` | YES | — |  | Set automatically when locked. |
| `created_at` | `timestamp` | NO | CURRENT_TIMESTAMP |  | When the row was created (UTC). |
| `updated_at` | `timestamp` | NO | CURRENT_TIMESTAMP (auto-updates) |  | When the row was last changed (UTC, automatic). |

**Foreign keys & delete behaviour**

- `next_month_action_id` → `next_month_actions.action_id` — ON DELETE **NO ACTION** (parent cannot be deleted while referenced (same as RESTRICT)); ON UPDATE RESTRICT (surrogate keys never change)
- `budget_id` → `monthly_budgets.budget_id` — ON DELETE **SET NULL** (column becomes NULL, row is kept); ON UPDATE RESTRICT (surrogate keys never change)
- `recommendation_id` → `recommendations.recommendation_id` — ON DELETE **SET NULL** (column becomes NULL, row is kept); ON UPDATE RESTRICT (surrogate keys never change)
- `strategy_id` → `strategies.strategy_id` — ON DELETE **NO ACTION** (parent cannot be deleted while referenced (same as RESTRICT)); ON UPDATE RESTRICT (surrogate keys never change)
- `user_id` → `users.user_id` — ON DELETE **CASCADE** (child rows are deleted with the parent); ON UPDATE RESTRICT (surrogate keys never change)

**Primary key:** (plan_id)  
**Unique constraints:** `uq_mp_user_month` (user_id, plan_month)  
**Indexes:** `ix_mp_action` (next_month_action_id); `ix_mp_budget` (budget_id); `ix_mp_rec` (recommendation_id); `ix_mp_strategy` (strategy_id)  

**CHECK constraints**

- `ck_mp_first_of_month`: `(dayofmonth(`plan_month`) = 1)`
- `ck_mp_lifestyle`: `(`lifestyle_pct` between 0 and 60)`
- `ck_mp_money`: `(`remaining_money` >= 0)`

---

## `plan_allocations`

**Area:** Financial  
**Purpose:** Amount, baseline %, AI adjustment and priority per bucket in a plan.  
**Frontend source:** Planner table

| Column | Type | Null | Default | Key | Description |
|---|---|---|---|---|---|
| `plan_id` | `bigint unsigned` | NO | — | PK, FK | Plan. |
| `bucket_id` | `tinyint unsigned` | NO | — | PK, FK | Bucket. |
| `baseline_pct` | `decimal(5,2)` | NO | — |  | Strategy baseline % (0-100). |
| `adjustment_pct` | `decimal(5,2)` | NO | 0.00 |  | AI/user adjustment in percentage points (-100..100). |
| `allocated_amount` | `decimal(12,2)` | NO | — |  | Rupees allocated (>= 0). Proposed % = this / plan remaining_money. |
| `priority` | `enum('High','Medium','Low')` | NO | Medium |  | High / Medium / Low. |

**Foreign keys & delete behaviour**

- `bucket_id` → `allocation_buckets.bucket_id` — ON DELETE **NO ACTION** (parent cannot be deleted while referenced (same as RESTRICT)); ON UPDATE RESTRICT (surrogate keys never change)
- `plan_id` → `monthly_plans.plan_id` — ON DELETE **CASCADE** (child rows are deleted with the parent); ON UPDATE RESTRICT (surrogate keys never change)

**Primary key:** (plan_id, bucket_id)  
**Indexes:** `ix_pa_bucket` (bucket_id)  

**CHECK constraints**

- `ck_pa_adjust`: `(`adjustment_pct` between -(100) and 100)`
- `ck_pa_amount`: `(`allocated_amount` >= 0)`
- `ck_pa_baseline`: `(`baseline_pct` between 0 and 100)`

---

## `goal_contributions`

**Area:** Financial [PHASE-2]  
**Purpose:** Money put toward a goal. Needed to compute goal progress.  
**Frontend source:** NOT in current UI

| Column | Type | Null | Default | Key | Description |
|---|---|---|---|---|---|
| `contribution_id` | `bigint unsigned` | NO | auto-increment | PK | Primary key. |
| `goal_id` | `bigint unsigned` | NO | — | FK | Goal funded. |
| `amount` | `decimal(12,2)` | NO | — |  | Rupees added (> 0). |
| `contributed_on` | `date` | NO | — |  | Date of the contribution. |
| `note` | `varchar(200)` | YES | — |  | Optional free text. |
| `created_at` | `timestamp` | NO | CURRENT_TIMESTAMP |  | When the row was created (UTC). |

**Foreign keys & delete behaviour**

- `goal_id` → `financial_goals.goal_id` — ON DELETE **CASCADE** (child rows are deleted with the parent); ON UPDATE RESTRICT (surrogate keys never change)

**Primary key:** (contribution_id)  
**Indexes:** `ix_gc_goal_date` (goal_id, contributed_on)  

**CHECK constraints**

- `ck_gc_amount`: `((`amount` > 0) and (`amount` <= 9999999999.99))`

---

## `transactions`

**Area:** Financial [PHASE-2]  
**Purpose:** Optional individual income/expense ledger.  
**Frontend source:** NOT in current UI

| Column | Type | Null | Default | Key | Description |
|---|---|---|---|---|---|
| `txn_id` | `bigint unsigned` | NO | auto-increment | PK | Primary key. |
| `user_id` | `bigint unsigned` | NO | — | FK | Owner. |
| `txn_type` | `enum('income','expense')` | NO | — |  | income or expense. |
| `income_category_id` | `smallint unsigned` | YES | — | FK | Set only when txn_type = income. |
| `category_id` | `int unsigned` | YES | — | FK | Set only when txn_type = expense. |
| `amount` | `decimal(12,2)` | NO | — |  | Always positive; direction comes from txn_type. |
| `txn_date` | `date` | NO | — |  | Date of the transaction. |
| `description` | `varchar(200)` | YES | — |  | Optional note (do not store card/bank numbers). |
| `created_at` | `timestamp` | NO | CURRENT_TIMESTAMP |  | When the row was created (UTC). |

**Foreign keys & delete behaviour**

- `category_id` → `expense_categories.category_id` — ON DELETE **NO ACTION** (parent cannot be deleted while referenced (same as RESTRICT)); ON UPDATE RESTRICT (surrogate keys never change)
- `income_category_id` → `income_categories.income_category_id` — ON DELETE **NO ACTION** (parent cannot be deleted while referenced (same as RESTRICT)); ON UPDATE RESTRICT (surrogate keys never change)
- `user_id` → `users.user_id` — ON DELETE **CASCADE** (child rows are deleted with the parent); ON UPDATE RESTRICT (surrogate keys never change)

**Primary key:** (txn_id)  
**Indexes:** `ix_tx_category` (category_id); `ix_tx_income_category` (income_category_id); `ix_tx_user_date` (user_id, txn_date)  

**CHECK constraints**

- `ck_tx_amount`: `((`amount` > 0) and (`amount` <= 9999999999.99))`
- `ck_tx_type_cat`: `(((`txn_type` = _utf8mb4\\'income\\') and (`income_category_id` is not null) and (`category_id` is null)) or ((`txn_type` = _utf8mb4\\'expense\\') and (`category_id` is not null) and (`income_category_id` is null)))`

---

## `recommendation_allocations`

**Area:** AI  
**Purpose:** The proposed split (weight % and amount) per bucket for a recommendation.  
**Frontend source:** Allocation manifest / donut

| Column | Type | Null | Default | Key | Description |
|---|---|---|---|---|---|
| `recommendation_id` | `bigint unsigned` | NO | — | PK, FK | Recommendation. |
| `bucket_id` | `tinyint unsigned` | NO | — | PK, FK | Bucket. |
| `weight_pct` | `decimal(5,2)` | NO | — |  | Proposed % of the base. |
| `amount` | `decimal(12,2)` | NO | — |  | Proposed rupees. |

**Foreign keys & delete behaviour**

- `bucket_id` → `allocation_buckets.bucket_id` — ON DELETE **NO ACTION** (parent cannot be deleted while referenced (same as RESTRICT)); ON UPDATE RESTRICT (surrogate keys never change)
- `recommendation_id` → `recommendations.recommendation_id` — ON DELETE **CASCADE** (child rows are deleted with the parent); ON UPDATE RESTRICT (surrogate keys never change)

**Primary key:** (recommendation_id, bucket_id)  
**Indexes:** `ix_ra_bucket` (bucket_id)  

**CHECK constraints**

- `ck_ra_amount`: `(`amount` >= 0)`
- `ck_ra_weight`: `(`weight_pct` between 0 and 100)`

---

## `recommendation_factors`

**Area:** AI  
**Purpose:** "Why this recommendation?" factor weights.  
**Frontend source:** Recommendation page

| Column | Type | Null | Default | Key | Description |
|---|---|---|---|---|---|
| `recommendation_id` | `bigint unsigned` | NO | — | PK, FK | Recommendation. |
| `factor` | `enum('financial_goal','risk_compatibility','available_budget','previous_performance','user_interest')` | NO | — | PK | financial_goal / risk_compatibility / available_budget / previous_performance / user_interest. |
| `weight_pct` | `decimal(5,2)` | NO | — |  | Influence of that factor (0-100). |

**Foreign keys & delete behaviour**

- `recommendation_id` → `recommendations.recommendation_id` — ON DELETE **CASCADE** (child rows are deleted with the parent); ON UPDATE RESTRICT (surrogate keys never change)

**Primary key:** (recommendation_id, factor)  

**CHECK constraints**

- `ck_rf_weight`: `(`weight_pct` between 0 and 100)`

---

## `recommendation_insights`

**Area:** AI  
**Purpose:** Insight cards shown with a recommendation.  
**Frontend source:** Cortex Insight cards

| Column | Type | Null | Default | Key | Description |
|---|---|---|---|---|---|
| `insight_id` | `bigint unsigned` | NO | auto-increment | PK | Primary key. |
| `recommendation_id` | `bigint unsigned` | NO | — | FK | Recommendation. |
| `insight_type` | `enum('spending','goal','performance','risk','next_month')` | NO | — |  | spending / goal / performance / risk / next_month. |
| `title` | `varchar(80)` | NO | — |  | Card title. |
| `body` | `varchar(500)` | NO | — |  | Card text. |

**Foreign keys & delete behaviour**

- `recommendation_id` → `recommendations.recommendation_id` — ON DELETE **CASCADE** (child rows are deleted with the parent); ON UPDATE RESTRICT (surrogate keys never change)

**Primary key:** (insight_id)  
**Indexes:** `ix_ri_rec` (recommendation_id)  

---

## `recommendations`

**Area:** AI  
**Purpose:** One generated recommendation: inputs snapshot, strategy, status.  
**Frontend source:** Cortex AI Recommendations

| Column | Type | Null | Default | Key | Description |
|---|---|---|---|---|---|
| `recommendation_id` | `bigint unsigned` | NO | auto-increment | PK | Primary key. |
| `user_id` | `bigint unsigned` | NO | — | FK | Owner. |
| `budget_id` | `bigint unsigned` | YES | — | FK | Month used as the input (NULL if that budget was deleted). |
| `strategy_id` | `tinyint unsigned` | NO | — | FK | Strategy recommended. |
| `risk_preference` | `enum('conservative','moderate','aggressive')` | NO | — |  | Risk preference at the time. |
| `lifestyle_pct` | `tinyint unsigned` | NO | — |  | Lifestyle slider at the time. |
| `remaining_money` | `decimal(12,2)` | NO | — |  | Snapshot of the allocation base (disposable income). |
| `input_snapshot` | `json` | YES | — |  | JSON of goals/interests used, so the result can be explained later. |
| `engine_version` | `varchar(40)` | NO | rules-v1 |  | Which recommendation engine/model produced it (e.g. rules-v1). |
| `status` | `enum('generated','applied','dismissed')` | NO | generated |  | generated / applied / dismissed. |
| `created_at` | `timestamp` | NO | CURRENT_TIMESTAMP |  | When the row was created (UTC). |
| `applied_at` | `timestamp` | YES | — |  | When the user applied it. |

**Foreign keys & delete behaviour**

- `budget_id` → `monthly_budgets.budget_id` — ON DELETE **SET NULL** (column becomes NULL, row is kept); ON UPDATE RESTRICT (surrogate keys never change)
- `strategy_id` → `strategies.strategy_id` — ON DELETE **NO ACTION** (parent cannot be deleted while referenced (same as RESTRICT)); ON UPDATE RESTRICT (surrogate keys never change)
- `user_id` → `users.user_id` — ON DELETE **CASCADE** (child rows are deleted with the parent); ON UPDATE RESTRICT (surrogate keys never change)

**Primary key:** (recommendation_id)  
**Indexes:** `ix_rec_budget` (budget_id); `ix_rec_strategy` (strategy_id); `ix_rec_user_created` (user_id, created_at)  

**CHECK constraints**

- `ck_rec_lifestyle`: `(`lifestyle_pct` between 0 and 60)`
- `ck_rec_money`: `(`remaining_money` >= 0)`

---

## Views

| View | Purpose |
|---|---|
| `v_monthly_summary` | Per user-month: total_income, total_expenses, remaining_money = GREATEST(0, income − expenses), deficit. Mirrors the frontend's `calculateRemainingMoney()`. |
| `v_plan_allocation_totals` | Per plan: allocated_total, unallocated, allocated_pct (the planner's live bar). |

Views do **not** filter by user — the backend must always add `WHERE user_id = <authenticated user>`.

## Triggers

| Trigger | Fires | Rule enforced |
|---|---|---|
| `trg_expense_entries_bi` | BEFORE INSERT on `expense_entries` | Category must be a system category for the budget owner's role, or the owner's own custom category |
| `trg_expense_entries_bu` | BEFORE UPDATE on `expense_entries` | Same rule when category/budget changes |
| `trg_income_entries_bi` | BEFORE INSERT on `income_entries` | Income source must apply to the budget owner's role |
| `trg_income_entries_bu` | BEFORE UPDATE on `income_entries` | Same rule when category/budget changes |
| `trg_monthly_plans_au` | AFTER UPDATE on `monthly_plans` | Writes PLAN_<STATUS> rows to audit_logs |
| `trg_monthly_plans_bi` | BEFORE INSERT on `monthly_plans` | New plans start as draft; budget & recommendation must belong to the same user |
| `trg_monthly_plans_bu` | BEFORE UPDATE on `monthly_plans` | Valid status transitions, locked plans immutable, cannot lock if allocations exceed remaining_money, sets/clears locked_at |
| `trg_plan_alloc_bd` | BEFORE DELETE on `plan_allocations` | …deleted only while draft |
| `trg_plan_alloc_bi` | BEFORE INSERT on `plan_allocations` | Allocations can only be added while the plan is draft |
| `trg_plan_alloc_bu` | BEFORE UPDATE on `plan_allocations` | …edited only while draft |
| `trg_recommendations_bi` | BEFORE INSERT on `recommendations` | Budget reference must belong to the same user |
| `trg_recommendations_bu` | BEFORE UPDATE on `recommendations` | Same; cannot change owner |
| `trg_transactions_bi` | BEFORE INSERT on `transactions` | Category must be valid for the user (same rules as budget lines) |
| `trg_transactions_bu` | BEFORE UPDATE on `transactions` | Same; a transaction can never be moved to another user |
| `trg_users_bd` | BEFORE DELETE on `users` | Deletes a user's transactions, budgets and custom categories first so a plain DELETE FROM users cascades cleanly |

Cascaded foreign-key deletes do not fire triggers in MySQL, so deleting a plan/budget/user is never blocked by the draft/locked rules.

## Stored procedures

| Procedure | Purpose | Who may run it |
|---|---|---|
| `sp_assert_expense_category_access(user, category)` | Helper used by triggers (raises error 45000) | internal |
| `sp_assert_income_category_access(user, income_category)` | Helper used by triggers | internal |
| `sp_lock_plan(plan_id, user_id)` | Locks a plan only if it belongs to that user | app |
| `sp_request_account_deletion(user_id)` | Marks pending_deletion, revokes sessions & reset tokens, audits | app |
| `sp_delete_user_account(user_id)` | Hard-deletes one user and all data (transactional) | maintenance |
| `sp_purge_deleted_accounts(retention_days)` | Hard-deletes accounts pending deletion longer than N days | maintenance |
| `sp_purge_expired_security_data(audit_retention_days)` | Removes expired tokens/sessions and old audit rows | maintenance |

## Rules the DATABASE enforces vs rules the BACKEND must enforce

| Rule | Enforced by |
|---|---|
| Amounts ≥ 0 / > 0, percentages 0–100, due day 1–31, priority 1–5, lifestyle 0–60, first-of-month dates | **Database** (CHECK) |
| Unique email (case-insensitive), one budget per user-month, one plan per user-month, one goal per type | **Database** (UNIQUE) |
| Referential integrity, cascade/anonymise on account deletion | **Database** (FK + trigger) |
| A user can only use their own custom categories and role-appropriate categories | **Database** (triggers) |
| Plan lifecycle, locked plans immutable, cannot lock an over-allocated plan | **Database** (triggers) |
| Password hashing (argon2id/bcrypt), strength rules, token generation, email verification | **Backend** |
| **Who may read/write which user's rows** (authorization): every query must filter by the authenticated `user_id`; views do not | **Backend** |
| Rate-limiting, login lockout policy (columns provided), session/refresh-token rotation | **Backend** |
| Computing recommendations/allocations (the DB stores results and checks totals ≤ base) | **Backend** |
| Allocation percentages of a plan summing to exactly 100 (draft plans may be temporarily off, like the UI) | **Backend** (validate before lock) |
| Goal contributions not exceeding target; goal-type/deadline sanity (deadline in the future) | **Backend** |
| Month-end job that creates valuations and moves plans locked → executed | **Backend / scheduler** |
| Running purge procedures on a schedule | **Scheduler** (cron / provider scheduler) |
| Never accept `user_id` from the request body or URL | **Backend** |
