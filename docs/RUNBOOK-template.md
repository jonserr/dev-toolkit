# [PROJECT NAME] Runbook

| Field | Value |
| --- | --- |
| Repository | [REPOSITORY URL] |
| Primary contact | [NAME / TEAM] |
| Issue tracker | [URL] |
| Last verified | [YYYY-MM-DD] |
| Next review | [YYYY-MM-DD] |

**Purpose:** Describe how to access, develop, test, deploy, and troubleshoot the application in each environment.

> Do not store passwords, tokens, or sensitive production records in this file. Reference the approved secret store instead.

---

## 1. Environments

| Environment | Host | URL | Directory | Branch |
| --- | --- | --- | --- | --- |
| Development | [DEV_HOSTNAME] | [DEV_URL] | [DEV_DIRECTORY] | [DEV_BRANCH] |
| Testing | [TEST_HOSTNAME] | [TEST_URL] | [TEST_DIRECTORY] | [TEST_BRANCH] |
| Production | [PROD_HOSTNAME] | [PROD_URL] | [PROD_DIRECTORY] | [PROD_BRANCH] |

| Item | Value |
| --- | --- |
| Service name | [SERVICE_NAME] |
| Log location | [LOG_DIRECTORY] |
| Configuration | [CONFIG_DIRECTORY / .env] |
| Database | [TYPE] at [HOST / FILE_PATH], database [NAME] |

---

## 2. Access

### 2.1 Repository

- **Access request:** [ACCESS REQUEST URL]
- **Required permission:** [READ / WRITE / ADMIN]
- **Approver:** [NAME / TEAM]

1. Request access at [ACCESS REQUEST URL].
2. Complete the required approval or authentication.
3. Run `git ls-remote [REPOSITORY URL]` to verify access.

### 2.2 Servers

- **Authentication:** [SSH KEY / KERBEROS / SSO]
- **Network:** [VPN OR NETWORK REQUIREMENT]
- **Server administrator:** [NAME / CONTACT]

```bash
# Connect to testing (production access is limited to authorized users)
ssh [USERNAME]@[TEST_HOSTNAME]

# Verify user, host, and directory
whoami && hostname && pwd
```

---

## 3. Local development

### 3.1 Setup

```bash
git clone [REPOSITORY URL]
cd [PROJECT_DIRECTORY]
make setup                  # installs dependencies, creates .env from .env.example
make up                     # starts local services (database, cache)
make check                  # runs lint and tests
```

### 3.2 Change workflow

```bash
git switch [DEV_BRANCH]
git pull --ff-only
git switch -c feature/[CHANGE_NAME]

# Edit, then verify
make check

git add [FILES]
git commit -m "feat: [SHORT DESCRIPTION]"
git push -u origin feature/[CHANGE_NAME]
```

1. Open a pull request into [DEV_BRANCH].
2. Get [N] approvals according to [BRANCH POLICY].
3. Merge after CI passes.

---

## 4. Testing deployment

```bash
ssh [USERNAME]@[TEST_HOSTNAME]
cd [TEST_DIRECTORY]

git status                              # confirm clean working tree
git pull --ff-only origin [TEST_BRANCH]

[DEPLOY_COMMAND]                        # rebuild or reinstall
[RESTART_COMMAND]                       # restart service
[STATUS_COMMAND]                        # confirm service is running
```

> Pulling code does not update the running application by itself. Run the deploy and restart commands.

**Verification checklist:**

- [ ] Application starts and `[STATUS_COMMAND]` reports healthy
- [ ] [TEST_URL] loads and shows the change
- [ ] Backend and database behavior is correct
- [ ] Demo dataset in section 6 produces the expected output
- [ ] No new errors in [LOG_DIRECTORY]

---

## 5. Production deployment and rollback

| Item | Value |
| --- | --- |
| Deploy command | [PROD_DEPLOY_COMMAND] |
| Restart command | [PROD_RESTART_COMMAND] |
| Status command | [STATUS_COMMAND] |
| Rollback procedure | [ROLLBACK_COMMAND / LINK] |
| Deployment approver | [NAME / TEAM] |

1. Confirm that the change passed testing and has approval.
2. Record the current version: `git -C [PROD_DIRECTORY] rev-parse --short HEAD`.
3. Deploy with [PROD_DEPLOY_COMMAND].
4. Restart the service if required.
5. Verify health and monitor logs for 15 minutes.
6. If verification fails, roll back to the recorded version:

```bash
cd [PROD_DIRECTORY]
git checkout [LAST_GOOD_COMMIT]
[PROD_DEPLOY_COMMAND]
[PROD_RESTART_COMMAND]
```

---

## 6. Application components

### 6.1 Frontend

- **Source directory:** [FRONTEND_DIRECTORY]
- **Login requirement:** [AUTH / ROLE]

```bash
cd [FRONTEND_DIRECTORY]
[BUILD_COMMAND]
[FRONTEND_RESTART_COMMAND]
```

### 6.2 Backend

- **Source directory:** [BACKEND_DIRECTORY]
- **API base URL:** [BACKEND_URL]

```bash
[BACKEND_STATUS_COMMAND]                # for example: systemctl status [SERVICE_NAME]
[VIEW_LOGS_COMMAND]                     # for example: journalctl -u [SERVICE_NAME] -n 100
curl -fsS [BACKEND_URL]/health          # health endpoint
```

### 6.3 Database

- **Access role:** [READ-ONLY ROLE]
- **Schema reference:** [LINK]
- **Backup and restore contact:** [NAME / TEAM]

```bash
[DATABASE_CONNECTION_COMMAND]           # for example: psql "$DATABASE_URL"
```

```sql
-- Read-only checks
SELECT * FROM [TABLE_NAME] LIMIT 10;
SELECT COUNT(*) FROM [TABLE_NAME];
```

### 6.4 Demo dataset

- **Location:** [DEMO_DATA_DIRECTORY]/[DEMO_FILENAME]
- **Format:** [CSV / JSON / OTHER]
- **Expected output:** [OUTPUT_DIRECTORY] contains [EXPECTED RESULT]

```bash
head -n 10 [DEMO_DATA_DIRECTORY]/[DEMO_FILENAME]
[TEST_WORKFLOW_COMMAND]
```

Use synthetic or approved de-identified data only.

---

## 7. Troubleshooting

| Symptom | Checks | Fix or escalation |
| --- | --- | --- |
| Application does not start | `[STATUS_COMMAND]`, logs in [LOG_DIRECTORY] | Fix configuration, run `[RESTART_COMMAND]` |
| Change does not appear | Correct host, branch, and commit, deploy step ran, browser cache | Rerun deploy and restart |
| Database connection fails | Service running, credentials in secret store, network | Escalate to [DATABASE CONTACT] |
| Port already in use | `lsof -i :[PORT]` | Stop the old process or change the port |
| Disk full | `df -h`, `du -sh [LOG_DIRECTORY]` | Rotate or archive logs |

---

## 8. Contacts

| Role | Name | Contact |
| --- | --- | --- |
| Project owner | [NAME] | [CONTACT] |
| Development lead | [NAME] | [CONTACT] |
| System administrator | [NAME] | [CONTACT] |
| Database administrator | [NAME] | [CONTACT] |
| Production support | [NAME] | [CONTACT] |

Update this runbook when access, directories, commands, or deployment steps change.
