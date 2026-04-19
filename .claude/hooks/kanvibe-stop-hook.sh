#!/bin/bash

# KanVibe Claude Code Hook: Stop
# AI 응답이 완료되면 현재 브랜치의 작업을 REVIEW로 변경한다.

KANVIBE_URL="http://localhost:4885"
PROJECT_NAME="auto_ktx"

BRANCH_NAME=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
if [ -z "$BRANCH_NAME" ] || [ "$BRANCH_NAME" = "HEAD" ]; then
  exit 0
fi

curl -s -X POST "${KANVIBE_URL}/api/hooks/status" \
  -H "Content-Type: application/json" \
  -d "{\"branchName\": \"${BRANCH_NAME}\", \"projectName\": \"${PROJECT_NAME}\", \"status\": \"review\"}" \
  > /dev/null 2>&1

exit 0
