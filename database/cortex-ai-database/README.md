# Cortex AI — MySQL Database

Complete MySQL 8.0 database for **Cortex AI — Personal Money-Balancing and Financial Decision-Support System**.
Designed from the *actual* uploaded frontend (`index.html`), not from the project description alone.

| | |
|---|---|
| Database | `cortex_ai` · MySQL **8.0.19+** (8.0.16 absolute minimum, for enforced CHECK constraints) · InnoDB · utf8mb4 |
| Tables | 33 (+ 2 views, 15 triggers, 7 stored procedures, 42 foreign keys, 28 CHECK constraints) |
| Verified | Every SQL file was executed against a real MySQL 8.0.46 server. Test suite: **127 / 127 PASS** |
| Owner scope | Database only. No backend, API or frontend code is included. |

---

## 1. What is in this folder

| File | What it is | Run order |
|---|---|---|
| `schema.sql` | Creates the `cortex_ai` database, all tables, keys, constraints, indexes, triggers, procedures, views **and the reference data** (categories, strategies, buckets…) | 1 |
| `seed.sql` | **Fictional demo data**: 4 demo users, 7 months of budgets, plans, goals, recommendations, ledger | 2 (dev/test only) |
| `queries.sql` | 28 dashboard/application queries, each documented (purpose, tables, parameters, result) | any time |
| `test_database.sql` | Self-checking test suite (PASS/FAIL grid) | 3 (dev/test only) |
| `security.sql` | Least-privilege roles + hardened login users | after schema (admin) |
| `er_diagram.mmd` | Mermaid ER diagram (validated with the Mermaid parser) | — |
| `data_dictionary.md` | Every table and every column, FKs, delete behaviour, indexes, checks | — |
| `deployment_guide.md` | Hosting, backups, migrations, secure connection, production checklist | — |

---

## 2. What I found in your frontend (and what it means for the database)

Your frontend is a **single-page PWA**: `index.html` (≈2,275 lines of HTML/CSS/vanilla JS), `sw.js`, `manifest.json`, two icons.

**Where data lives today**

| Frontend data | Where it lives now | Becomes |
|---|---|---|
| Login session (`cortexSession`) | `sessionStorage` | `user_sessions` (server-side, hashed token) |
| Appearance settings (`cortexAppearance`) | `localStorage` (per device) | `user_preferences` |
| Income, expenses, flexible flag, due day, custom lines, goals, risk, lifestyle %, interests, plan lock | JS `state` object — **lost on every refresh** | `monthly_budgets`, `income_entries`, `expense_entries`, `expense_categories`, `financial_goals`, `user_profiles`, `user_interests`, `monthly_plans` |
| Recommendations, allocation weights, "Why this?" factors, insight cards | Hard-coded JS tables | reference tables + `recommendations*` tables |
| Financial History (prev/current value) | Mock numbers | `allocation_valuations` |

The frontend makes **zero network requests** today (`fetch` count = 0), so a backend must be built to connect it to this database.

**Mapping: frontend feature → tables**

| Frontend feature | Tables |
|---|---|
| Create account / Login / Profile (name, email, Student or Employee) | `users`, `user_sessions`, `password_reset_tokens` |
| Income card (salary / allowance / scholarship / other) | `income_categories`, `income_entries` |
| Essential Expenses card (grouped lines, Flexible toggle, Due day, + Add Custom Line) | `expense_category_groups`, `expense_categories`, `role_expense_categories`, `expense_entries` |
| "Remaining Money" ring (income − expenses, floored at 0) | view `v_monthly_summary` |
| Money, Goals & Interests (risk, lifestyle slider, goal cards + target/deadline/priority, chips) | `user_profiles`, `financial_goals`, `goal_types`, `interest_options`, `user_interests` |
| Cortex AI Recommendations (strategy cards, donut, "Why this?", insights) | `strategies`, `strategy_bucket_weights`, `strategy_rationales`, `recommendations`, `recommendation_allocations`, `recommendation_factors`, `recommendation_insights` |
| Allocation Manifest & Planner, Lock & Execute | `monthly_plans`, `plan_allocations`, `allocation_buckets` |
| Next Month (Continue / Modify / Review) | `next_month_actions`, `next_month_action_tweaks`, `monthly_plans.next_month_action_id` |
| Financial History | `allocation_valuations` |
| Settings → Appearance | `user_preferences` |

### Gaps and issues in the frontend you should know about

These are **not database bugs**; they are things the database had to make a decision about, or that the frontend/backend developer should fix.

1. **No individual transactions exist in the UI** — only one monthly total per category. Your brief lists "transaction history" and "recent transactions", so I added `transactions` as an **optional [PHASE-2] ledger**. The current UI does not use it.
2. **Goals have no "saved so far" field**, so goal *progress* cannot be calculated from today's UI. I added `goal_contributions` **[PHASE-2]** so progress works once the UI can record deposits.
3. **There is no month concept in the UI**, but analysis, history and trends need one. The database adds `monthly_budgets` (one row per user per month).
4. **Hard-coded demo credentials** are in the client JS (`employee@cortex.app` / `student@cortex.app`, lines ~1119–1120). Anyone can read them in the browser. Remove them when the real login is wired up. The seed uses different fictional accounts (`@example.com`).
5. **The Monthly Trend chart is hard-coded** (`Apr…Sep` with fixed numbers, line ~1972). Query `D3` in `queries.sql` returns the real data.
6. **The "Investments" figure counts only Fixed Deposit + Stocks** (line ~1948); Recurring Deposit, Chits and Crypto are excluded. The database groups buckets as `saving` / `investment` / `lifestyle` / `other` and the queries use the full group — so the numbers will differ from the current UI. Decide which definition you want and align the frontend.
7. **The lifestyle slider (0–60%) only displays an amount**; it does not change the bucket allocation. The database stores it (`user_profiles.lifestyle_pct`) but nothing consumes it yet.
8. **The student sample defaults overspend**: expenses ₹14,500 vs allowance ₹12,000, so Remaining Money clamps to ₹0 and the ₹2,500 shortfall is invisible. The view `v_monthly_summary` reports it separately as `deficit`.
9. **"Email / Username" label** on the login form, but only email format is accepted. The database has no username column.
10. **Every expense line is called "essential"**, including Student *Entertainment*. I added `expense_categories.nature` (essential/discretionary) so "essential vs discretionary" analytics are possible; only Entertainment is discretionary. This classification is my decision — change it in the reference data if you disagree.
11. **Recommendations are rule-based, not machine-learning** (fixed weights per strategy). The database stores `engine_version` so a future ML engine can be tracked.

---

## 3. Architecture in plain language

```
 Browser (Vercel)  ──HTTPS──▶  Backend API (separate host)  ──TLS──▶  MySQL (managed cloud)
  never talks to the DB          authenticates, authorizes,           enforces data rules,
                                 hashes passwords, filters by user    stores everything
```

* **Reference tables** (categories, strategies, buckets, goal types …) hold the fixed lists the UI shows. The app can only *read* them.
* **`users`** is the root. Everything a user owns hangs off `user_id` and is **deleted automatically** when the account is deleted.
* **`monthly_budgets`** = one row per user per month. Its **income lines** and **expense lines** are the numbers typed on the Income & Expenses page. Disposable income is *calculated* (view), never stored twice.
* **`recommendations`** records what the AI suggested (inputs, strategy, split, reasons). **`monthly_plans`** is what the user actually chose for a target month. A plan keeps a **frozen copy of the money it allocates** (`remaining_money`) so history never changes if budgets are edited later.
* **`plan_allocations`** = the planner table (one row per bucket). **`allocation_valuations`** = how each allocation performed after the month (Financial History page).
* A plan moves **draft → locked → executed**. Once locked, its allocations cannot be changed (database-enforced), and it cannot be locked if it allocates more than the money available.
* **Allocations are calculated from disposable income, not gross income.** Example from your brief: income ₹30,000 − essentials ₹10,000 = ₹20,000 disposable; Balanced strategy gives Savings 20% × ₹20,000 = **₹4,000** (verified by test section 7b).

### Key relationships (cardinality and delete behaviour)

| Relationship | Cardinality | If the parent is deleted |
|---|---|---|
| `users` → `user_profiles`, `user_preferences` | 1 : 1 | child deleted |
| `users` → `monthly_budgets`, `financial_goals`, `recommendations`, `monthly_plans`, `transactions`, sessions, tokens | 1 : many | child deleted |
| `users` ↔ `interest_options` via `user_interests` | many : many | link rows deleted |
| `monthly_budgets` → `income_entries`, `expense_entries` | 1 : many | lines deleted |
| `expense_categories` → `expense_entries` | 1 : many | **blocked** (deactivate with `is_active = 0` instead) |
| `monthly_plans` → `plan_allocations` → `allocation_valuations` | 1 : many → 1 : 0..1 | children deleted |
| `recommendations` → allocations / factors / insights | 1 : many | children deleted |
| `monthly_budgets` / `recommendations` → `monthly_plans` | 1 : many (optional) | plan **kept**, link set to NULL |
| `strategies`, `allocation_buckets`, `goal_types` → anything | 1 : many | **blocked** while used |
| `users` → `audit_logs` | 1 : many (optional) | log **kept**, user_id set to NULL (anonymised) |
| `financial_goals` → `goal_contributions` | 1 : many | contributions deleted |

See `er_diagram.mmd` for the full diagram and `data_dictionary.md` for every column.

---

## 4. Step-by-step: run it in MySQL Workbench

**Requirements:** MySQL Server 8.0.19+ (local install or a dev instance) and MySQL Workbench 8.0.

1. **Open Workbench** and connect to your local server (usually `Local instance MySQL80`, user `root`).
2. **Run the schema.** `File → Open SQL Script…` → choose `schema.sql` → click the ⚡ **Execute** button (the lightning bolt, *not* the one with the cursor).
   * ⚠ `schema.sql` begins with `DROP DATABASE IF EXISTS cortex_ai;` — it **erases** any existing `cortex_ai`. Never run it on a database with real data.
   * Expected result grid: `cortex_ai schema created | tables_created = 33`.
3. **Load the demo data.** Open `seed.sql` → ⚡ Execute. Expected: `cortex_ai demo data loaded | demo_users = 4`.
4. **Run the tests.** Open `test_database.sql` → ⚡ Execute. In the **Result Grid** tabs you should see all rows `PASS` and the final summary:
   `total_tests = 127 | passed = 127 | failed = 0 | ALL TESTS PASSED`.
5. **Try the dashboard queries.** Open `queries.sql`. Run the **PARAMETERS** block at the top (select those `SET` lines → ⚡), then put the cursor inside any query and press `Ctrl+Enter` (⌘+Enter on Mac). Change `@p_user_id` (1–4) and `@p_month` to look at other users/months.
6. **(Optional) View the ER diagram.** Paste `er_diagram.mmd` into <https://mermaid.live>, or in Workbench use `Database → Reverse Engineer…` for Workbench's own diagram.
7. **Create application users** (when you are ready to connect a backend): edit the 6 `SET` lines at the top of `security.sql`, then run it as an administrator. See `deployment_guide.md`.

**Command-line alternative**

```bash
mysql -u root -p < schema.sql
mysql -u root -p < seed.sql
mysql -u root -p cortex_ai < test_database.sql
```

**Demo logins** (for the backend developer's testing only): `ananya.demo@example.com`, `rohan.demo@example.com`, `meera.demo@example.com`, `kiran.demo@example.com` — password `Demo@12345` (bcrypt-hashed in the database). Before go-live run `DELETE FROM users WHERE is_demo = 1;` — it removes every demo account and all their data.

### Expected values from the sample data (use these to sanity-check)

| Check | Expected |
|---|---|
| User 1, Oct 2026: income / expenses / disposable | 58,000 / 38,500 / **19,500** |
| User 1, Nov plan: allocated vs base | 19,500 / 19,500 (100%) |
| User 1, Nov plan: savings-type + investment allocations ÷ income | (7,800 + 6,825) / 58,000 = **25.22 %** |
| User 2, Nov plan (draft, customised) | base 3,800, allocated 3,420, **unallocated 380** |
| User 1 Emergency Fund progress | 6,600 of 150,000 = **4.4 %** |
| User 1 Vacation progress | 3,300 of 60,000 = **5.5 %** |
| Strategy weights | each of the 3 strategies sums to exactly 100 % |

---

## 5. Who enforces what

**The database enforces:** non-negative amounts, percentage ranges, unique emails (case-insensitive), one budget/plan per user per month, referential integrity, a user can only use their own custom categories and role-appropriate categories, plan lifecycle (draft → locked → executed), locked plans are immutable, cannot lock an over-allocated plan, cascade/anonymise on account deletion, least-privilege accounts (`security.sql`).

**The backend developer MUST enforce** (the database cannot):

1. **Authorization.** Foreign keys do **not** stop user A from reading user B's rows. *Every* query must include `WHERE user_id = <id from the verified session>`. Never take `user_id` from the request body, URL or query string. The two views do not filter by user.
2. **Password handling:** hash with argon2id (preferred) or bcrypt; enforce strength; never log passwords. The database rejects obviously-plaintext values but cannot verify a hash is strong.
3. **Sessions/tokens:** generate random tokens, store only SHA-256 hashes, rotate refresh tokens, revoke on logout/password change.
4. **Login throttling:** the columns `failed_login_count` / `locked_until` exist (queries I2/I3); the backend applies the policy. Also rate-limit by IP.
5. **Calculations:** compute recommendations and allocations; ensure a plan's baseline % sums to 100 before locking (drafts may be temporarily off, as in the UI).
6. **Business sanity checks:** goal deadline in the future, contributions not exceeding targets, plan month = next month, etc.
7. **Scheduled jobs:** month-end valuations and `locked → executed`; daily `sp_purge_expired_security_data`; daily `sp_purge_deleted_accounts(30)`.
8. **Secrets:** database credentials only in the backend's environment variables / secret manager. Never in the Vercel frontend, never in GitHub.

---

## 6. Notes for the backend developer

| Frontend `state` field | Write to |
|---|---|
| `state.income[id]` | `income_entries` (one row per `income_category_id` per budget) |
| `state.expenses[id]`, `expenseMeta[id].flexible/dueDay` | `expense_entries.amount / is_flexible / due_day` |
| `state.customExpenses` | `expense_categories` (`user_id` = caller) + `expense_entries` |
| `state.goalDetails[goal]` (target, deadline, priority) | `financial_goals` (UNIQUE per user + goal type) |
| `state.lifestylePct`, risk, strategy | `user_profiles` |
| `state.locked` | `monthly_plans.status` (`locked` / back to `draft`) |
| `state.nextMonthSelected` | `monthly_plans.next_month_action_id` |

Useful patterns:

```sql
-- Save one expense line (idempotent): the UNIQUE (budget_id, category_id) key makes this safe to repeat
INSERT INTO expense_entries (budget_id, category_id, amount, is_flexible, due_day)
VALUES (?, ?, ?, ?, ?)
ON DUPLICATE KEY UPDATE amount = VALUES(amount), is_flexible = VALUES(is_flexible), due_day = VALUES(due_day);

-- Get-or-create this month's budget
INSERT INTO monthly_budgets (user_id, budget_month) VALUES (?, ?) ON DUPLICATE KEY UPDATE budget_id = LAST_INSERT_ID(budget_id);
```

* Wrap multi-statement saves (e.g. a plan + its 9 allocations) in **one transaction**.
* Create a plan as `draft`, insert its 9 `plan_allocations`, then `UPDATE … SET status='locked'` (the trigger validates).
* Connect with `time_zone = '+00:00'` and TLS. Use a pooled connection with the `cortex_app` user — never `root`.
* Expose `users.public_id` (a UUID) in APIs, never the numeric `user_id`.
* Zero-amount lines are allowed (the UI posts them); you may skip them to save space.
* The one-goal-per-type rule mirrors the UI. To allow several goals of the same type (e.g. two vacations), drop `uq_fg_user_type` in a migration and add a `title` column.

---

## 7. Design decisions worth knowing

* **Money:** `DECIMAL(12,2)` everywhere (max ≈ ₹10 billion). No FLOAT/DOUBLE — verified by a test.
* **Snapshots:** plans and recommendations store the `remaining_money` they used, so history is stable.
* **Deactivate, don't delete:** custom categories use `is_active`; deletion is blocked once a category has history.
* **Triggers only where a constraint cannot do the job:** cross-user safety and plan lifecycle (listed in `data_dictionary.md`).
* **Plain `DELETE FROM users` works** and removes everything. I found, by testing, that without the `trg_users_bd` trigger it would fail with error 1451 whenever a user had custom categories in use; the trigger fixes that.
* **Insight/rationale text** is stored as data (reference tables) so wording can change without a frontend release.
* **Not stored on purpose:** card numbers, bank account numbers/passwords, government IDs. A test checks that no such columns exist.

## 8. Limitations — please read

* I verified everything on **MySQL 8.0.46 (Ubuntu)**. I did **not** test on your chosen cloud provider; some managed/“MySQL-compatible” services restrict triggers, stored procedures or foreign keys. Confirm your provider supports all three before choosing (see `deployment_guide.md`).
* I did not run MySQL Workbench itself (no GUI here); I used the `mysql` client, which runs the same scripts. Workbench handles the `DELIMITER` lines natively.
* The data dictionary and ER diagram were generated from the live schema; if you change `schema.sql`, regenerate or edit them.
