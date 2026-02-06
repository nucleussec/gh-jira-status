#!/bin/bash

# Move to Changes Requested Script
# Moves a Jira ticket to "Changes Requested" status when PR pipeline fails
# Only applies to tickets that are beyond "Self Review" stage

JIRA_TICKET="$1"
JIRA_BASE_URL="$2"
JIRA_EMAIL="$3"
JIRA_API_TOKEN="$4"
FAILED_RUN_URL="$5"
TRANSITION_ID="21" # This is the transition id for "Selected for Development" in my case. It should be replaced with "Changes Requested" when it will be implemented.
# Statuses that should trigger move to "Changes Requested" on pipeline failure
# These are statuses beyond "Self Review" in the workflow
TRIGGER_STATUSES=(
    "Review"  # @ TODO: This should be removed. Only for testing purposes.
    "Code Review"
    "Design Review"
    "QA Review"
    "QA In Progress"
    "Stakeholder Review"
    "Stakeholder Approved"
)

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

echo "🔍 Checking Jira ticket: $JIRA_TICKET"

# Get current ticket status
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

# Extract current status
CURRENT_STATUS=$(echo "$BODY" | jq -r '.fields.status.name')
echo "Current status: $CURRENT_STATUS"

# Check if current status is in the trigger list
SHOULD_MOVE=false
for status in "${TRIGGER_STATUSES[@]}"; do
    if [ "$CURRENT_STATUS" == "$status" ]; then
        SHOULD_MOVE=true
        break
    fi
done

if [ "$SHOULD_MOVE" != "true" ]; then
    echo "ℹ️  Status '$CURRENT_STATUS' is not beyond Self Review"
    echo "No action needed - ticket stays in current status"
    exit 0
fi

echo "⚠️  Pipeline failed while ticket is in '$CURRENT_STATUS'"
echo "Moving ticket to 'Changes Requested'..."

echo "Found 'Changes Requested' transition with ID: $TRANSITION_ID"

# Perform the transition
UPDATE_RESPONSE=$(curl -s -L -w "\nHTTP_CODE=%{http_code}" \
    -X POST \
    -u "${JIRA_EMAIL}:${JIRA_API_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{\"transition\": {\"id\": \"$TRANSITION_ID\"}}" \
    "${JIRA_BASE_URL}/rest/api/3/issue/${JIRA_TICKET}/transitions")

HTTP_CODE=$(echo "$UPDATE_RESPONSE" | grep "HTTP_CODE=" | cut -d'=' -f2)
UPDATE_BODY=$(echo "$UPDATE_RESPONSE" | sed '/HTTP_CODE=/d')

if [ "$HTTP_CODE" == "204" ] || [ "$HTTP_CODE" == "200" ]; then
    echo "✅ Successfully moved $JIRA_TICKET to 'Changes Requested'"
else
    echo "❌ Failed to update Jira status. HTTP Status: $HTTP_CODE"
    echo "Response: $UPDATE_BODY"
    exit 1
fi

# Add a comment to the ticket explaining why it was moved
if [ -n "$FAILED_RUN_URL" ]; then
    echo ""
    echo "Adding comment to ticket..."
    
    COMMENT_BODY="{\"body\": {\"type\": \"doc\", \"version\": 1, \"content\": [{\"type\": \"paragraph\", \"content\": [{\"type\": \"text\", \"text\": \"⚠️ Automatically moved to Changes Requested due to pipeline failure. \"}, {\"type\": \"text\", \"text\": \"View failed run\", \"marks\": [{\"type\": \"link\", \"attrs\": {\"href\": \"$FAILED_RUN_URL\"}}]}]}]}}"
    
    COMMENT_RESPONSE=$(curl -s -L -w "\nHTTP_CODE=%{http_code}" \
        -X POST \
        -u "${JIRA_EMAIL}:${JIRA_API_TOKEN}" \
        -H "Content-Type: application/json" \
        -d "$COMMENT_BODY" \
        "${JIRA_BASE_URL}/rest/api/3/issue/${JIRA_TICKET}/comment")
    
    COMMENT_HTTP_CODE=$(echo "$COMMENT_RESPONSE" | grep "HTTP_CODE=" | cut -d'=' -f2)
    
    if [ "$COMMENT_HTTP_CODE" == "201" ] || [ "$COMMENT_HTTP_CODE" == "200" ]; then
        echo "✅ Comment added to ticket"
    else
        echo "⚠️  Failed to add comment (non-critical)"
    fi
fi

echo ""
echo "🔗 Jira ticket: ${JIRA_BASE_URL}/browse/${JIRA_TICKET}"
exit 0

