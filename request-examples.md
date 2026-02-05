
TO get transition id
```sh
curl -u your_email:JIRA_TOKEN\
  -X GET \
  -H "Accept: application/json" \
  https://nucleussec.atlassian.net/rest/api/3/issue/AUTO-25/transitions

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
```