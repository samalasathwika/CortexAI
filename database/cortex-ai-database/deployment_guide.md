# Cortex AI — Database Deployment Guide

How to take `cortex_ai` from your laptop to a secure managed MySQL service.
Commands marked ✅ were rehearsed against a real MySQL 8.0.46 server while preparing this project (backup → restore, role creation, TLS login, permission-denied checks). Everything provider-specific (console menus, prices, free tiers) changes often — **check your provider's current documentation**.

---

## 1. Choosing a MySQL host

**Hard requirements** (the schema uses them): MySQL **8.0.19+**, InnoDB, **foreign keys**, **triggers**, **stored procedures**, CHECK constraints, `utf8mb4`, TLS.

> ⚠ Some "MySQL-compatible" services (for example distributed/serverless engines) restrict triggers, stored procedures or foreign keys. **Before you pick a provider, confirm in its current docs that all three work.** If not, the integrity rules in `schema.sql` section 8 would have to move into the backend.

| Option | Notes |
|---|---|
| **AWS RDS for MySQL / Aurora MySQL** | Mature; automated backups + point-in-time recovery (PITR); VPC private networking; parameter groups to force TLS. |
| **Google Cloud SQL for MySQL** | Automated backups, PITR, private IP, authorized networks, enforce SSL option. |
| **Azure Database for MySQL – Flexible Server** | Zone-redundant HA option, private access, enforce TLS parameter. |
| **DigitalOcean / Aiven / Linode managed MySQL** | Simpler and often cheaper for a student/startup project; trusted-sources (IP allow-list) and daily backups included on most plans. |

**Choosing guide:** for a student project start with the cheapest managed MySQL 8.0 on any of the above (a single small instance is enough); you can migrate later with `mysqldump`. Pick a **region close to your backend host** to keep latency low. Since the backend host is not chosen yet, choose the DB first and then put the backend in the same cloud/region if possible (this also lets you use private networking).

Sizing for this schema is tiny: ~33 tables, a few thousand rows per user at most. 1 vCPU / 1–2 GB RAM / 10–20 GB storage is plenty to start.

---

## 2. Create the database instance (provider-neutral)

1. Create a **MySQL 8.0** instance (not 5.7). Enable **automated backups**, **storage auto-grow** and, if offered, **deletion protection**.
2. Set the **admin ("root"/"admin") password** to a long random value from a password manager. This account is for *you only*.
3. Network: **do not make the instance open to the whole internet.**
   * Best: private networking (VPC / private IP) between the backend and DB.
   * If the backend has a public egress IP: allow-list **only that IP** (and your own IP for Workbench). Never `0.0.0.0/0`.
   * Serverless backends often lack a fixed IP — in that case use a provider that supports private networking/VPC connectors, or a managed proxy; do **not** open the DB to everyone to work around it.
4. Turn on **"require TLS/SSL"** (server parameter such as `require_secure_transport = ON`, or the provider's toggle).
5. Set the server time zone to **UTC** (`time_zone = '+00:00'`).
6. Download the provider's **CA certificate** (needed for verified TLS connections).

---

## 3. Create the database and import the schema

Connect as the admin user (see section 6 for Workbench). Then:

### 3a. Prepare `schema.sql` for production (important)

`schema.sql` starts with:

```sql
DROP DATABASE IF EXISTS cortex_ai;
CREATE DATABASE cortex_ai ...
```

* On a **brand-new, empty** production instance that is fine, **but delete the `DROP DATABASE` line first** so the script can never wipe data if re-run by mistake.
* If your provider already created an empty `cortex_ai` database (or your admin can't `CREATE DATABASE`), delete the `CREATE DATABASE` line too and keep `USE cortex_ai;`.
* **After the first production deployment never run `schema.sql` again.** Use migration files (section 9).

### 3b. Import

**Workbench:** `File → Open SQL Script → schema.sql → ⚡ Execute`.

**Command line** (verified TLS):

```bash
mysql --host=<db-host> --port=3306 --user=<admin-user> -p \
      --ssl-mode=VERIFY_IDENTITY --ssl-ca=/path/to/provider-ca.pem \
      < schema.sql
```

Verify: the last result shows `tables_created = 33`. Then run `SHOW TRIGGERS FROM cortex_ai;` (15 rows) and `SHOW PROCEDURE STATUS WHERE Db='cortex_ai';` (7 rows).

> If the import fails with *"Access denied; you need SUPER or SET_USER_ID privilege"* when creating triggers/procedures, your provider requires a parameter such as `log_bin_trust_function_creators = 1` (AWS RDS parameter group, GCP flag). Set it, then re-run.

---

## 4. Secure database users (least privilege)

1. Edit the top of `security.sql`:
   * `@app_host` → your **backend's fixed IP/CIDR** (not `%`).
   * `@admin_host` → your office/VPN IP (or provider-required value).
   * Replace all four placeholder passwords with **random 24+ character secrets** (`openssl rand -base64 36`). The script **refuses to run** while placeholders remain ✅.
2. Run it once as admin. ✅ Rehearsed result:
   * `cortex_app` can read/write user data but **cannot** `DROP`/`ALTER`, **cannot** edit reference data, **cannot** read or delete `audit_logs` (insert-only), **cannot** touch `schema_migrations`, **cannot** run the purge procedures, and a connection **without TLS is refused**.
   * `sp_lock_plan(plan, wrong_user)` is rejected — authorization inside the call.
3. Remove the passwords from the file / shell history afterwards. **Never commit `security.sql` with real passwords.**

| User | Used by | Can do |
|---|---|---|
| `cortex_app` | backend API at runtime | CRUD on user data, read reference data, insert audit rows, run `sp_lock_plan`, `sp_request_account_deletion` |
| `cortex_maint` | scheduled jobs | run purge procedures only |
| `cortex_analyst` | optional BI/reporting | read-only on budgets/plans (no emails/passwords/sessions/audit) |
| `cortex_migrator` | CI/deploy pipeline | DDL changes; not used at runtime |

Managed-service notes: if the provider rejects a clause (for example `FAILED_LOGIN_ATTEMPTS` or `REQUIRE SSL` because TLS is already forced) remove just that clause. If `CREATE ROLE` is not permitted, grant the same privileges directly to each user.

---

## 5. Importing sample data

* **Development / staging only:** `seed.sql` (4 fictional demo accounts, password `Demo@12345`).
* **Never load `seed.sql` into production.** If it was loaded by accident:

```sql
DELETE FROM users WHERE is_demo = 1;   -- removes demo accounts and ALL their data (cascades)
```

Import: Workbench → open `seed.sql` → ⚡ Execute, or `mysql … cortex_ai < seed.sql`. Then optionally `test_database.sql` (also dev/staging only — it creates and deletes scratch users).

---

## 6. Connecting

### 6a. MySQL Workbench (you, for administration)

1. Home → `MySQL Connections ⊕`.
2. *Connection Name:* `cortex-prod`; *Hostname/Port/Username:* from the provider; **Password → Store in Vault** (or enter each time).
3. **SSL tab:** *Use SSL = Require and Verify Identity* (or *Require and Verify CA*) and set *SSL CA File* to the provider certificate.
4. *Test Connection*. Your IP must be on the provider's allow-list.
5. Use the **admin** user for schema work; use `cortex_analyst` for read-only exploration so you can't change data by accident.
6. Preferences → SQL Editor → tick **"Safe Updates"** (default) to block `UPDATE`/`DELETE` without a `WHERE`.

### 6b. Backend developer

Give the backend developer **only**: host, port, database name, the `cortex_app` credentials (through a secret manager / the host's encrypted environment variables), and the CA certificate file.

* Suggested environment variables: `DB_HOST`, `DB_PORT`, `DB_NAME=cortex_ai`, `DB_USER=cortex_app`, `DB_PASSWORD`, `DB_SSL_CA`.
* Always **TLS with certificate verification** (not "skip verify").
* Use a **connection pool** (≈10–20 connections; the `cortex_app` user is capped at 40).
* Session settings on connect: `SET time_zone='+00:00'; SET sql_mode` left at the strict MySQL 8 default.
* **Parameterized queries only** (`?` placeholders) — `queries.sql` is written for this. Never concatenate user input into SQL.
* `user_id` always comes from the verified session/JWT, never from the request.
* Do **not** log SQL parameters for `users`, `password_reset_tokens` or `user_sessions`.

### 6c. Keeping credentials secret

* The browser (Vercel frontend) **never** connects to MySQL and never sees any DB credential.
* Add to `.gitignore`: `.env`, `*.pem`, `*.key`, any file containing real passwords.
* If a credential is ever committed to GitHub, treat it as compromised: **rotate it immediately** (`ALTER USER 'cortex_app'@'host' IDENTIFIED BY '<new>'`) — deleting the commit is not enough.
* Rotate DB passwords at least every 180 days (the accounts are set to expire then).

---

## 7. Backup and recovery

**Provider backups (primary):** enable automated daily snapshots **and point-in-time recovery**; retention **7–14 days minimum** (30 for production). Enable cross-region copy if your provider offers it and the budget allows.

**Logical backups (secondary, portable)** ✅ rehearsed — dumped, restored into a new database, and confirmed 4 users / 15 triggers / 7 routines / 42 foreign keys came back:

```bash
mysqldump --host=<db-host> --user=<admin-user> -p --ssl-mode=VERIFY_IDENTITY --ssl-ca=provider-ca.pem \
  --single-transaction --routines --triggers --events --set-gtid-purged=OFF --hex-blob \
  cortex_ai > cortex_ai_$(date +%F).sql
```

* Encrypt the file (`gpg -c …`) and store it **off-site** (a private bucket with versioning). A dump contains financial data — treat it as sensitive.
* **Test a restore at least quarterly** into a throw-away database (a backup you have never restored is not a backup):

```bash
mysql -u <admin> -p -e "CREATE DATABASE cortex_ai_restore_test CHARACTER SET utf8mb4"
mysql -u <admin> -p cortex_ai_restore_test < cortex_ai_2026-11-04.sql   # dump rewritten to the new db name
```

* **Recovery targets** (suggested): RPO ≤ 24 h (≤ 5 min with PITR), RTO ≤ 4 h. Write down who can trigger a restore.
* After restoring a backup, **re-run the account deletions requested since the backup was taken** — otherwise a user who asked to be erased can reappear. Keep a log of deletion requests (`audit_logs` actions `ACCOUNT_DELETION_REQUESTED` / `ACCOUNT_DELETED`, which survive anonymised).

---

## 8. Data retention, account deletion and financial privacy

| Data | Retention (suggested — adjust to the law that applies to you) | How |
|---|---|---|
| Active user's financial data | While the account is active | — |
| Deleted account | **30-day grace**, then hard-erased | app calls `sp_request_account_deletion(user_id)` → scheduler runs `CALL sp_purge_deleted_accounts(30)` daily as `cortex_maint` |
| Expired/used reset tokens, old sessions | 7 days after expiry | `CALL sp_purge_expired_security_data(365)` daily |
| Audit log | 12 months | same procedure (argument = days) |
| Backups | Contain deleted users until they age out (7–30 days) — state this in your privacy policy | — |

* Account deletion is complete: all budgets, goals, plans, recommendations, ledger rows, sessions, tokens and custom categories are removed; audit rows are kept but anonymised (`user_id` → NULL). ✅ tested.
* **Privacy design:** the schema contains **no card numbers, bank account numbers/passwords or government IDs**, and a test asserts it. Do not let free-text fields (`transactions.description`, `goal_contributions.note`) be used for such data — validate in the backend.
* Provide users a data export (a backend endpoint running the user-scoped queries) and a delete-account button wired to `sp_request_account_deletion` — these are typical privacy-law expectations (check GDPR/DPDP applicability with a qualified adviser; this guide is not legal advice).
* **Encrypt at rest:** enable the provider's storage encryption when creating the instance (usually cannot be added later).
* Mask emails/amounts in application logs.

---

## 9. Migration strategy

The database changes over time (Phase-2 UI, new strategies…). Use **versioned migration files**, never edit production by hand.

1. **Freeze `schema.sql` as version `001`** (already recorded in `schema_migrations`). After the first production deploy it is history, not a runnable script.
2. Create `migrations/V002__short_description.sql`, `V003__…` — **one change per file, forward-only, never edited after being applied**. Each ends with:
   ```sql
   INSERT INTO schema_migrations (version, description) VALUES ('002', 'Add title to financial_goals');
   ```
3. Apply with a tool (Flyway, Liquibase, or your backend's migration runner) using the `cortex_migrator` account — in **CI**, not from laptops.
4. **Safe-change pattern ("expand → migrate → contract")** to avoid downtime: add the new column/table (nullable) → deploy backend that writes both → backfill → switch reads → drop the old column in a later migration.
5. **Always:** take a snapshot/backup immediately before each production migration; run the migration on a restored copy of production first; keep a rollback script for each file.
6. After any migration run `test_database.sql` on staging (update expected counts in its header if tables/triggers changed) and regenerate `data_dictionary.md` / `er_diagram.mmd`.
7. Known future migrations: allow several goals per type (drop `uq_fg_user_type`, add `title`); add `currency` if multi-currency is needed; add a partition/archival job for `audit_logs` if it grows large.

---

## 10. Production deployment checklist

**Before go-live**

- [ ] MySQL 8.0.19+ instance, **encryption at rest** on, **automated backups + PITR** on, retention ≥ 14 days
- [ ] Verified the provider supports triggers, stored procedures, foreign keys
- [ ] Network: private/IP-allow-listed only; **not** open to the internet; **TLS required**
- [ ] Server time zone UTC
- [ ] `DROP DATABASE` line removed from `schema.sql`; schema imported; 33 tables / 15 triggers / 7 procedures present
- [ ] `security.sql` run with strong unique passwords; placeholders gone; `cortex_app` tested (cannot `DROP`, cannot read `audit_logs`)
- [ ] **No demo data**: `SELECT COUNT(*) FROM users WHERE is_demo = 1;` returns 0
- [ ] **Hard-coded demo credentials removed from the frontend JS**
- [ ] Credentials stored only in the backend's secret store; none in GitHub or Vercel frontend variables
- [ ] Backend uses parameterized queries and filters **every** query by the authenticated `user_id`
- [ ] Backend uses TLS with certificate verification; connection pool configured
- [ ] Passwords hashed with argon2id/bcrypt in the backend; login throttling implemented
- [ ] Scheduled jobs created: `sp_purge_deleted_accounts(30)`, `sp_purge_expired_security_data(365)`, month-end valuations
- [ ] A full **restore test** completed successfully
- [ ] Monitoring/alerts: CPU, storage, connections, replication/backup failures, slow-query log on
- [ ] Privacy policy states retention and deletion behaviour
- [ ] Migration pipeline in place (`cortex_migrator` used only by CI)
- [ ] `test_database.sql` passed on staging with the same schema

**Operational habits**

- [ ] Rotate DB passwords every ≤ 180 days; revoke access of people who leave
- [ ] Review `audit_logs` for repeated `LOGIN_FAILED` and unexpected `PLAN_*` events
- [ ] Keep MySQL patched (enable the provider's minor-version auto-upgrade in a maintenance window)
- [ ] Quarterly restore drill; annual access review of all DB accounts
