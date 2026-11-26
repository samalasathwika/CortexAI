-- =====================================================================
-- Cortex AI — DATABASE TEST SUITE
-- Run AFTER schema.sql and seed.sql (a fresh, local/dev database only).
-- Expected outcome: every row in the final result grid says PASS and the
-- summary row reads:  total_tests = 127 | passed = 127 | failed = 0
--
-- How it works
--   tmp_assert(...)        compares an expected value with an actual value
--   tmp_expect_error(...)  runs a statement that MUST be rejected and checks the MySQL error number
--     1451 = delete blocked by foreign key   1452 = insert blocked by foreign key
--     1062 = duplicate key                   3819 = CHECK constraint violated
--     1644 = rule raised by one of our triggers (SIGNAL)
-- Tests that change data run inside a transaction that is ROLLED BACK, so the
-- seed data is left untouched. The helper objects are dropped at the end.
-- =====================================================================
USE cortex_ai;
SET NAMES utf8mb4;
SET time_zone = '+00:00';

DROP TABLE IF EXISTS tmp_test_results;
CREATE TABLE tmp_test_results (          -- MEMORY engine: NOT affected by ROLLBACK, so results survive
  id INT AUTO_INCREMENT PRIMARY KEY,
  section VARCHAR(24), test_name VARCHAR(110), expected VARCHAR(80), actual VARCHAR(120), result CHAR(4)
) ENGINE=MEMORY;

DROP PROCEDURE IF EXISTS tmp_assert;
DROP PROCEDURE IF EXISTS tmp_expect_error;
DELIMITER $$
CREATE PROCEDURE tmp_assert(IN p_section VARCHAR(24), IN p_name VARCHAR(110), IN p_expected VARCHAR(80), IN p_actual VARCHAR(120))
BEGIN
  INSERT INTO tmp_test_results (section, test_name, expected, actual, result)
  VALUES (p_section, p_name, p_expected, p_actual, IF(p_expected <=> p_actual, 'PASS', 'FAIL'));
END$$

CREATE PROCEDURE tmp_expect_error(IN p_section VARCHAR(24), IN p_name VARCHAR(110), IN p_sql TEXT, IN p_errno INT)
BEGIN
  DECLARE v_errno INT DEFAULT 0;
  DECLARE v_msg VARCHAR(200) DEFAULT '';
  DECLARE CONTINUE HANDLER FOR SQLEXCEPTION, SQLWARNING   -- strict-mode "data truncated" is raised with a warning-class SQLSTATE
    BEGIN GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO, v_msg = MESSAGE_TEXT; END;
  SET @tmp_stmt = p_sql;
  PREPARE s FROM @tmp_stmt;
  EXECUTE s;
  DEALLOCATE PREPARE s;
  INSERT INTO tmp_test_results (section, test_name, expected, actual, result)
  VALUES (p_section, p_name, CONCAT('rejected (', IFNULL(p_errno, 'any'), ')'),
          IF(v_errno = 0, 'NOT REJECTED', CONCAT('rejected (', v_errno, ') ', LEFT(v_msg, 70))),
          IF(v_errno <> 0 AND (p_errno IS NULL OR p_errno = v_errno), 'PASS', 'FAIL'));
END$$
DELIMITER ;

-- handy ids from the seed data
SET @u1 = (SELECT user_id FROM users WHERE email = 'ananya.demo@example.com');
SET @u2 = (SELECT user_id FROM users WHERE email = 'rohan.demo@example.com');
SET @u3 = (SELECT user_id FROM users WHERE email = 'meera.demo@example.com');
SET @u4 = (SELECT user_id FROM users WHERE email = 'kiran.demo@example.com');
SET @b1_oct = (SELECT budget_id FROM monthly_budgets WHERE user_id = @u1 AND budget_month = '2026-10-01');
SET @b2_oct = (SELECT budget_id FROM monthly_budgets WHERE user_id = @u2 AND budget_month = '2026-10-01');
SET @hash   = CONCAT('$2b$12$', REPEAT('a', 53));       -- shape of a real bcrypt hash (for scratch rows only)

-- =====================================================================
-- 1. STRUCTURE — all tables, views, objects, engines, data types
-- =====================================================================
CALL tmp_assert('1 structure', 'Base tables in cortex_ai', '33',
  (SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='cortex_ai' AND table_type='BASE TABLE' AND table_name NOT LIKE 'tmp\\_%'));
CALL tmp_assert('1 structure', 'No expected table is missing', '',
  (SELECT IFNULL(GROUP_CONCAT(e.t), '') FROM (
     SELECT 'schema_migrations' t UNION ALL SELECT 'expense_category_groups' UNION ALL SELECT 'income_categories' UNION ALL SELECT 'expense_categories'
     UNION ALL SELECT 'role_expense_categories' UNION ALL SELECT 'goal_types' UNION ALL SELECT 'interest_options' UNION ALL SELECT 'allocation_buckets'
     UNION ALL SELECT 'strategies' UNION ALL SELECT 'strategy_bucket_weights' UNION ALL SELECT 'strategy_rationales' UNION ALL SELECT 'next_month_actions'
     UNION ALL SELECT 'next_month_action_tweaks' UNION ALL SELECT 'users' UNION ALL SELECT 'user_profiles' UNION ALL SELECT 'user_preferences'
     UNION ALL SELECT 'user_interests' UNION ALL SELECT 'user_sessions' UNION ALL SELECT 'password_reset_tokens' UNION ALL SELECT 'monthly_budgets'
     UNION ALL SELECT 'income_entries' UNION ALL SELECT 'expense_entries' UNION ALL SELECT 'financial_goals' UNION ALL SELECT 'goal_contributions'
     UNION ALL SELECT 'transactions' UNION ALL SELECT 'recommendations' UNION ALL SELECT 'recommendation_allocations' UNION ALL SELECT 'recommendation_factors'
     UNION ALL SELECT 'recommendation_insights' UNION ALL SELECT 'monthly_plans' UNION ALL SELECT 'plan_allocations' UNION ALL SELECT 'allocation_valuations'
     UNION ALL SELECT 'audit_logs') e
   LEFT JOIN information_schema.tables t ON t.table_schema='cortex_ai' AND t.table_name = e.t
   WHERE t.table_name IS NULL));
CALL tmp_assert('1 structure', 'Views exist (v_monthly_summary, v_plan_allocation_totals)', '2',
  (SELECT COUNT(*) FROM information_schema.views WHERE table_schema='cortex_ai' AND table_name IN ('v_monthly_summary','v_plan_allocation_totals')));
CALL tmp_assert('1 structure', 'All tables use InnoDB', '0',
  (SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='cortex_ai' AND table_type='BASE TABLE' AND engine <> 'InnoDB' AND table_name NOT LIKE 'tmp\\_%'));
CALL tmp_assert('1 structure', 'All tables use utf8mb4', '0',
  (SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='cortex_ai' AND table_type='BASE TABLE' AND table_collation NOT LIKE 'utf8mb4%'));
CALL tmp_assert('1 structure', 'Database default charset is utf8mb4', 'utf8mb4',
  (SELECT default_character_set_name FROM information_schema.schemata WHERE schema_name='cortex_ai'));
CALL tmp_assert('1 structure', 'No FLOAT/DOUBLE columns anywhere (money is DECIMAL)', '0',
  (SELECT COUNT(*) FROM information_schema.columns WHERE table_schema='cortex_ai' AND data_type IN ('float','double')));
CALL tmp_assert('1 structure', 'All money columns are DECIMAL(12,2)', '0',
  (SELECT COUNT(*) FROM information_schema.columns c JOIN information_schema.tables t ON t.table_schema = c.table_schema AND t.table_name = c.table_name
    WHERE c.table_schema='cortex_ai' AND t.table_type = 'BASE TABLE'
     AND c.column_name IN ('amount','target_amount','allocated_amount','remaining_money','opening_value','closing_value')
     AND c.column_type <> 'decimal(12,2)'));
CALL tmp_assert('1 structure', 'Foreign keys defined', '42',
  (SELECT COUNT(*) FROM information_schema.referential_constraints WHERE constraint_schema='cortex_ai'));
CALL tmp_assert('1 structure', 'CHECK constraints defined', '28',
  (SELECT COUNT(*) FROM information_schema.check_constraints WHERE constraint_schema='cortex_ai'));
CALL tmp_assert('1 structure', 'Triggers defined', '15',
  (SELECT COUNT(*) FROM information_schema.triggers WHERE trigger_schema='cortex_ai'));
CALL tmp_assert('1 structure', 'Stored procedures defined (excluding test helpers)', '7',
  (SELECT COUNT(*) FROM information_schema.routines WHERE routine_schema='cortex_ai' AND routine_type='PROCEDURE' AND routine_name NOT LIKE 'tmp\\_%'));
CALL tmp_assert('1 structure', 'Schema migration 001 recorded', '1',
  (SELECT COUNT(*) FROM schema_migrations WHERE version='001'));

-- =====================================================================
-- 2. REFERENCE DATA
-- =====================================================================
CALL tmp_assert('2 reference', '3 strategies, 9 buckets', '3/9',
  (SELECT CONCAT((SELECT COUNT(*) FROM strategies), '/', (SELECT COUNT(*) FROM allocation_buckets))));
CALL tmp_assert('2 reference', 'Every strategy has a weight for all 9 buckets', '0',
  (SELECT COUNT(*) FROM (SELECT strategy_id FROM strategy_bucket_weights GROUP BY strategy_id HAVING COUNT(*) <> 9) x));
CALL tmp_assert('2 reference', 'Every strategy\'s weights add up to exactly 100%', '0',
  (SELECT COUNT(*) FROM (SELECT strategy_id FROM strategy_bucket_weights GROUP BY strategy_id HAVING SUM(weight_pct) <> 100) x));
CALL tmp_assert('2 reference', 'Next-month action tweaks net to 0 points each', '0',
  (SELECT COUNT(*) FROM (SELECT action_id FROM next_month_action_tweaks GROUP BY action_id HAVING SUM(tweak_pct) <> 0) x));
CALL tmp_assert('2 reference', 'Employee sees 15 expense lines, student sees 14', '15/14',
  (SELECT CONCAT((SELECT COUNT(*) FROM role_expense_categories WHERE role='employee'), '/', (SELECT COUNT(*) FROM role_expense_categories WHERE role='student'))));
CALL tmp_assert('2 reference', '4 income categories, 9 goal types, 12 interest chips', '4/9/12',
  (SELECT CONCAT((SELECT COUNT(*) FROM income_categories), '/', (SELECT COUNT(*) FROM goal_types), '/', (SELECT COUNT(*) FROM interest_options))));
CALL tmp_assert('2 reference', 'Default strategy id used by user_profiles is "balanced"', 'balanced',
  (SELECT code FROM strategies WHERE strategy_id = 2));

-- =====================================================================
-- 3. SEED DATA SAFETY (demo accounts are clearly fictional; no plaintext passwords)
-- =====================================================================
CALL tmp_assert('3 seed safety', '4 demo users loaded', '4', (SELECT COUNT(*) FROM users WHERE is_demo = 1));
CALL tmp_assert('3 seed safety', 'Every demo user uses the reserved example.com domain', '0',
  (SELECT COUNT(*) FROM users WHERE is_demo = 1 AND email NOT LIKE '%@example.com'));
CALL tmp_assert('3 seed safety', 'No password is stored in plaintext (all bcrypt/argon2)', '0',
  (SELECT COUNT(*) FROM users WHERE password_hash NOT LIKE '$2_$%' AND password_hash NOT LIKE '$argon2%'));
CALL tmp_assert('3 seed safety', 'Seed has no card/bank/SSN-like columns in the schema', '0',
  (SELECT COUNT(*) FROM information_schema.columns WHERE table_schema='cortex_ai'
     AND (column_name LIKE '%card_number%' OR column_name LIKE '%cvv%' OR column_name LIKE '%bank_account%' OR column_name LIKE '%ssn%' OR column_name LIKE '%aadhaar%' OR column_name LIKE '%pan\\_%')));

-- =====================================================================
-- 4. CONSTRAINTS — invalid data must be rejected
-- =====================================================================
CALL tmp_expect_error('4 constraints', 'Negative income amount rejected',
  CONCAT('INSERT INTO income_entries (budget_id, income_category_id, amount) VALUES (', @b2_oct, ', 4, -1)'), 3819);
CALL tmp_expect_error('4 constraints', 'Negative expense amount rejected',
  CONCAT('INSERT INTO expense_entries (budget_id, category_id, amount) VALUES (', @b1_oct, ', 9, -50)'), 3819);
CALL tmp_expect_error('4 constraints', 'Absurdly large amount rejected (> 9,999,999,999.99)',
  CONCAT('INSERT INTO expense_entries (budget_id, category_id, amount) VALUES (', @b1_oct, ', 9, 99999999999)'), NULL);
CALL tmp_expect_error('4 constraints', 'Due day 0 rejected',
  CONCAT('INSERT INTO expense_entries (budget_id, category_id, amount, due_day) VALUES (', @b1_oct, ', 9, 10, 0)'), 3819);
CALL tmp_expect_error('4 constraints', 'Due day 32 rejected',
  CONCAT('INSERT INTO expense_entries (budget_id, category_id, amount, due_day) VALUES (', @b1_oct, ', 9, 10, 32)'), 3819);
CALL tmp_expect_error('4 constraints', 'Goal target of 0 rejected',
  CONCAT('INSERT INTO financial_goals (user_id, goal_type_id, target_amount) VALUES (', @u3, ', 1, 0)'), 3819);
CALL tmp_expect_error('4 constraints', 'Goal priority 6 rejected (must be 1-5)',
  CONCAT('INSERT INTO financial_goals (user_id, goal_type_id, priority) VALUES (', @u3, ', 1, 6)'), 3819);
CALL tmp_expect_error('4 constraints', 'Lifestyle slider above 60% rejected',
  CONCAT('UPDATE user_profiles SET lifestyle_pct = 61 WHERE user_id = ', @u1), 3819);
CALL tmp_expect_error('4 constraints', 'Negative allocation amount rejected (draft plan)',
  'UPDATE plan_allocations SET allocated_amount = -1 WHERE plan_id = 5 AND bucket_id = 1', 3819);
CALL tmp_expect_error('4 constraints', 'Allocation % above 100 rejected',
  'UPDATE plan_allocations SET baseline_pct = 101 WHERE plan_id = 5 AND bucket_id = 1', 3819);
CALL tmp_expect_error('4 constraints', 'Budget month must be the 1st of a month',
  CONCAT('INSERT INTO monthly_budgets (user_id, budget_month) VALUES (', @u4, ', ''2027-01-15'')'), 3819);
CALL tmp_expect_error('4 constraints', 'Invalid email format rejected',
  CONCAT('INSERT INTO users (email, password_hash, full_name, role) VALUES (''not-an-email'', ''', @hash, ''', ''X'', ''student'')'), 3819);
CALL tmp_expect_error('4 constraints', 'Plaintext-looking password (short hash) rejected',
  'INSERT INTO users (email, password_hash, full_name, role) VALUES (''plain@example.com'', ''Secret123'', ''X'', ''student'')', 3819);
CALL tmp_expect_error('4 constraints', 'Invalid role value rejected',
  CONCAT('INSERT INTO users (email, password_hash, full_name, role) VALUES (''r@example.com'', ''', @hash, ''', ''X'', ''admin'')'), NULL);
CALL tmp_expect_error('4 constraints', 'Transaction amount 0 rejected',
  CONCAT('INSERT INTO transactions (user_id, txn_type, category_id, amount, txn_date) VALUES (', @u1, ', ''expense'', 1, 0, ''2026-11-03'')'), 3819);
CALL tmp_expect_error('4 constraints', 'Transaction with BOTH income and expense category rejected',
  CONCAT('INSERT INTO transactions (user_id, txn_type, income_category_id, category_id, amount, txn_date) VALUES (', @u1, ', ''expense'', 1, 1, 10, ''2026-11-03'')'), 3819);
CALL tmp_expect_error('4 constraints', 'Allocation valuation with negative value rejected',
  'UPDATE allocation_valuations SET opening_value = -5 WHERE plan_id = 2 AND bucket_id = 1', 3819);

-- =====================================================================
-- 5. UNIQUE CONSTRAINTS & FOREIGN KEYS
-- =====================================================================
CALL tmp_expect_error('5 unique/FK', 'Duplicate email rejected',
  CONCAT('INSERT INTO users (email, password_hash, full_name, role) VALUES (''ananya.demo@example.com'', ''', @hash, ''', ''X'', ''student'')'), 1062);
CALL tmp_expect_error('5 unique/FK', 'Duplicate email rejected even with different letter case',
  CONCAT('INSERT INTO users (email, password_hash, full_name, role) VALUES (''ANANYA.DEMO@EXAMPLE.COM'', ''', @hash, ''', ''X'', ''student'')'), 1062);
CALL tmp_expect_error('5 unique/FK', 'Second budget for the same user+month rejected',
  CONCAT('INSERT INTO monthly_budgets (user_id, budget_month) VALUES (', @u1, ', ''2026-10-01'')'), 1062);
CALL tmp_expect_error('5 unique/FK', 'Same expense category twice in one budget rejected',
  CONCAT('INSERT INTO expense_entries (budget_id, category_id, amount) VALUES (', @b1_oct, ', 1, 10)'), 1062);
CALL tmp_expect_error('5 unique/FK', 'Same goal type twice for one user rejected',
  CONCAT('INSERT INTO financial_goals (user_id, goal_type_id) VALUES (', @u1, ', 4)'), 1062);
CALL tmp_expect_error('5 unique/FK', 'Second plan for the same user+target month rejected',
  CONCAT('INSERT INTO monthly_plans (user_id, strategy_id, plan_month, remaining_money, risk_preference) VALUES (', @u1, ', 2, ''2026-11-01'', 100, ''moderate'')'), 1062);
CALL tmp_expect_error('5 unique/FK', 'Duplicate custom category name for same user rejected',
  CONCAT('INSERT INTO expense_categories (user_id, name) VALUES (NULL, ''Rent'')'), 1062);
CALL tmp_expect_error('5 unique/FK', 'user_profiles row for a non-existent user rejected (FK)',
  'INSERT INTO user_profiles (user_id) VALUES (987654321)', 1452);
CALL tmp_expect_error('5 unique/FK', 'Budget for a non-existent user rejected (FK)',
  'INSERT INTO monthly_budgets (user_id, budget_month) VALUES (987654321, ''2026-12-01'')', 1452);
CALL tmp_expect_error('5 unique/FK', 'Goal contribution for a non-existent goal rejected (FK)',
  'INSERT INTO goal_contributions (goal_id, amount, contributed_on) VALUES (987654321, 10, ''2026-11-03'')', 1452);
CALL tmp_expect_error('5 unique/FK', 'Profile pointing at a non-existent strategy rejected (FK)',
  CONCAT('UPDATE user_profiles SET preferred_strategy_id = 99 WHERE user_id = ', @u1), 1452);

-- =====================================================================
-- 6. USER DATA ISOLATION (rules that foreign keys alone cannot express)
-- =====================================================================
START TRANSACTION;
INSERT INTO expense_categories (user_id, name) VALUES (@u2, 'ZZ test custom - Rohan only');
SET @cat_u2_custom = LAST_INSERT_ID();
CALL tmp_expect_error('6 isolation', 'User 1 cannot use user 2\'s custom category in a budget',
  CONCAT('INSERT INTO expense_entries (budget_id, category_id, amount) VALUES (', @b1_oct, ', ', @cat_u2_custom, ', 100)'), 1644);
CALL tmp_expect_error('6 isolation', 'User 1 cannot log a transaction in user 2\'s custom category',
  CONCAT('INSERT INTO transactions (user_id, txn_type, category_id, amount, txn_date) VALUES (', @u1, ', ''expense'', ', @cat_u2_custom, ', 10, ''2026-11-03'')'), 1644);
CALL tmp_expect_error('6 isolation', 'Employee cannot use a student-only category (Education)',
  CONCAT('INSERT INTO expense_entries (budget_id, category_id, amount) VALUES (', @b1_oct, ', 16, 100)'), 1644);
CALL tmp_expect_error('6 isolation', 'Student cannot use an employee-only category (Rent)',
  CONCAT('INSERT INTO expense_entries (budget_id, category_id, amount) VALUES (', @b2_oct, ', 1, 100)'), 1644);
CALL tmp_expect_error('6 isolation', 'Employee cannot record "Monthly Allowance" income',
  CONCAT('INSERT INTO income_entries (budget_id, income_category_id, amount) VALUES (', @b1_oct, ', 2, 100)'), 1644);
CALL tmp_expect_error('6 isolation', 'Student cannot record "Monthly Salary" income',
  CONCAT('INSERT INTO income_entries (budget_id, income_category_id, amount) VALUES (', @b2_oct, ', 1, 100)'), 1644);
CALL tmp_expect_error('6 isolation', 'A transaction cannot be re-assigned to another user',
  CONCAT('UPDATE transactions SET user_id = ', @u2, ' WHERE user_id = ', @u1, ' LIMIT 1'), 1644);
CALL tmp_expect_error('6 isolation', 'A plan cannot reference another user\'s budget',
  CONCAT('INSERT INTO monthly_plans (user_id, budget_id, strategy_id, plan_month, remaining_money, risk_preference) VALUES (', @u3, ', ', @b1_oct, ', 1, ''2027-02-01'', 100, ''conservative'')'), 1644);
CALL tmp_expect_error('6 isolation', 'A recommendation cannot reference another user\'s budget',
  CONCAT('INSERT INTO recommendations (user_id, budget_id, strategy_id, risk_preference, lifestyle_pct, remaining_money) VALUES (', @u3, ', ', @b1_oct, ', 1, ''conservative'', 10, 100)'), 1644);
CALL tmp_expect_error('6 isolation', 'A plan cannot reference another user\'s recommendation',
  CONCAT('INSERT INTO monthly_plans (user_id, recommendation_id, strategy_id, plan_month, remaining_money, risk_preference) VALUES (', @u3, ', 1, 1, ''2027-02-01'', 100, ''conservative'')'), 1644);
ROLLBACK;
CALL tmp_assert('6 isolation', 'Isolation test rows were rolled back', '0',
  (SELECT COUNT(*) FROM expense_categories WHERE name LIKE 'ZZ test custom%'));

-- Positive checks: the transactions in the seed all respect those rules
CALL tmp_assert('6 isolation', 'Every seeded expense transaction uses a category its owner may use', '0',
  (SELECT COUNT(*) FROM transactions t JOIN users u ON u.user_id = t.user_id JOIN expense_categories c ON c.category_id = t.category_id
    WHERE t.txn_type = 'expense'
      AND ((c.user_id IS NOT NULL AND c.user_id <> t.user_id)
        OR (c.user_id IS NULL AND NOT EXISTS (SELECT 1 FROM role_expense_categories r WHERE r.role = u.role AND r.category_id = c.category_id)))));
CALL tmp_assert('6 isolation', 'Every seeded budget line belongs to a budget of the same user\'s role', '0',
  (SELECT COUNT(*) FROM expense_entries ee JOIN monthly_budgets b ON b.budget_id = ee.budget_id JOIN users u ON u.user_id = b.user_id
    JOIN expense_categories c ON c.category_id = ee.category_id
    WHERE c.user_id IS NULL AND NOT EXISTS (SELECT 1 FROM role_expense_categories r WHERE r.role = u.role AND r.category_id = c.category_id)));
CALL tmp_assert('6 isolation', 'Seeded ledger rows per user (users 1-4)', '23/20/0/0',
  (SELECT CONCAT((SELECT COUNT(*) FROM transactions WHERE user_id = @u1), '/', (SELECT COUNT(*) FROM transactions WHERE user_id = @u2), '/',
                 (SELECT COUNT(*) FROM transactions WHERE user_id = @u3), '/', (SELECT COUNT(*) FROM transactions WHERE user_id = @u4))));

-- =====================================================================
-- 7. FINANCIAL CALCULATIONS (computed from tables, compared with hand-calculated values)
-- =====================================================================
CALL tmp_assert('7 calculations', 'User 1 Oct-2026 income = 58000', '58000.00', (SELECT total_income FROM v_monthly_summary WHERE budget_id = @b1_oct));
CALL tmp_assert('7 calculations', 'User 1 Oct-2026 expenses = 38500', '38500.00', (SELECT total_expenses FROM v_monthly_summary WHERE budget_id = @b1_oct));
CALL tmp_assert('7 calculations', 'User 1 Oct-2026 disposable income = 58000 - 38500 = 19500', '19500.00', (SELECT remaining_money FROM v_monthly_summary WHERE budget_id = @b1_oct));
CALL tmp_assert('7 calculations', 'User 2 Jun-2026 disposable income = 15000 - 13900 = 1100', '1100.00',
  (SELECT remaining_money FROM v_monthly_summary WHERE user_id = @u2 AND budget_month = '2026-06-01'));
CALL tmp_assert('7 calculations', 'Disposable income is never negative in any month', '0', (SELECT COUNT(*) FROM v_monthly_summary WHERE remaining_money < 0));
CALL tmp_assert('7 calculations', 'income - expenses = remaining - deficit for every month', '0',
  (SELECT COUNT(*) FROM v_monthly_summary WHERE total_income - total_expenses <> remaining_money - deficit));
CALL tmp_assert('7 calculations', 'Seeded plan bases equal the source month\'s disposable income', '0',
  (SELECT COUNT(*) FROM monthly_plans p JOIN v_monthly_summary s ON s.budget_id = p.budget_id WHERE p.remaining_money <> s.remaining_money));
CALL tmp_assert('7 calculations', 'Plan 3 (user 1, Nov) allocates exactly its 19500 base', '19500.00', (SELECT allocated_total FROM v_plan_allocation_totals WHERE plan_id = 3));
CALL tmp_assert('7 calculations', 'Plan 5 (draft, customised) leaves 380 unallocated', '380.00', (SELECT unallocated FROM v_plan_allocation_totals WHERE plan_id = 5));
CALL tmp_assert('7 calculations', 'No plan allocates more than its remaining money', '0',
  (SELECT COUNT(*) FROM v_plan_allocation_totals WHERE allocated_total > remaining_money));
CALL tmp_assert('7 calculations', 'Every locked/executed plan is fully allocated (sum = remaining)', '0',
  (SELECT COUNT(*) FROM v_plan_allocation_totals WHERE status IN ('locked','executed') AND allocated_total <> remaining_money));
CALL tmp_assert('7 calculations', 'Each plan has all 9 buckets', '0',
  (SELECT COUNT(*) FROM (SELECT plan_id FROM plan_allocations GROUP BY plan_id HAVING COUNT(*) <> 9) x));
CALL tmp_assert('7 calculations', 'Baseline % of every plan sums to 100', '0',
  (SELECT COUNT(*) FROM (SELECT plan_id FROM plan_allocations GROUP BY plan_id HAVING SUM(baseline_pct) <> 100) x));
CALL tmp_assert('7 calculations', 'Non-customised plans: amount = remaining x (baseline+adjustment)/100 in every bucket', '0',
  (SELECT COUNT(*) FROM plan_allocations pa JOIN monthly_plans p ON p.plan_id = pa.plan_id
    WHERE p.is_customized = 0 AND ABS(pa.allocated_amount - p.remaining_money * (pa.baseline_pct + pa.adjustment_pct) / 100) > 0.005));
CALL tmp_assert('7 calculations', 'User 1 Nov-plan savings rate = (7800+6825)/58000 = 25.22%', '25.22',
  (SELECT ROUND(100 * SUM(CASE WHEN ab.bucket_group IN ('saving','investment') THEN pa.allocated_amount ELSE 0 END) / s.total_income, 2)
     FROM monthly_plans p JOIN v_monthly_summary s ON s.budget_id = p.budget_id
     JOIN plan_allocations pa ON pa.plan_id = p.plan_id JOIN allocation_buckets ab ON ab.bucket_id = pa.bucket_id
    WHERE p.plan_id = 3 GROUP BY s.total_income));
CALL tmp_assert('7 calculations', 'Seeded Oct-2026 ledger for user 1 equals the budget expenses (38500)', '38500.00',
  (SELECT SUM(amount) FROM transactions WHERE user_id = @u1 AND txn_type = 'expense' AND txn_date BETWEEN '2026-10-01' AND '2026-10-31'));
CALL tmp_assert('7 calculations', 'Seeded Oct-2026 ledger income for user 1 equals the budget income (58000)', '58000.00',
  (SELECT SUM(amount) FROM transactions WHERE user_id = @u1 AND txn_type = 'income' AND txn_date BETWEEN '2026-10-01' AND '2026-10-31'));

-- 7b. The exact example from the brief, built from scratch in a rolled-back transaction
START TRANSACTION;
INSERT INTO users (email, password_hash, full_name, role, is_demo) VALUES ('scratch.calc@example.com', @hash, 'Scratch', 'employee', 1);
SET @sc = LAST_INSERT_ID();
INSERT INTO monthly_budgets (user_id, budget_month) VALUES (@sc, '2026-12-01');
SET @sb = LAST_INSERT_ID();
INSERT INTO income_entries (budget_id, income_category_id, amount) VALUES (@sb, 1, 30000);      -- salary
INSERT INTO expense_entries (budget_id, category_id, amount) VALUES (@sb, 1, 7000), (@sb, 4, 3000);  -- rent + food = 10000
CALL tmp_assert('7b brief example', 'Income 30000 - essentials 10000 = disposable 20000', '20000.00', (SELECT remaining_money FROM v_monthly_summary WHERE budget_id = @sb));
INSERT INTO monthly_plans (user_id, budget_id, strategy_id, plan_month, remaining_money, risk_preference)
  VALUES (@sc, @sb, 2, '2027-01-01', (SELECT remaining_money FROM v_monthly_summary WHERE budget_id = @sb), 'moderate');
SET @sp = LAST_INSERT_ID();
INSERT INTO plan_allocations (plan_id, bucket_id, baseline_pct, adjustment_pct, allocated_amount)
  SELECT @sp, w.bucket_id, w.weight_pct, 0, ROUND(20000 * w.weight_pct / 100, 2) FROM strategy_bucket_weights w WHERE w.strategy_id = 2;
CALL tmp_assert('7b brief example', 'Balanced: Savings 20% of 20000 = 4000', '4000.00', (SELECT allocated_amount FROM plan_allocations WHERE plan_id = @sp AND bucket_id = 1));
CALL tmp_assert('7b brief example', 'Balanced: allocations total exactly 20000 (not 30000)', '20000.00', (SELECT allocated_total FROM v_plan_allocation_totals WHERE plan_id = @sp));
UPDATE monthly_plans SET status = 'locked' WHERE plan_id = @sp;
CALL tmp_assert('7b brief example', 'Plan can be locked when fully allocated', 'locked', (SELECT status FROM monthly_plans WHERE plan_id = @sp));
CALL tmp_assert('7b brief example', 'Locking wrote an audit_logs row', '1', (SELECT COUNT(*) FROM audit_logs WHERE action = 'PLAN_LOCKED' AND entity_id = @sp));
ROLLBACK;

-- =====================================================================
-- 8. GOAL PROGRESS
-- =====================================================================
CALL tmp_assert('8 goals', 'User 1 Emergency Fund saved = 3320 + 3320... = 6600', '6600.00',
  (SELECT SUM(gc.amount) FROM financial_goals g JOIN goal_contributions gc ON gc.goal_id = g.goal_id WHERE g.user_id = @u1 AND g.goal_type_id = 4));
CALL tmp_assert('8 goals', 'User 1 Emergency Fund progress = 6600/150000 = 4.4%', '4.4',
  (SELECT ROUND(100 * SUM(gc.amount) / MAX(g.target_amount), 1) FROM financial_goals g JOIN goal_contributions gc ON gc.goal_id = g.goal_id WHERE g.user_id = @u1 AND g.goal_type_id = 4));
CALL tmp_assert('8 goals', 'User 1 Vacation progress = 3300/60000 = 5.5%', '5.5',
  (SELECT ROUND(100 * SUM(gc.amount) / MAX(g.target_amount), 1) FROM financial_goals g JOIN goal_contributions gc ON gc.goal_id = g.goal_id WHERE g.user_id = @u1 AND g.goal_type_id = 2));
CALL tmp_assert('8 goals', 'Goal with no contributions shows 0 saved (LEFT JOIN)', '0',
  (SELECT COALESCE(SUM(gc.amount), 0) FROM financial_goals g LEFT JOIN goal_contributions gc ON gc.goal_id = g.goal_id WHERE g.user_id = @u3 AND g.goal_type_id = 8));
CALL tmp_assert('8 goals', 'Goal with blank target (allowed by the UI) is stored with NULL target', '1',
  (SELECT COUNT(*) FROM financial_goals WHERE user_id = @u1 AND goal_type_id = 6 AND target_amount IS NULL AND deadline IS NULL));
CALL tmp_assert('8 goals', 'No seeded goal is over-funded (saved <= target)', '0',
  (SELECT COUNT(*) FROM (SELECT g.goal_id FROM financial_goals g JOIN goal_contributions gc ON gc.goal_id = g.goal_id
                          WHERE g.target_amount IS NOT NULL GROUP BY g.goal_id, g.target_amount HAVING SUM(gc.amount) > g.target_amount) x));

-- =====================================================================
-- 9. PLAN LIFECYCLE RULES
-- =====================================================================
CALL tmp_expect_error('9 plan rules', 'New plans must start as draft',
  CONCAT('INSERT INTO monthly_plans (user_id, strategy_id, plan_month, remaining_money, risk_preference, status) VALUES (', @u4, ', 3, ''2027-03-01'', 100, ''moderate'', ''locked'')'), 1644);
CALL tmp_expect_error('9 plan rules', 'Locked plan: allocation amount cannot be edited',
  'UPDATE plan_allocations SET allocated_amount = 1 WHERE plan_id = 3 AND bucket_id = 1', 1644);
CALL tmp_expect_error('9 plan rules', 'Locked plan: allocation cannot be deleted',
  'DELETE FROM plan_allocations WHERE plan_id = 3 AND bucket_id = 1', 1644);
CALL tmp_expect_error('9 plan rules', 'Locked plan: no allocation can be added',
  'INSERT INTO plan_allocations (plan_id, bucket_id, baseline_pct, allocated_amount) VALUES (3, 1, 20, 1)', 1644);
CALL tmp_expect_error('9 plan rules', 'Locked plan: remaining_money cannot change',
  'UPDATE monthly_plans SET remaining_money = 1 WHERE plan_id = 3', 1644);
CALL tmp_expect_error('9 plan rules', 'Executed plan cannot go back to draft',
  'UPDATE monthly_plans SET status = ''draft'' WHERE plan_id = 2', 1644);
CALL tmp_expect_error('9 plan rules', 'A plan cannot be moved to another user',
  CONCAT('UPDATE monthly_plans SET user_id = ', @u2, ' WHERE plan_id = 3'), 1644);
START TRANSACTION;
UPDATE plan_allocations SET allocated_amount = allocated_amount + 5000 WHERE plan_id = 5 AND bucket_id = 1;   -- now over budget (draft allows it, like the UI)
CALL tmp_assert('9 plan rules', 'Draft plan may be temporarily over budget (UI shows a warning)', '1',
  (SELECT COUNT(*) FROM v_plan_allocation_totals WHERE plan_id = 5 AND allocated_total > remaining_money));
CALL tmp_expect_error('9 plan rules', 'Over-allocated plan cannot be locked',
  'UPDATE monthly_plans SET status = ''locked'' WHERE plan_id = 5', 1644);
ROLLBACK;
START TRANSACTION;
UPDATE monthly_plans SET status = 'locked' WHERE plan_id = 5;     -- 3420 allocated of 3800: surplus is allowed
CALL tmp_assert('9 plan rules', 'Plan with unallocated surplus can be locked', 'locked', (SELECT status FROM monthly_plans WHERE plan_id = 5));
CALL tmp_assert('9 plan rules', 'locked_at is set automatically on lock', '1', (SELECT locked_at IS NOT NULL FROM monthly_plans WHERE plan_id = 5));
UPDATE monthly_plans SET status = 'draft' WHERE plan_id = 5;      -- "Unlock" button in the UI
CALL tmp_assert('9 plan rules', 'Unlock returns the plan to draft and clears locked_at', 'draft/1',
  (SELECT CONCAT(status, '/', locked_at IS NULL) FROM monthly_plans WHERE plan_id = 5));
ROLLBACK;
CALL tmp_assert('9 plan rules', 'Seed plans statuses: 3 executed, 2 locked, 2 draft', '3/2/2',
  (SELECT CONCAT(SUM(status='executed'), '/', SUM(status='locked'), '/', SUM(status='draft')) FROM monthly_plans));

-- =====================================================================
-- 10. DELETION BEHAVIOUR
-- =====================================================================
CALL tmp_expect_error('10 deletion', 'A used system category cannot be deleted (RESTRICT)', 'DELETE FROM expense_categories WHERE category_id = 1', 1451);
CALL tmp_expect_error('10 deletion', 'A strategy in use cannot be deleted (RESTRICT)', 'DELETE FROM strategies WHERE strategy_id = 2', 1451);
CALL tmp_expect_error('10 deletion', 'An allocation bucket in use cannot be deleted (RESTRICT)', 'DELETE FROM allocation_buckets WHERE bucket_id = 1', 1451);

START TRANSACTION;
SET @b4_oct = (SELECT budget_id FROM monthly_budgets WHERE user_id = @u4 AND budget_month = '2026-10-01');
DELETE FROM monthly_budgets WHERE budget_id = @b4_oct;
CALL tmp_assert('10 deletion', 'Deleting a budget cascades to its income & expense lines', '0/0',
  (SELECT CONCAT((SELECT COUNT(*) FROM expense_entries WHERE budget_id = @b4_oct), '/', (SELECT COUNT(*) FROM income_entries WHERE budget_id = @b4_oct))));
CALL tmp_assert('10 deletion', 'Deleting a budget keeps the plan built from it (budget_id -> NULL)', '1/1',
  (SELECT CONCAT(COUNT(*), '/', SUM(budget_id IS NULL)) FROM monthly_plans WHERE plan_id = 7));
ROLLBACK;
START TRANSACTION;
DELETE FROM monthly_plans WHERE plan_id = 4;
CALL tmp_assert('10 deletion', 'Deleting a plan cascades to allocations and valuations', '0/0',
  (SELECT CONCAT((SELECT COUNT(*) FROM plan_allocations WHERE plan_id = 4), '/', (SELECT COUNT(*) FROM allocation_valuations WHERE plan_id = 4))));
ROLLBACK;
START TRANSACTION;
DELETE FROM recommendations WHERE recommendation_id = (SELECT recommendation_id FROM monthly_plans WHERE plan_id = 3);
CALL tmp_assert('10 deletion', 'Deleting a recommendation keeps the plan (recommendation_id -> NULL) and removes its children', '1/0',
  (SELECT CONCAT((SELECT COUNT(*) FROM monthly_plans WHERE plan_id = 3 AND recommendation_id IS NULL), '/',
                 (SELECT COUNT(*) FROM recommendation_factors rf WHERE NOT EXISTS (SELECT 1 FROM recommendations r WHERE r.recommendation_id = rf.recommendation_id)))));
ROLLBACK;
CALL tmp_assert('10 deletion', 'Rolled-back deletions left the seed intact (22 budgets, 7 plans)', '22/7',
  (SELECT CONCAT((SELECT COUNT(*) FROM monthly_budgets), '/', (SELECT COUNT(*) FROM monthly_plans))));

-- 10b. Whole-account deletion: build a throw-away user with data in EVERY user-owned table, then erase it
INSERT INTO users (email, password_hash, full_name, role, is_demo) VALUES ('scratch.delete@example.com', @hash, 'Scratch Delete', 'employee', 1);
SET @d = LAST_INSERT_ID();
INSERT INTO user_profiles (user_id) VALUES (@d);
INSERT INTO user_preferences (user_id) VALUES (@d);
INSERT INTO user_interests (user_id, interest_id) VALUES (@d, 1);
INSERT INTO user_sessions (user_id, refresh_token_hash, expires_at) VALUES (@d, SHA2('scratch-token', 256), DATE_ADD(NOW(), INTERVAL 7 DAY));
INSERT INTO password_reset_tokens (user_id, token_hash, expires_at) VALUES (@d, SHA2('scratch-reset', 256), DATE_ADD(NOW(), INTERVAL 1 HOUR));
INSERT INTO expense_categories (user_id, name) VALUES (@d, 'Scratch custom line');
SET @dc = LAST_INSERT_ID();
INSERT INTO monthly_budgets (user_id, budget_month) VALUES (@d, '2027-01-01');
SET @db = LAST_INSERT_ID();
INSERT INTO income_entries (budget_id, income_category_id, amount) VALUES (@db, 1, 1000);
INSERT INTO expense_entries (budget_id, category_id, amount) VALUES (@db, @dc, 100), (@db, 1, 200);
INSERT INTO transactions (user_id, txn_type, category_id, amount, txn_date) VALUES (@d, 'expense', @dc, 50, '2027-01-03');
INSERT INTO financial_goals (user_id, goal_type_id, target_amount) VALUES (@d, 4, 5000);
INSERT INTO goal_contributions (goal_id, amount, contributed_on) VALUES (LAST_INSERT_ID(), 100, '2027-01-04');
INSERT INTO recommendations (user_id, budget_id, strategy_id, risk_preference, lifestyle_pct, remaining_money) VALUES (@d, @db, 2, 'moderate', 15, 700);
SET @dr = LAST_INSERT_ID();
INSERT INTO recommendation_allocations (recommendation_id, bucket_id, weight_pct, amount) VALUES (@dr, 1, 20, 140);
INSERT INTO recommendation_factors (recommendation_id, factor, weight_pct) VALUES (@dr, 'financial_goal', 30);
INSERT INTO recommendation_insights (recommendation_id, insight_type, title, body) VALUES (@dr, 'goal', 't', 'b');
INSERT INTO monthly_plans (user_id, budget_id, recommendation_id, strategy_id, plan_month, remaining_money, risk_preference) VALUES (@d, @db, @dr, 2, '2027-02-01', 700, 'moderate');
SET @dp = LAST_INSERT_ID();
INSERT INTO plan_allocations (plan_id, bucket_id, baseline_pct, allocated_amount) VALUES (@dp, 1, 20, 140);
INSERT INTO allocation_valuations (plan_id, bucket_id, opening_value) VALUES (@dp, 1, 140);
CALL tmp_assert('10 deletion', 'Throw-away user has rows in all 17 user-owned tables before deletion', '17',
  (SELECT (SELECT COUNT(*)>0 FROM user_profiles WHERE user_id=@d) + (SELECT COUNT(*)>0 FROM user_preferences WHERE user_id=@d) + (SELECT COUNT(*)>0 FROM user_interests WHERE user_id=@d)
        + (SELECT COUNT(*)>0 FROM user_sessions WHERE user_id=@d) + (SELECT COUNT(*)>0 FROM password_reset_tokens WHERE user_id=@d) + (SELECT COUNT(*)>0 FROM expense_categories WHERE user_id=@d)
        + (SELECT COUNT(*)>0 FROM monthly_budgets WHERE user_id=@d) + (SELECT COUNT(*)>0 FROM income_entries WHERE budget_id=@db) + (SELECT COUNT(*)>0 FROM expense_entries WHERE budget_id=@db)
        + (SELECT COUNT(*)>0 FROM transactions WHERE user_id=@d) + (SELECT COUNT(*)>0 FROM financial_goals WHERE user_id=@d) + (SELECT COUNT(*)>0 FROM goal_contributions WHERE contributed_on='2027-01-04')
        + (SELECT COUNT(*)>0 FROM recommendations WHERE user_id=@d) + (SELECT COUNT(*)>0 FROM recommendation_allocations WHERE recommendation_id=@dr)
        + (SELECT COUNT(*)>0 FROM recommendation_factors WHERE recommendation_id=@dr) + (SELECT COUNT(*)>0 FROM recommendation_insights WHERE recommendation_id=@dr)
        + (SELECT COUNT(*)>0 FROM monthly_plans WHERE user_id=@d)));
CALL sp_request_account_deletion(@d);
CALL tmp_assert('10 deletion', 'Deletion request marks the account pending_deletion', 'pending_deletion', (SELECT status FROM users WHERE user_id = @d));
CALL tmp_assert('10 deletion', 'Deletion request revokes active sessions and reset tokens', '0/0',
  (SELECT CONCAT((SELECT COUNT(*) FROM user_sessions WHERE user_id=@d AND revoked_at IS NULL), '/', (SELECT COUNT(*) FROM password_reset_tokens WHERE user_id=@d))));
CALL sp_purge_deleted_accounts(30);
CALL tmp_assert('10 deletion', 'Retention: account requested just now is NOT purged within 30 days', '1', (SELECT COUNT(*) FROM users WHERE user_id = @d));
UPDATE users SET deletion_requested_at = DATE_SUB(NOW(), INTERVAL 31 DAY) WHERE user_id = @d;
CALL sp_purge_deleted_accounts(30);
CALL tmp_assert('10 deletion', 'Retention: account past the 30-day grace period IS purged', '0', (SELECT COUNT(*) FROM users WHERE user_id = @d));
CALL tmp_assert('10 deletion', 'Purge removed every row the user owned (all child tables)', '0',
  (SELECT (SELECT COUNT(*) FROM monthly_budgets WHERE user_id=@d) + (SELECT COUNT(*) FROM income_entries WHERE budget_id=@db) + (SELECT COUNT(*) FROM expense_entries WHERE budget_id=@db)
        + (SELECT COUNT(*) FROM transactions WHERE user_id=@d) + (SELECT COUNT(*) FROM financial_goals WHERE user_id=@d) + (SELECT COUNT(*) FROM goal_contributions WHERE contributed_on='2027-01-04')
        + (SELECT COUNT(*) FROM recommendations WHERE user_id=@d) + (SELECT COUNT(*) FROM recommendation_allocations WHERE recommendation_id=@dr)
        + (SELECT COUNT(*) FROM monthly_plans WHERE user_id=@d) + (SELECT COUNT(*) FROM plan_allocations WHERE plan_id=@dp) + (SELECT COUNT(*) FROM allocation_valuations WHERE plan_id=@dp)
        + (SELECT COUNT(*) FROM expense_categories WHERE user_id=@d) + (SELECT COUNT(*) FROM user_sessions WHERE user_id=@d) + (SELECT COUNT(*) FROM user_profiles WHERE user_id=@d)));
CALL tmp_assert('10 deletion', 'Audit trail kept but anonymised (user_id NULL) after purge', '1',
  (SELECT COUNT(*) FROM audit_logs WHERE action = 'ACCOUNT_DELETED' AND entity_id = @d AND user_id IS NULL));
CALL tmp_assert('10 deletion', 'Other users untouched by the purge (4 demo users remain)', '4', (SELECT COUNT(*) FROM users WHERE is_demo = 1));
-- a plain one-statement DELETE also works (thanks to trg_users_bd)
INSERT INTO users (email, password_hash, full_name, role, is_demo) VALUES ('scratch.plain@example.com', @hash, 'Scratch Plain', 'student', 1);
SET @d2 = LAST_INSERT_ID();
INSERT INTO expense_categories (user_id, name) VALUES (@d2, 'Scratch custom 2');
SET @d2c = LAST_INSERT_ID();
INSERT INTO monthly_budgets (user_id, budget_month) VALUES (@d2, '2027-01-01');
INSERT INTO expense_entries (budget_id, category_id, amount) VALUES (LAST_INSERT_ID(), @d2c, 10);
INSERT INTO transactions (user_id, txn_type, category_id, amount, txn_date) VALUES (@d2, 'expense', @d2c, 5, '2027-01-03');
DELETE FROM users WHERE user_id = @d2;
CALL tmp_assert('10 deletion', 'Plain DELETE FROM users cascades cleanly (custom categories + their entries)', '0/0',
  (SELECT CONCAT((SELECT COUNT(*) FROM users WHERE user_id=@d2), '/', (SELECT COUNT(*) FROM expense_categories WHERE user_id=@d2))));
DELETE FROM audit_logs WHERE action IN ('ACCOUNT_DELETED','ACCOUNT_DELETION_REQUESTED') AND entity_id IN (@d, @d2);   -- tidy up test noise

-- =====================================================================
-- 11. INDEXES
-- =====================================================================
CALL tmp_assert('11 indexes', 'Every foreign key column is the first column of some index', '0',
  (SELECT COUNT(*) FROM information_schema.key_column_usage k
    WHERE k.table_schema = 'cortex_ai' AND k.referenced_table_name IS NOT NULL AND k.ordinal_position = 1
      AND NOT EXISTS (SELECT 1 FROM information_schema.statistics s WHERE s.table_schema = k.table_schema AND s.table_name = k.table_name
                         AND s.column_name = k.column_name AND s.seq_in_index = 1)));
CALL tmp_assert('11 indexes', 'Dashboard-critical indexes exist', '0',
  (SELECT COUNT(*) FROM (
     SELECT 'monthly_budgets' t, 'uq_mb_user_month' i UNION ALL SELECT 'expense_entries','uq_ee_budget_cat' UNION ALL SELECT 'income_entries','uq_ie_budget_cat'
     UNION ALL SELECT 'transactions','ix_tx_user_date' UNION ALL SELECT 'recommendations','ix_rec_user_created' UNION ALL SELECT 'monthly_plans','uq_mp_user_month'
     UNION ALL SELECT 'financial_goals','uq_fg_user_type' UNION ALL SELECT 'goal_contributions','ix_gc_goal_date' UNION ALL SELECT 'audit_logs','ix_al_user_created'
     UNION ALL SELECT 'users','uq_users_email' UNION ALL SELECT 'user_sessions','uq_us_token') e
   WHERE NOT EXISTS (SELECT 1 FROM information_schema.statistics s WHERE s.table_schema='cortex_ai' AND s.table_name = e.t AND s.index_name = e.i)));
CALL tmp_assert('11 indexes', 'Unique index on users.email', '0',
  (SELECT non_unique FROM information_schema.statistics WHERE table_schema='cortex_ai' AND table_name='users' AND index_name='uq_users_email' LIMIT 1));

-- =====================================================================
-- RESULTS
-- =====================================================================
SELECT id, section, test_name, expected, actual, result FROM tmp_test_results ORDER BY id;
SELECT COUNT(*) AS total_tests, SUM(result = 'PASS') AS passed, SUM(result = 'FAIL') AS failed,
       IF(SUM(result = 'FAIL') = 0, 'ALL TESTS PASSED', 'SOME TESTS FAILED - see rows marked FAIL above') AS verdict
  FROM tmp_test_results;

-- clean up helper objects (comment these 3 lines out if you want to inspect tmp_test_results afterwards)
DROP PROCEDURE IF EXISTS tmp_assert;
DROP PROCEDURE IF EXISTS tmp_expect_error;
DROP TABLE IF EXISTS tmp_test_results;
