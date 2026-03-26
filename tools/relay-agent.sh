#!/bin/bash
# relay-agent: Event-driven Claude Code agent triggered by relay messages.
#
# Watches a relay room, dispatches events to Claude Code skills,
# and publishes results back to relay.
#
# Usage:
#   ./tools/relay-agent.sh [owner/repo] [options]
#
# Options:
#   --interval SEC    Poll interval (default: 5)
#   --filter TOPIC    Only react to specific topic
#   --respond         Push Claude's output back to relay
#   --dry-run         Preview without invoking Claude
#   --skill NAME      Use specific skill for all events
#
# Examples:
#   ./tools/relay-agent.sh bit-vcs/bit --respond
#   ./tools/relay-agent.sh bit-vcs/bit --filter ci.status --respond
#   ./tools/relay-agent.sh --dry-run

set -euo pipefail

RELAY_BASE="${BIT_RELAY_URL:-https://bit-relay.mizchi.workers.dev}"
ROOM="${1:-}"
INTERVAL=5
FILTER_TOPIC=""
DRY_RUN=false
RESPOND=false
SKILL=""
CLAUDE_CMD="${CLAUDE_CMD:-claude}"
AGENT_SENDER="${BIT_RELAY_SENDER:-claude-agent}"

shift || true
while [[ $# -gt 0 ]]; do
  case "$1" in
    --interval|-i) INTERVAL="$2"; shift 2 ;;
    --filter|-f) FILTER_TOPIC="$2"; shift 2 ;;
    --respond|-r) RESPOND=true; shift ;;
    --dry-run) DRY_RUN=true; shift ;;
    --skill|-s) SKILL="$2"; shift 2 ;;
    *) shift ;;
  esac
done

# Derive room from git remote if not specified
if [[ -z "$ROOM" ]]; then
  ORIGIN=$(git remote get-url origin 2>/dev/null || echo "")
  if [[ -n "$ORIGIN" ]]; then
    ROOM=$(echo "$ORIGIN" | sed -E 's#.*[:/]([^/]+/[^/]+?)(\.git)?$#\1#')
  fi
fi

if [[ -z "$ROOM" ]]; then
  echo "Usage: relay-agent.sh <owner/repo> [options]" >&2
  exit 1
fi

echo "🤖 relay-agent v0.36.0"
echo "   room: $ROOM"
echo "   relay: $RELAY_BASE"
echo "   interval: ${INTERVAL}s"
echo "   respond: $RESPOND"
[[ -n "$FILTER_TOPIC" ]] && echo "   filter: $FILTER_TOPIC"
[[ -n "$SKILL" ]] && echo "   skill: $SKILL"
$DRY_RUN && echo "   mode: DRY RUN"
echo ""

# --- Helper: publish response back to relay ---
relay_respond() {
  local response_topic="$1"
  local response_id="$2"
  local response_body="$3"

  if ! $RESPOND; then return 0; fi

  local payload
  payload=$(jq -n \
    --arg kind "agent.response" \
    --arg topic "$response_topic" \
    --arg ref_id "$response_id" \
    --arg body "$response_body" \
    '{kind: $kind, original_topic: $topic, ref_id: $ref_id, body: $body}')

  curl -sf -X POST \
    "${RELAY_BASE}/api/v1/publish?room=${ROOM}&sender=${AGENT_SENDER}&topic=agent.response&id=resp-${response_id}" \
    -H "Content-Type: application/json" \
    -d "$payload" > /dev/null 2>&1 || true
}

# --- Helper: build prompt from event ---
build_prompt() {
  local topic="$1"
  local payload="$2"
  local id="$3"

  # If a specific skill is set, use it for all events
  if [[ -n "$SKILL" ]]; then
    echo "/$SKILL $(echo "$payload" | jq -c '.')"
    return
  fi

  case "$topic" in
    ci.status)
      local status ref url
      status=$(echo "$payload" | jq -r '.status // "unknown"')
      ref=$(echo "$payload" | jq -r '.ref // "?"')
      url=$(echo "$payload" | jq -r '.url // ""')
      if [[ "$status" == "fail" ]]; then
        cat <<PROMPT
CI failed on ref '$ref'.${url:+ URL: $url}

1. Check the CI logs and identify the root cause
2. If it's a test failure, look at the failing test and the relevant code
3. Suggest a fix or create a patch
4. Summarize what went wrong and how to fix it
PROMPT
      fi
      ;;

    review.request)
      local pr_id requester reviewer
      pr_id=$(echo "$payload" | jq -r '.pr_id // "?"')
      requester=$(echo "$payload" | jq -r '.requester // "?"')
      reviewer=$(echo "$payload" | jq -r '.reviewer // ""')
      cat <<PROMPT
Review requested by $requester for PR $pr_id.${reviewer:+ Assigned to: $reviewer}

1. Read the changes in the PR
2. Check for bugs, security issues, and code quality
3. Provide constructive feedback
4. Give a verdict: approve or request changes
PROMPT
      ;;

    hub.issue|notify)
      local kind title msg
      kind=$(echo "$payload" | jq -r '.kind // ""')
      if [[ "$kind" == "hub.record" ]]; then
        local record
        record=$(echo "$payload" | jq -r '.record // ""')
        title=$(echo "$record" | grep -o 'title: .*' | head -1 | sed 's/title: //')
        local body
        body=$(echo "$record" | sed -n '/^$/,$ p' | head -5)
        if [[ -n "$title" ]]; then
          cat <<PROMPT
New issue: "$title"
${body:+Content: $body}

1. Analyze the issue and categorize it (bug, feature, question, etc.)
2. Suggest appropriate labels
3. Estimate complexity (small/medium/large)
4. Propose an implementation approach if applicable
PROMPT
        fi
      else
        msg=$(echo "$payload" | jq -r '.message // ""')
        if [[ -n "$msg" ]]; then
          echo "$msg"
        fi
      fi
      ;;

    agent.*)
      # Don't react to our own responses
      ;;

    *)
      echo "Relay event [$topic]: $(echo "$payload" | jq -c '.')"
      ;;
  esac
}

# --- Main loop ---
CURSOR=0

# Skip existing messages
INIT=$(curl -sf "${RELAY_BASE}/api/v1/poll?room=${ROOM}&after=0&limit=1000" 2>/dev/null || echo '{}')
CURSOR=$(echo "$INIT" | jq -r '.next_cursor // 0')
echo "Starting from cursor: $CURSOR"
echo "Listening for events..."
echo "---"

while true; do
  sleep "$INTERVAL"

  RESPONSE=$(curl -sf "${RELAY_BASE}/api/v1/poll?room=${ROOM}&after=${CURSOR}&limit=50" 2>/dev/null || echo '{}')
  NEW_CURSOR=$(echo "$RESPONSE" | jq -r '.next_cursor // 0')
  ENVELOPES=$(echo "$RESPONSE" | jq -c '.envelopes // []')
  COUNT=$(echo "$ENVELOPES" | jq 'length')

  [[ "$COUNT" -eq 0 ]] && continue
  CURSOR="$NEW_CURSOR"

  echo "$ENVELOPES" | jq -c '.[]' | while read -r ENVELOPE; do
    TOPIC=$(echo "$ENVELOPE" | jq -r '.topic')
    SENDER=$(echo "$ENVELOPE" | jq -r '.sender')
    ID=$(echo "$ENVELOPE" | jq -r '.id')
    PAYLOAD=$(echo "$ENVELOPE" | jq -c '.payload')

    # Skip our own messages
    [[ "$SENDER" == "$AGENT_SENDER" ]] && continue

    # Apply topic filter
    [[ -n "$FILTER_TOPIC" && "$TOPIC" != "$FILTER_TOPIC" ]] && continue

    echo "📨 [$SENDER] $TOPIC $ID"

    PROMPT=$(build_prompt "$TOPIC" "$PAYLOAD" "$ID")
    if [[ -z "$PROMPT" ]]; then
      echo "   (skipped)"
      continue
    fi

    echo "   ⚡ dispatching..."

    if $DRY_RUN; then
      echo "   [DRY RUN] prompt:"
      echo "$PROMPT" | sed 's/^/   > /'
    else
      # Invoke Claude and capture output
      OUTPUT=$($CLAUDE_CMD -p "$PROMPT" 2>&1 || true)
      echo "$OUTPUT" | sed 's/^/   🤖 /'

      # Push response back to relay
      if $RESPOND && [[ -n "$OUTPUT" ]]; then
        relay_respond "$TOPIC" "$ID" "$OUTPUT"
        echo "   📤 response published to relay"
      fi
    fi
    echo "---"
  done
done
