-- =====================================================================
-- Cortex AI — DASHBOARD & APPLICATION QUERIES
-- =====================================================================
-- HOW TO RUN IN WORKBENCH
--   1. Run schema.sql then seed.sql.
--   2. Run the "PARAMETERS" block below, then run any query (Ctrl+Enter on the statement).
-- HOW THE BACKEND USES THEM
--   Replace each @p_xxx with a ? placeholder and bind values via a prepared statement
--   (mysql2 / JDBC / etc.). NEVER build these strings by concatenating user input.
--   user_id must ALWAYS come from the authenticated session/JWT, never from the request body.
-- CONVENTIONS
--   * "month" parameters are the 1st day of a month ('2026-10-01').
--   * remaining_money (a.k.a. disposable income) = GREATEST(0, income - expenses),
--     exactly like the frontend's calculateRemainingMoney(); the deficit is reported separately.
--   * No financial metric below uses a hard-coded number: everything is aggregated from tables.
-- =====================================================================
USE cortex_ai;

-- ---------------------------- PARAMETERS -----------------------------
SET @p_user_id      = 1;                 -- authenticated user (from session, never from the client)
SET @p_month        = '2026-10-01';      -- budget month being viewed
SET @p_plan_month   = '2026-11-01';      -- target month of a plan
SET @p_months_back  = 6;                 -- how many months for trend charts
SET @p_year         = 2026;
SET @p_as_of        = '2026-11-02';      -- "today" (backend passes CURDATE())
SET @p_email        = 'ananya.demo@example.com';
SET @p_recommendation_id = (SELECT MAX(recommendation_id) FROM recommendations WHERE user_id = @p_user_id);

-- =====================================================================
-- A. FORM DEFINITIONS (what the Income & Expenses page needs to render)
-- =====================================================================

-- A1. Income fields for this user's role.
-- Tables: users, income_categories | Params: @p_user_id | Returns: one row per income input box.
SELECT ic.income_category_id, ic.code, ic.name
  FROM users u
  JOIN income_categories ic ON ic.is_active = 1 AND ic.applies_to IN ('both', u.role)
 WHERE u.user_id = @p_user_id
 ORDER BY ic.sort_order, ic.name;

-- A2. Expense fields for this user: system categories for their role (grouped, ordered) + their custom lines.
-- Tables: users, role_expense_categories, expense_categories, expense_category_groups | Params: @p_user_id
-- Returns: group_name, category, nature (essential/discretionary), is_custom.
SELECT g.name AS group_name, c.category_id, c.name AS category, c.nature, 0 AS is_custom, rec.sort_order
  FROM users u
  JOIN role_expense_categories rec ON rec.role = u.role
  JOIN expense_categories c        ON c.category_id = rec.category_id AND c.is_active = 1
  JOIN expense_category_groups g   ON g.group_id = rec.group_id
 WHERE u.user_id = @p_user_id
UNION ALL
SELECT 'Custom', c.category_id, c.name, c.nature, 1, 99
  FROM expense_categories c
 WHERE c.user_id = @p_user_id AND c.is_active = 1
 ORDER BY 1, 6, 3;

-- =====================================================================
-- B. OVERVIEW CARDS
-- =====================================================================

-- B1. Total monthly income, by source and in total.
-- Tables: monthly_budgets, income_entries, income_categories | Params: @p_user_id, @p_month
-- Returns: one row per income source + a ROLLUP total row (source = NULL).
SELECT ic.name AS source, SUM(ie.amount) AS amount
  FROM monthly_budgets b
  JOIN income_entries ie    ON ie.budget_id = b.budget_id
  JOIN income_categories ic ON ic.income_category_id = ie.income_category_id
 WHERE b.user_id = @p_user_id AND b.budget_month = @p_month
 GROUP BY ic.name WITH ROLLUP;

-- B2. Total monthly (essential) expenses.
-- Tables: monthly_budgets, expense_entries | Params: @p_user_id, @p_month | Returns: 1 row, total_expenses.
SELECT COALESCE(SUM(ee.amount), 0) AS total_expenses
  FROM monthly_budgets b
  LEFT JOIN expense_entries ee ON ee.budget_id = b.budget_id
 WHERE b.user_id = @p_user_id AND b.budget_month = @p_month;

-- B3. Disposable income (the "Remaining Money" ring) + deficit + share of income left.
-- Tables: v_monthly_summary (monthly_budgets + income_entries + expense_entries) | Params: @p_user_id, @p_month
-- Returns: total_income, total_expenses, remaining_money, deficit, remaining_pct_of_income.
SELECT s.total_income, s.total_expenses, s.remaining_money, s.deficit,
       CASE WHEN s.total_income > 0 THEN ROUND(100 * s.remaining_money / s.total_income, 1) ELSE 0 END AS remaining_pct_of_income
  FROM v_monthly_summary s
 WHERE s.user_id = @p_user_id AND s.budget_month = @p_month;

-- B4. "Allocation: NN% Planned" card = how much of next month's remaining money is allocated.
-- Tables: v_plan_allocation_totals | Params: @p_user_id, @p_plan_month
-- Returns: plan status, remaining_money, allocated_total, unallocated, allocated_pct.
SELECT plan_id, status, remaining_money, allocated_total, unallocated, allocated_pct
  FROM v_plan_allocation_totals
 WHERE user_id = @p_user_id AND plan_month = @p_plan_month;

-- =====================================================================
-- C. SAVINGS & INVESTMENT
-- =====================================================================

-- C1. Total savings & investments planned for a month (+ year-to-date), from locked/executed plans.
-- Tables: monthly_plans, plan_allocations, allocation_buckets | Params: @p_user_id, @p_plan_month
-- Returns: planned_savings (saving group), planned_investments (investment group), planned_lifestyle, ytd_savings_and_investments.
-- NOTE: the frontend's "Investments" tile adds only FD + Stocks; here the full 'investment' group (FD+Stocks+Crypto) is used.
SELECT SUM(CASE WHEN p.plan_month = @p_plan_month AND ab.bucket_group = 'saving'     THEN pa.allocated_amount ELSE 0 END) AS planned_savings,
       SUM(CASE WHEN p.plan_month = @p_plan_month AND ab.bucket_group = 'investment' THEN pa.allocated_amount ELSE 0 END) AS planned_investments,
       SUM(CASE WHEN p.plan_month = @p_plan_month AND ab.bucket_group = 'lifestyle'  THEN pa.allocated_amount ELSE 0 END) AS planned_lifestyle,
       SUM(CASE WHEN ab.bucket_group IN ('saving','investment') THEN pa.allocated_amount ELSE 0 END)                       AS ytd_savings_and_investments
  FROM monthly_plans p
  JOIN plan_allocations pa  ON pa.plan_id = p.plan_id
  JOIN allocation_buckets ab ON ab.bucket_id = pa.bucket_id
 WHERE p.user_id = @p_user_id
   AND p.status IN ('locked','executed')
   AND YEAR(p.plan_month) = YEAR(@p_plan_month)
   AND p.plan_month <= @p_plan_month;

-- C2. Savings rate = (saving + investment allocations) / income of the budget the plan was based on.
-- Tables: monthly_plans, plan_allocations, allocation_buckets, v_monthly_summary | Params: @p_user_id, @p_plan_month
-- Returns: total_income, saved_and_invested, savings_rate_pct, disposable_rate_pct (remaining / income).
SELECT s.total_income,
       SUM(CASE WHEN ab.bucket_group IN ('saving','investment') THEN pa.allocated_amount ELSE 0 END) AS saved_and_invested,
       CASE WHEN s.total_income > 0
            THEN ROUND(100 * SUM(CASE WHEN ab.bucket_group IN ('saving','investment') THEN pa.allocated_amount ELSE 0 END) / s.total_income, 2)
            ELSE 0 END AS savings_rate_pct,
       CASE WHEN s.total_income > 0 THEN ROUND(100 * s.remaining_money / s.total_income, 2) ELSE 0 END AS disposable_rate_pct
  FROM monthly_plans p
  JOIN v_monthly_summary s   ON s.budget_id = p.budget_id
  JOIN plan_allocations pa   ON pa.plan_id = p.plan_id
  JOIN allocation_buckets ab ON ab.bucket_id = pa.bucket_id
 WHERE p.user_id = @p_user_id AND p.plan_month = @p_plan_month
 GROUP BY s.budget_id, s.total_income, s.remaining_money;

-- C3. Investment allocation: only investment-group buckets and their share of the investment total.
-- Tables: monthly_plans, plan_allocations, allocation_buckets | Params: @p_user_id, @p_plan_month
-- Returns: bucket, amount, share_of_investments_pct (Fixed Deposit / Stocks / Crypto).
SELECT ab.name AS bucket, pa.allocated_amount AS amount,
       ROUND(100 * pa.allocated_amount / NULLIF(SUM(pa.allocated_amount) OVER (), 0), 1) AS share_of_investments_pct
  FROM monthly_plans p
  JOIN plan_allocations pa   ON pa.plan_id = p.plan_id
  JOIN allocation_buckets ab ON ab.bucket_id = pa.bucket_id AND ab.bucket_group = 'investment'
 WHERE p.user_id = @p_user_id AND p.plan_month = @p_plan_month
 ORDER BY ab.sort_order;

-- =====================================================================
-- D. SPENDING ANALYTICS (Monthly Analysis charts)
-- =====================================================================

-- D1. Expense breakdown by category (the "Spending Breakdown" donut).
-- Tables: users, monthly_budgets, expense_entries, expense_categories, role_expense_categories, expense_category_groups
-- Params: @p_user_id, @p_month | Returns: group, category, amount, pct_of_expenses (zero lines excluded).
SELECT COALESCE(g.name, 'Custom') AS group_name, c.name AS category, ee.amount,
       ROUND(100 * ee.amount / NULLIF(SUM(ee.amount) OVER (), 0), 1) AS pct_of_expenses
  FROM monthly_budgets b
  JOIN users u              ON u.user_id = b.user_id
  JOIN expense_entries ee   ON ee.budget_id = b.budget_id AND ee.amount > 0
  JOIN expense_categories c ON c.category_id = ee.category_id
  LEFT JOIN role_expense_categories rec ON rec.role = u.role AND rec.category_id = c.category_id
  LEFT JOIN expense_category_groups g   ON g.group_id = rec.group_id
 WHERE b.user_id = @p_user_id AND b.budget_month = @p_month
 ORDER BY ee.amount DESC;

-- D2. Essential vs discretionary spending: (a) expense lines by nature, (b) planned lifestyle buckets.
-- Tables: monthly_budgets, expense_entries, expense_categories; monthly_plans, plan_allocations, allocation_buckets
-- Params: @p_user_id, @p_month, @p_plan_month | Returns: kind, amount.
SELECT 'Expense lines - essential' AS kind, COALESCE(SUM(ee.amount),0) AS amount
  FROM monthly_budgets b JOIN expense_entries ee ON ee.budget_id = b.budget_id
  JOIN expense_categories c ON c.category_id = ee.category_id AND c.nature = 'essential'
 WHERE b.user_id = @p_user_id AND b.budget_month = @p_month
UNION ALL
SELECT 'Expense lines - discretionary', COALESCE(SUM(ee.amount),0)
  FROM monthly_budgets b JOIN expense_entries ee ON ee.budget_id = b.budget_id
  JOIN expense_categories c ON c.category_id = ee.category_id AND c.nature = 'discretionary'
 WHERE b.user_id = @p_user_id AND b.budget_month = @p_month
UNION ALL
SELECT 'Planned lifestyle (Entertainment + Shopping)', COALESCE(SUM(pa.allocated_amount),0)
  FROM monthly_plans p JOIN plan_allocations pa ON pa.plan_id = p.plan_id
  JOIN allocation_buckets ab ON ab.bucket_id = pa.bucket_id AND ab.bucket_group = 'lifestyle'
 WHERE p.user_id = @p_user_id AND p.plan_month = @p_plan_month;

-- D3. Monthly income vs expenses for the last N months (the "Monthly Trend" chart).
-- Tables: v_monthly_summary | Params: @p_user_id, @p_month (last month shown), @p_months_back
-- Returns: month, total_income, total_expenses, remaining_money.
SELECT DATE_FORMAT(budget_month, '%Y-%m') AS month, total_income, total_expenses, remaining_money
  FROM v_monthly_summary
 WHERE user_id = @p_user_id
   AND budget_month BETWEEN DATE_SUB(@p_month, INTERVAL (@p_months_back - 1) MONTH) AND @p_month
 ORDER BY budget_month;

-- D4. Previous-month comparison with absolute and % change.
-- Tables: v_monthly_summary | Params: @p_user_id, @p_month
-- Returns: one row per metric: this_month, previous_month, change, change_pct.
SELECT m.metric, m.cur AS this_month, m.prev AS previous_month, m.cur - m.prev AS change_amount,
       CASE WHEN m.prev = 0 THEN NULL ELSE ROUND(100 * (m.cur - m.prev) / m.prev, 1) END AS change_pct
  FROM (
    SELECT 'Income' AS metric, c.total_income AS cur, COALESCE(p.total_income,0) AS prev
      FROM v_monthly_summary c LEFT JOIN v_monthly_summary p ON p.user_id = c.user_id AND p.budget_month = DATE_SUB(c.budget_month, INTERVAL 1 MONTH)
     WHERE c.user_id = @p_user_id AND c.budget_month = @p_month
    UNION ALL
    SELECT 'Expenses', c.total_expenses, COALESCE(p.total_expenses,0)
      FROM v_monthly_summary c LEFT JOIN v_monthly_summary p ON p.user_id = c.user_id AND p.budget_month = DATE_SUB(c.budget_month, INTERVAL 1 MONTH)
     WHERE c.user_id = @p_user_id AND c.budget_month = @p_month
    UNION ALL
    SELECT 'Remaining money', c.remaining_money, COALESCE(p.remaining_money,0)
      FROM v_monthly_summary c LEFT JOIN v_monthly_summary p ON p.user_id = c.user_id AND p.budget_month = DATE_SUB(c.budget_month, INTERVAL 1 MONTH)
     WHERE c.user_id = @p_user_id AND c.budget_month = @p_month
  ) m;

-- D5. Spending trends: each category month by month with month-over-month change.
-- The previous value is looked up by CALENDAR month (not "previous row"), so a missing/zero month is handled correctly.
-- Tables: monthly_budgets, expense_entries, expense_categories | Params: @p_user_id, @p_month, @p_months_back
-- Returns: category, month, amount, previous_amount (NULL if no budget existed for the prior month), mom_change_pct.
SELECT c.name AS category, DATE_FORMAT(b.budget_month, '%Y-%m') AS month, ee.amount,
       IF(pb.budget_id IS NULL, NULL, COALESCE(pe.amount, 0)) AS previous_amount,
       CASE WHEN pe.amount > 0 THEN ROUND(100 * (ee.amount - pe.amount) / pe.amount, 1) END AS mom_change_pct
  FROM monthly_budgets b
  JOIN expense_entries ee   ON ee.budget_id = b.budget_id AND ee.amount > 0
  JOIN expense_categories c ON c.category_id = ee.category_id
  LEFT JOIN monthly_budgets pb ON pb.user_id = b.user_id AND pb.budget_month = DATE_SUB(b.budget_month, INTERVAL 1 MONTH)
  LEFT JOIN expense_entries pe ON pe.budget_id = pb.budget_id AND pe.category_id = ee.category_id
 WHERE b.user_id = @p_user_id
   AND b.budget_month BETWEEN DATE_SUB(@p_month, INTERVAL (@p_months_back - 1) MONTH) AND @p_month
 ORDER BY c.name, b.budget_month;

-- D6. Yearly financial summary.
-- Tables: v_monthly_summary; monthly_plans, plan_allocations, allocation_buckets | Params: @p_user_id, @p_year
-- Returns: months_recorded, total_income, total_expenses, total_remaining, avg_monthly_remaining, planned_saved_and_invested, ytd_savings_rate_pct.
SELECT s.months_recorded, s.total_income, s.total_expenses, s.total_remaining,
       ROUND(s.total_remaining / NULLIF(s.months_recorded, 0), 2) AS avg_monthly_remaining,
       COALESCE(pl.saved_and_invested, 0) AS planned_saved_and_invested,
       CASE WHEN s.total_income > 0 THEN ROUND(100 * COALESCE(pl.saved_and_invested, 0) / s.total_income, 2) ELSE 0 END AS ytd_savings_rate_pct
  FROM (SELECT COUNT(*) AS months_recorded, SUM(total_income) AS total_income, SUM(total_expenses) AS total_expenses, SUM(remaining_money) AS total_remaining
          FROM v_monthly_summary WHERE user_id = @p_user_id AND YEAR(budget_month) = @p_year) s
  LEFT JOIN (SELECT SUM(pa.allocated_amount) AS saved_and_invested
               FROM monthly_plans p
               JOIN plan_allocations pa   ON pa.plan_id = p.plan_id
               JOIN allocation_buckets ab ON ab.bucket_id = pa.bucket_id AND ab.bucket_group IN ('saving','investment')
              WHERE p.user_id = @p_user_id AND YEAR(p.plan_month) = @p_year AND p.status IN ('locked','executed')) pl ON 1 = 1;

-- =====================================================================
-- E. TRANSACTIONS  [PHASE-2: the current frontend has no transaction entry screen]
-- =====================================================================

-- E1. Recent transactions (latest first). Backend: use LIMIT ? in a prepared statement.
-- Tables: transactions, expense_categories, income_categories | Params: @p_user_id
-- Returns: txn_date, type, category, amount, description.
SELECT t.txn_date, t.txn_type, COALESCE(ec.name, ic.name) AS category, t.amount, t.description
  FROM transactions t
  LEFT JOIN expense_categories ec ON ec.category_id = t.category_id
  LEFT JOIN income_categories  ic ON ic.income_category_id = t.income_category_id
 WHERE t.user_id = @p_user_id
 ORDER BY t.txn_date DESC, t.txn_id DESC
 LIMIT 10;

-- E2. Budget vs actual for a month (ledger totals compared with the monthly budget lines).
-- Tables: expense_categories, expense_entries, monthly_budgets, transactions | Params: @p_user_id, @p_month
-- Returns: category, budgeted, actual, difference (positive = under budget).
SELECT c.name AS category, COALESCE(bg.amount, 0) AS budgeted, COALESCE(ac.actual, 0) AS actual,
       COALESCE(bg.amount, 0) - COALESCE(ac.actual, 0) AS difference
  FROM expense_categories c
  LEFT JOIN (SELECT ee.category_id, ee.amount FROM monthly_budgets b JOIN expense_entries ee ON ee.budget_id = b.budget_id
              WHERE b.user_id = @p_user_id AND b.budget_month = @p_month) bg ON bg.category_id = c.category_id
  LEFT JOIN (SELECT category_id, SUM(amount) AS actual FROM transactions
              WHERE user_id = @p_user_id AND txn_type = 'expense' AND txn_date >= @p_month AND txn_date < DATE_ADD(@p_month, INTERVAL 1 MONTH)
              GROUP BY category_id) ac ON ac.category_id = c.category_id
 WHERE bg.category_id IS NOT NULL OR ac.category_id IS NOT NULL
 ORDER BY actual DESC;

-- =====================================================================
-- F. GOALS
-- =====================================================================

-- F1. Financial goal progress. Progress needs goal_contributions (PHASE-2); goals with no target return NULL progress.
-- Tables: financial_goals, goal_types, goal_contributions | Params: @p_user_id, @p_as_of
-- Returns: goal, target, saved, progress_pct, remaining, deadline, months_left, required_per_month, priority.
SELECT gt.name AS goal, g.target_amount AS target, COALESCE(SUM(gc.amount), 0) AS saved,
       CASE WHEN g.target_amount IS NULL THEN NULL
            ELSE LEAST(100, ROUND(100 * COALESCE(SUM(gc.amount), 0) / g.target_amount, 1)) END AS progress_pct,
       CASE WHEN g.target_amount IS NULL THEN NULL ELSE GREATEST(g.target_amount - COALESCE(SUM(gc.amount), 0), 0) END AS remaining,
       g.deadline,
       CASE WHEN g.deadline IS NULL THEN NULL ELSE GREATEST(TIMESTAMPDIFF(MONTH, @p_as_of, g.deadline), 0) END AS months_left,
       CASE WHEN g.target_amount IS NULL OR g.deadline IS NULL OR TIMESTAMPDIFF(MONTH, @p_as_of, g.deadline) <= 0 THEN NULL
            ELSE ROUND(GREATEST(g.target_amount - COALESCE(SUM(gc.amount), 0), 0) / TIMESTAMPDIFF(MONTH, @p_as_of, g.deadline), 2) END AS required_per_month,
       g.priority, g.status
  FROM financial_goals g
  JOIN goal_types gt           ON gt.goal_type_id = g.goal_type_id
  LEFT JOIN goal_contributions gc ON gc.goal_id = g.goal_id
 WHERE g.user_id = @p_user_id
 GROUP BY g.goal_id, gt.name, g.target_amount, g.deadline, g.priority, g.status
 ORDER BY g.priority DESC, g.deadline;

-- =====================================================================
-- G. ALLOCATION PLANNER / RECOMMENDATIONS
-- =====================================================================

-- G1. Monthly allocation breakdown (the planner table + manifest).
-- Tables: monthly_plans, plan_allocations, allocation_buckets | Params: @p_user_id, @p_plan_month
-- Returns: bucket, group, baseline_pct, ai_adjustment_pct, proposed_amount, proposed_pct, priority.
SELECT ab.name AS bucket, ab.bucket_group, pa.baseline_pct, pa.adjustment_pct AS ai_adjustment_pct,
       pa.allocated_amount AS proposed_amount,
       CASE WHEN p.remaining_money > 0 THEN ROUND(100 * pa.allocated_amount / p.remaining_money, 1) ELSE 0 END AS proposed_pct,
       pa.priority
  FROM monthly_plans p
  JOIN plan_allocations pa   ON pa.plan_id = p.plan_id
  JOIN allocation_buckets ab ON ab.bucket_id = pa.bucket_id
 WHERE p.user_id = @p_user_id AND p.plan_month = @p_plan_month
 ORDER BY ab.sort_order;

-- G2. Recommendation history (newest first).
-- Tables: recommendations, strategies, monthly_plans | Params: @p_user_id
-- Returns: when, strategy, risk, remaining_money, status, whether it became a plan (and for which month).
SELECT r.recommendation_id, r.created_at, s.name AS strategy, r.risk_preference, r.remaining_money, r.status,
       r.engine_version, p.plan_month AS applied_to_plan_month, p.status AS plan_status
  FROM recommendations r
  JOIN strategies s            ON s.strategy_id = r.strategy_id
  LEFT JOIN monthly_plans p    ON p.recommendation_id = r.recommendation_id
 WHERE r.user_id = @p_user_id
 ORDER BY r.created_at DESC, r.recommendation_id DESC;

-- G3. One recommendation in full: allocation manifest (user ownership enforced in the WHERE).
-- Tables: recommendations, recommendation_allocations, allocation_buckets | Params: @p_user_id, @p_recommendation_id
SELECT ab.name AS bucket, ra.weight_pct, ra.amount
  FROM recommendations r
  JOIN recommendation_allocations ra ON ra.recommendation_id = r.recommendation_id
  JOIN allocation_buckets ab         ON ab.bucket_id = ra.bucket_id
 WHERE r.user_id = @p_user_id AND r.recommendation_id = @p_recommendation_id
 ORDER BY ab.sort_order;

-- G4. "Why this recommendation?" factors + "Cortex Insight" cards for one recommendation.
-- Tables: recommendations, recommendation_factors, recommendation_insights | Params: @p_user_id, @p_recommendation_id
SELECT 'factor' AS kind, rf.factor AS label, CAST(rf.weight_pct AS CHAR) AS value
  FROM recommendations r JOIN recommendation_factors rf ON rf.recommendation_id = r.recommendation_id
 WHERE r.user_id = @p_user_id AND r.recommendation_id = @p_recommendation_id
UNION ALL
SELECT 'insight', ri.title, ri.body
  FROM recommendations r JOIN recommendation_insights ri ON ri.recommendation_id = r.recommendation_id
 WHERE r.user_id = @p_user_id AND r.recommendation_id = @p_recommendation_id;

-- G5. Strategy reference (baseline weights per strategy) for the strategy cards.
-- Tables: strategies, strategy_bucket_weights, allocation_buckets | Params: none (public reference data)
SELECT s.name AS strategy, ab.name AS bucket, w.weight_pct
  FROM strategies s
  JOIN strategy_bucket_weights w ON w.strategy_id = s.strategy_id
  JOIN allocation_buckets ab     ON ab.bucket_id = w.bucket_id
 ORDER BY s.strategy_id, ab.sort_order;

-- =====================================================================
-- H. FINANCIAL HISTORY PAGE
-- =====================================================================

-- H1. Financial History table: Activity | Amount | Previous Value | Current Value | Result.
-- Tables: monthly_plans, plan_allocations, allocation_valuations, allocation_buckets
-- Params: @p_user_id, @p_plan_month | Returns: result = closing - opening, or 'Expense' for spend buckets.
SELECT ab.name AS activity, pa.allocated_amount AS amount, av.opening_value AS previous_value, av.closing_value AS current_value,
       CASE WHEN av.closing_value IS NULL THEN 'Expense' ELSE CAST(av.closing_value - av.opening_value AS CHAR) END AS result
  FROM monthly_plans p
  JOIN plan_allocations pa        ON pa.plan_id = p.plan_id
  JOIN allocation_buckets ab      ON ab.bucket_id = pa.bucket_id
  LEFT JOIN allocation_valuations av ON av.plan_id = pa.plan_id AND av.bucket_id = pa.bucket_id
 WHERE p.user_id = @p_user_id AND p.plan_month = DATE_SUB(@p_plan_month, INTERVAL 1 MONTH)
 ORDER BY ab.sort_order;

-- H2. Net investment performance of a plan (feeds the "Performance" chart & Continue/Modify/Review suggestion).
-- Tables: monthly_plans, allocation_valuations | Params: @p_user_id, @p_plan_month
-- Returns: opening_total, closing_total, gain_loss, return_pct (only buckets that have a closing value).
SELECT SUM(av.opening_value) AS opening_total, SUM(av.closing_value) AS closing_total,
       SUM(av.closing_value) - SUM(av.opening_value) AS gain_loss,
       ROUND(100 * (SUM(av.closing_value) - SUM(av.opening_value)) / NULLIF(SUM(av.opening_value), 0), 2) AS return_pct
  FROM monthly_plans p
  JOIN allocation_valuations av ON av.plan_id = p.plan_id AND av.closing_value IS NOT NULL
 WHERE p.user_id = @p_user_id AND p.plan_month = DATE_SUB(@p_plan_month, INTERVAL 1 MONTH);

-- =====================================================================
-- I. ACCOUNT / AUTH QUERIES (used by the backend, never by the browser)
-- =====================================================================

-- I1. Login: fetch the user + hash for the entered email. The BACKEND verifies the hash (argon2/bcrypt),
--     checks role matches the selected tab (frontend "role_mismatch"), status and lockout.
SELECT user_id, public_id, full_name, role, password_hash, status, failed_login_count, locked_until
  FROM users WHERE email = @p_email;

-- I2. After a failed login (lock the account for 15 minutes after 5 failures):
UPDATE users SET failed_login_count = failed_login_count + 1,
                 locked_until = IF(failed_login_count + 1 >= 5, DATE_ADD(CURRENT_TIMESTAMP, INTERVAL 15 MINUTE), locked_until)
 WHERE email = @p_email;

-- I3. After a successful login:
UPDATE users SET failed_login_count = 0, locked_until = NULL, last_login_at = CURRENT_TIMESTAMP WHERE email = @p_email;
