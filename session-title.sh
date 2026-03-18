#!/bin/bash
# Generate a short session title using Haiku and display it in iTerm tab
# Called as a Claude Code Stop hook — runs after each assistant turn

set -euo pipefail

# API key for Haiku title generation — use a separate env var to avoid
# conflicting with Claude Code's own ANTHROPIC_API_KEY auth.
# Set CLAUDE_TITLE_API_KEY in your shell profile (e.g. ~/.zshrc).
ANTHROPIC_API_KEY="${CLAUDE_TITLE_API_KEY:-}"

input=$(cat)

session_id=$(echo "$input" | jq -r '.session_id // ""')
transcript_path=$(echo "$input" | jq -r '.transcript_path // ""')

if [ -z "$session_id" ] || [ -z "$transcript_path" ]; then
  exit 0
fi

title_dir="$HOME/.claude/session-titles"
title_file="$title_dir/$session_id"

# If title already exists, just set iTerm tab title and exit
if [ -f "$title_file" ]; then
  title=$(cat "$title_file")
  printf '\033]1;%s\007' "$title" > /dev/tty 2>/dev/null || true
  exit 0
fi

# Need API key to generate title
if [ -z "${ANTHROPIC_API_KEY:-}" ]; then
  exit 0
fi

# Run title generation in background to avoid blocking Claude Code
(
  # Read first ~80 lines of transcript, extract only user and assistant text
  snippet=$(head -n 80 "$transcript_path" 2>/dev/null | jq -r '
    select(.type == "user" or .type == "assistant") |
    if .type == "user" then
      .message.content | if type == "string" then "User: " + .
      elif type == "array" then [.[] | select(.type == "text") | .text] | if length > 0 then "User: " + join(" ") else empty end
      else empty end
    else
      .message.content | if type == "array" then [.[] | select(.type == "text") | .text] | if length > 0 then "Assistant: " + join(" ") else empty end
      elif type == "string" then "Assistant: " + .
      else empty end
    end
  ' 2>/dev/null | head -c 2000)

  if [ -z "$snippet" ]; then
    exit 0
  fi

  # Call Haiku API to generate a short title
  response=$(curl -s --max-time 10 \
    -H "x-api-key: $ANTHROPIC_API_KEY" \
    -H "anthropic-version: 2023-06-01" \
    -H "content-type: application/json" \
    -d "$(jq -n --arg snippet "$snippet" '{
      model: "claude-haiku-4-5-20251001",
      max_tokens: 30,
      messages: [{
        role: "user",
        content: ("Generate a short title (max 5 words, no quotes) for this coding session:\n\n" + $snippet)
      }]
    }')" \
    https://api.anthropic.com/v1/messages 2>/dev/null)

  title=$(echo "$response" | jq -r '.content[0].text // ""' 2>/dev/null | head -1 | sed 's/^"//;s/"$//' | cut -c1-50)

  if [ -n "$title" ]; then
    mkdir -p "$title_dir"
    echo "$title" > "$title_file"
    printf '\033]1;%s\007' "$title" > /dev/tty 2>/dev/null || true
  fi
) &

exit 0
