#!/bin/bash
# relay-agent: Watch a relay room and trigger Claude Code on new messages.
#
# Usage:
#   ./tools/relay-agent.sh [owner/repo] [--interval SEC] [--filter TOPIC] [--dry-run]
#
# Examples:
#   ./tools/relay-agent.sh bit-vcs/bit
#   ./tools/relay-agent.sh bit-vcs/bit --filter ci.status
#   ./tools/relay-agent.sh --dry-run

set -euo pipefail

RELAY_BASE="${BIT_RELAY_URL:-https://bit-relay.mizchi.workers.dev}"
ROOM="${1:-}"
INTERVAL=30
FILTER_TOPIC=""
DRY_RUN=false
CLAUDE_CMD="${CLAUDE_CMD:-claude}"

# Parse args
shift || true
while [[ $# -gt 0 ]]; do
  case "$1" in
    --interval|-i) INTERVAL="$2"; shift 2 ;;
    --filter|-f) FILTER_TOPIC="$2"; shift 2 ;;
    --dry-run) DRY_RUN=true; shift ;;
    *) shift ;;
  esac
done

# Derive room from git remote if not specified
if [[ -z "$ROOM" ]]; then
  ORIGIN=$(git remote get-url origin 2>/dev/null || echo "")
  if [[ -n "$ORIGIN" ]]; then
    # Extract owner/repo from git URL
    ROOM=$(echo "$ORIGIN" | sed -E 's#.*[:/]([^/]+/[^/]+?)(\.git)?$#\1#')
  fi
fi

if [[ -z "$ROOM" ]]; then
  echo "Usage: relay-agent.sh <owner/repo> [--interval SEC] [--filter TOPIC]" >&2
  exit 1
fi

echo "🤖 relay-agent: watching room '$ROOM'"
echo "   relay: $RELAY_BASE"
echo "   interval: ${INTERVAL}s"
[[ -n "$FILTER_TOPIC" ]] && echo "   filter: $FILTER_TOPIC"
$DRY_RUN && echo "   mode: DRY RUN (no claude invocation)"
echo ""

CURSOR=0

# Initial fetch to get current cursor position (skip existing messages)
INIT=$(curl -sf "${RELAY_BASE}/api/v1/poll?room=${ROOM}&after=0&limit=1000" 2>/dev/null || echo '{}')
CURSOR=$(echo "$INIT" | jq -r '.next_cursor // 0')
echo "Starting from cursor: $CURSOR"
echo "---"

while true; do
  sleep "$INTERVAL"

  RESPONSE=$(curl -sf "${RELAY_BASE}/api/v1/poll?room=${ROOM}&after=${CURSOR}&limit=50" 2>/dev/null || echo '{}')
  NEW_CURSOR=$(echo "$RESPONSE" | jq -r '.next_cursor // 0')
  ENVELOPES=$(echo "$RESPONSE" | jq -c '.envelopes // []')
  COUNT=$(echo "$ENVELOPES" | jq 'length')

  if [[ "$COUNT" -eq 0 ]]; then
    continue
  fi

  CURSOR="$NEW_CURSOR"

  # Process each envelope
  echo "$ENVELOPES" | jq -c '.[]' | while read -r ENVELOPE; do
    TOPIC=$(echo "$ENVELOPE" | jq -r '.topic')
    SENDER=$(echo "$ENVELOPE" | jq -r '.sender')
    ID=$(echo "$ENVELOPE" | jq -r '.id')
    PAYLOAD=$(echo "$ENVELOPE" | jq -c '.payload')

    # Apply topic filter
    if [[ -n "$FILTER_TOPIC" && "$TOPIC" != "$FILTER_TOPIC" ]]; then
      continue
    fi

    echo "📨 [$SENDER] $TOPIC $ID"

    # Build prompt based on topic
    PROMPT=""
    case "$TOPIC" in
      ci.status)
        STATUS=$(echo "$PAYLOAD" | jq -r '.status // "unknown"')
        REF=$(echo "$PAYLOAD" | jq -r '.ref // "?"')
        URL=$(echo "$PAYLOAD" | jq -r '.url // ""')
        if [[ "$STATUS" == "fail" ]]; then
          PROMPT="CI failed on ref '$REF'. URL: $URL. Please investigate the failure and suggest a fix."
        fi
        ;;
      review.request)
        PR_ID=$(echo "$PAYLOAD" | jq -r '.pr_id // "?"')
        REQUESTER=$(echo "$PAYLOAD" | jq -r '.requester // "?"')
        PROMPT="Review requested by $REQUESTER for PR $PR_ID. Please review the changes and provide feedback."
        ;;
      hub.issue)
        KIND=$(echo "$PAYLOAD" | jq -r '.kind // ""')
        if [[ "$KIND" == "hub.record" ]]; then
          RECORD=$(echo "$PAYLOAD" | jq -r '.record // ""')
          TITLE=$(echo "$RECORD" | grep -o 'title: .*' | head -1 | sed 's/title: //')
          if [[ -n "$TITLE" ]]; then
            PROMPT="New issue: '$TITLE'. Please triage this issue and suggest an approach."
          fi
        fi
        ;;
      notify)
        MSG=$(echo "$PAYLOAD" | jq -r '.message // ""')
        if [[ -n "$MSG" ]]; then
          PROMPT="Notification: $MSG"
        fi
        ;;
    esac

    if [[ -z "$PROMPT" ]]; then
      echo "   (no action for this topic)"
      continue
    fi

    echo "   → $PROMPT"

    if $DRY_RUN; then
      echo "   [DRY RUN] would invoke: claude -p \"$PROMPT\""
    else
      echo "   Invoking Claude..."
      # Run claude in non-interactive mode with the prompt
      $CLAUDE_CMD -p "$PROMPT" 2>&1 | sed 's/^/   🤖 /' || true
    fi
    echo "---"
  done
done
