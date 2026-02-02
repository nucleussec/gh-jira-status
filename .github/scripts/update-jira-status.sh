#!/bin/bash

# Update Jira Status Script
# Extracts Jira ticket from PR title and updates status to "Code Review"

PR_TITLE="$1"
JIRA_BASE_URL="$2"
JIRA_EMAIL="$3"
JIRA_API_TOKEN="$4"

echo "PR Title: $PR_TITLE"
echo ""

# Remove [HOTFIX] prefix if present
if [[ $PR_TITLE =~ ^\[HOTFIX\]\ (.+)$ ]]; then
    PR_TITLE="${BASH_REMATCH[1]}"
fi

# Extract Jira ticket ID (NUCLEUS-<number> or AUTO-<number>)
if [[ $PR_TITLE =~ ^(NUCLEUS|AUTO)-([0-9]+)_ ]]; then
    JIRA_PROJECT="${BASH_REMATCH[1]}"
    JIRA_ISSUE_NUMBER="${BASH_REMATCH[2]}"
    JIRA_TICKET="${JIRA_PROJECT}-${JIRA_ISSUE_NUMBER}"
    
    echo "✅ Found Jira ticket: $JIRA_TICKET"
else
    echo "ℹ️  No Jira ticket found in PR title. Skipping Jira update."
    exit 0
fi

# Validate required parameters
if [ -z "$JIRA_BASE_URL" ]; then
    echo "❌ Error: JIRA_BASE_URL is not set"
    exit 1
fi

if [ -z "$JIRA_EMAIL" ]; then
    echo "❌ Error: JIRA_EMAIL is not set"
    exit 1
fi

if [ -z "$JIRA_API_TOKEN" ]; then
    echo "❌ Error: JIRA_API_TOKEN is not set"
    exit 1
fi

# Get available transitions for the issue
echo ""
echo "Fetching available transitions for $JIRA_TICKET..."

TRANSITIONS_RESPONSE=$(curl -s -w "\n%{http_code}" \
    -u "${JIRA_EMAIL}:${JIRA_API_TOKEN}" \
    -H "Content-Type: application/json" \
    "${JIRA_BASE_URL}/rest/api/3/issue/${JIRA_TICKET}/transitions")

HTTP_CODE=$(echo "$TRANSITIONS_RESPONSE" | tail -n1)
TRANSITIONS_BODY=$(echo "$TRANSITIONS_RESPONSE" | sed '$d')

if [ "$HTTP_CODE" != "200" ]; then
    echo "❌ Failed to fetch transitions. HTTP Status: $HTTP_CODE"
    echo "Response: $TRANSITIONS_BODY"
    exit 1
fi

# Find the "Code Review" transition ID
# Common names: "Code Review", "In Code Review", "Ready for Code Review"
TRANSITION_ID=$(echo "$TRANSITIONS_BODY" | jq -r '.transitions[] | select(.name | test("Code Review"; "i")) | .id' | head -n1)

if [ -z "$TRANSITION_ID" ] || [ "$TRANSITION_ID" == "null" ]; then
    echo "⚠️  Warning: 'Code Review' transition not found for $JIRA_TICKET"
    echo "Available transitions:"
    echo "$TRANSITIONS_BODY" | jq -r '.transitions[] | "  - \(.name) (id: \(.id))"'
    echo ""
    echo "The issue may already be in Code Review or the transition is not available."
    exit 0
fi

echo "Found 'Code Review' transition with ID: $TRANSITION_ID"

# Perform the transition
echo ""
echo "Updating $JIRA_TICKET status to 'Code Review'..."

UPDATE_RESPONSE=$(curl -s -w "\n%{http_code}" \
    -X POST \
    -u "${JIRA_EMAIL}:${JIRA_API_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{\"transition\": {\"id\": \"${TRANSITION_ID}\"}}" \
    "${JIRA_BASE_URL}/rest/api/3/issue/${JIRA_TICKET}/transitions")

HTTP_CODE=$(echo "$UPDATE_RESPONSE" | tail -n1)
UPDATE_BODY=$(echo "$UPDATE_RESPONSE" | sed '$d')

if [ "$HTTP_CODE" == "204" ] || [ "$HTTP_CODE" == "200" ]; then
    echo "✅ Successfully updated $JIRA_TICKET to 'Code Review'!"
else
    echo "❌ Failed to update Jira status. HTTP Status: $HTTP_CODE"
    echo "Response: $UPDATE_BODY"
    exit 1
fi

echo ""
echo "🔗 Jira ticket: ${JIRA_BASE_URL}/browse/${JIRA_TICKET}"
exit 0

