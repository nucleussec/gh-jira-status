# augment_pr
testing augment_pr tool

TO get transition id
curl -u your_email:JIRA_TOKEN\
  -X GET \
  -H "Accept: application/json" \
  https://nucleussec.atlassian.net/rest/api/3/issue/AUTO-25/transitions

To update status REVIEW is 51 in my case. 
curl -u your_email:JIRA_TOKEN \
  -X POST \
  -H "Accept: application/json" \
  -H "Content-Type: application/json" \
  https://nucleussec.atlassian.net/rest/api/3/issue/AUTO-25/transitions \
  -d '{"transition":{"id":"51"}}'

curl -s -u "ssadvakassov@nucleussec.com:JIRA_TOKEN" \
  -H "Accept: application/json" \
  "https://nucleussec.atlassian.net/rest/api/3/issue/AUTO-25?fields=status" \
  -w "\nHTTP_CODE=%{http_code}\n"


BACKLOG → READY → ACCEPTED FOR DEVELOPMENT → IN PROGRESS → SELF REVIEW
                                                              ↓
CHANGES REQUESTED ← CODE REVIEW ← DESIGN REVIEW ←────────────┘
        ↓               ↓
        └───────→ QA REVIEW → QA IN PROGRESS → STAKEHOLDER REVIEW 
                                                      ↓
                              RELEASED ← MERGED INTO DEVELOP ← STAKEHOLDER APPROVED;



PR Pipeline Fails
       ↓
jira-pipeline-failure.yml triggers (workflow_run event)
       ↓
Get PR info → Extract Jira ticket
       ↓
move-to-changes-requested.sh
       ↓
Check current status → Is it beyond Self Review?
       ↓
  YES → Move to "Changes Requested" + Add comment with link
  NO  → Do nothing (ticket stays in current status)