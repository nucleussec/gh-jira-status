#!/bin/bash

# Verify Jira Ticket Script
# Checks if a Jira ticket exists and validates its current status

JIRA_TICKET="$1"
JIRA_BASE_URL="$2"
JIRA_EMAIL="$3"
JIRA_API_TOKEN="$4"

# Statuses that allow transition to "Review"
ALLOWED_STATUSES=("Backlog" "In Progress" "Selected for Development")

# Validate required parameters
if [ -z "$JIRA_TICKET" ]; then
    echo "❌ Error: JIRA_TICKET is not provided"
    exit 1
fi

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

echo "Verifying Jira ticket: $JIRA_TICKET"

RESPONSE=$(curl -s -L -w "\nHTTP_CODE=%{http_code}" \
    -u "${JIRA_EMAIL}:${JIRA_API_TOKEN}" \
    -H "Accept: application/json" \
    "${JIRA_BASE_URL}/rest/api/3/issue/${JIRA_TICKET}?fields=status")

HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE=" | cut -d'=' -f2)
BODY=$(echo "$RESPONSE" | sed '/HTTP_CODE=/d')

if [ "$HTTP_CODE" != "200" ]; then
    echo "❌ Jira ticket $JIRA_TICKET not found or inaccessible. HTTP Status: $HTTP_CODE"
    echo "Response: $BODY"
    exit 1
fi

echo "✅ Jira ticket $JIRA_TICKET exists"

# Extract current status
CURRENT_STATUS=$(echo "$BODY" | jq -r '.fields.status.name')
echo "Current status: $CURRENT_STATUS"

# Output current status for GitHub Actions
if [ -n "$GITHUB_OUTPUT" ]; then
    echo "current_status=$CURRENT_STATUS" >> $GITHUB_OUTPUT
fi

# Check if current status is in allowed list
STATUS_ALLOWED=false
for status in "${ALLOWED_STATUSES[@]}"; do
    if [ "$CURRENT_STATUS" == "$status" ]; then
        STATUS_ALLOWED=true
        break
    fi
done

if [ "$STATUS_ALLOWED" == "true" ]; then
    echo "✅ Status '$CURRENT_STATUS' is eligible for transition to 'Review'"
    if [ -n "$GITHUB_OUTPUT" ]; then
        echo "should_update=true" >> $GITHUB_OUTPUT
    fi
    exit 0
else
    echo "ℹ️  Status '$CURRENT_STATUS' is not in the allowed list for transition"
    echo "Allowed statuses: ${ALLOWED_STATUSES[*]}"
    echo "Skipping Jira status update"
    if [ -n "$GITHUB_OUTPUT" ]; then
        echo "should_update=false" >> $GITHUB_OUTPUT
    fi
    exit 0
fi

