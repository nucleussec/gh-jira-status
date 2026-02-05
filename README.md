
# AUTO-5: Jira Status Update Workflow - Implementation Report

## Ticket Summary

**Ticket:** AUTO-5  
**Title:** When certain pipeline triggers occur, update the Jira ticket status

### Original Requirements

1. **When a pipeline passes**, if the associated ticket is in "Self Review", automatically move it to "Code Review"
2. **When the pipeline is in any state beyond self-review** (starting with Code Review), if the PR pipelines fail, move the attached ticket to "Changes Requested"


## Implementation Overview

### Workflow File
**`.github/workflows/jira-status-update.yml`**

### Trigger
```yaml
on:
  pull_request:
    types: [opened, edited, synchronize, reopened]
```

The workflow runs whenever a PR is:
- Opened
- Edited (title changed)
- Synchronized (new commits pushed)
- Reopened

---

## Workflow Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    PR Title Check and Jira Status Update                    │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  Job 1: check-pr-title                                                      │
│  ────────────────────                                                       │
│  • Validates PR title format matches: [HOTFIX] PROJECT-123_description      │
│  • Validates branch name format                                             │
│  • Supported projects: NUCLEUS, AUTO                                        │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  Job 2: update-jira-status (depends on check-pr-title)                      │
│  ─────────────────────────                                                  │
│  • Extracts Jira ticket ID from PR title                                    │
│  • Verifies ticket exists in Jira                                           │
│  • Checks current status is eligible for transition                         │
│  • Updates ticket to "Review" status (transition ID: 51)                    │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                         ┌──────────┴──────────┐
                         │                     │
                      SUCCESS               FAILURE
                         │                     │
                         ▼                     ▼
                       Done     ┌─────────────────────────────────────────────┐
                                │  Job 3: notify-on-failure                   │
                                │  ────────────────────────                   │
                                │  • Extracts Jira ticket from PR title       │
                                │  • Moves ticket to "Changes Requested"      │
                                │    (only if status is beyond Self Review)   │
                                │  • Adds comment with link to failed run     │
                                └─────────────────────────────────────────────┘
```

---

## Supporting Scripts

| Script | Purpose |
|--------|---------|
| `check-pr-title.sh` | Validates PR title and branch name format |
| `verify-jira-ticket.sh` | Verifies ticket exists and checks if status allows transition to Review |
| `update-jira-status.sh` | Transitions ticket to "Review" status |
| `move-to-changes-requested.sh` | Moves ticket to "Changes Requested" on pipeline failure |

---

## Status Transition Logic

### On Pipeline Success → Move to "Review"

**Eligible statuses** (from `verify-jira-ticket.sh`):
- Backlog
- In Progress
- Selected for Development

If the ticket is in one of these statuses, it will be transitioned to **"Review"** (transition ID: 51).

### On Pipeline Failure → Move to "Changes Requested"

**Trigger statuses** (from `move-to-changes-requested.sh`):
- Review *(currently for testing)*
- Code Review
- Design Review
- QA Review
- QA In Progress
- Stakeholder Review
- Stakeholder Approved
- Merged Into Develop

If the ticket is in one of these statuses (beyond Self Review), it will be moved to **"Changes Requested"** (transition ID: 21 - currently set to "Selected for Development" for testing).

---

## Jira Workflow Reference

```
BACKLOG → READY → ACCEPTED FOR DEVELOPMENT → IN PROGRESS → SELF REVIEW
                                                              ↓
CHANGES REQUESTED ← CODE REVIEW ← DESIGN REVIEW ←────────────┘
        ↓               ↓
        └───────→ QA REVIEW → QA IN PROGRESS → STAKEHOLDER REVIEW 
                                                      ↓
                              RELEASED ← MERGED INTO DEVELOP ← STAKEHOLDER APPROVED
```

---

## Required GitHub Secrets

| Secret | Description |
|--------|-------------|
| `JIRA_BASE_URL` | Jira instance URL (e.g., `https://nucleussec.atlassian.net`) |
| `JIRA_EMAIL` | Email for Jira API authentication |
| `JIRA_API_TOKEN` | API token generated from Jira |

---

## Transition IDs Reference

| Status | Transition ID |
|--------|---------------|
| Backlog | 11 |
| Selected for Development | 21 |
| In Progress | 31 |
| Done | 41 |
| Review | 51 |

---

## TODOs / Notes

1. **`move-to-changes-requested.sh`**: The transition ID is currently hardcoded to `21` (Selected for Development) for testing. This should be updated to the actual "Changes Requested" transition ID when available.

2. **`move-to-changes-requested.sh`**: "Review" is included in `TRIGGER_STATUSES` for testing purposes and should be removed in production.

3. **Branch Protection**: To enforce these checks before merging, configure branch protection rules in GitHub Settings → Branches → Add rule → Require status checks (`check-pr-title`, `update-jira-status`).

---

## Benefits

1. **Automated status updates** - No manual Jira updates needed when opening PRs
2. **Faster feedback loop** - Tickets automatically move to "Changes Requested" when pipelines fail
3. **Avoids Bitbucket integration issues** - Custom implementation prevents the issue where GitHub↔Jira integration affects unrelated tickets in branch chains
4. **Audit trail** - Comments are added to Jira tickets with links to failed pipeline runs
