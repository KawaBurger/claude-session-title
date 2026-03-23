#!/bin/bash
# Generate a short session title and display it in iTerm2 tab
# Called as a Claude Code Stop hook — runs after each assistant turn
# Supports Anthropic, OpenAI, or plain text (first message) modes

set -euo pipefail

# Load config: env file provides defaults, environment variables take precedence
_SAVE_PROVIDER="${PROVIDER:-}"
_SAVE_ANTHROPIC_KEY="${ANTHROPIC_API_KEY:-}"
_SAVE_OPENAI_KEY="${OPENAI_API_KEY:-}"

CONFIG_FILE="${HOME}/.claude/session-title.env"
if [ -f "$CONFIG_FILE" ]; then
  # shellcheck source=/dev/null
  source "$CONFIG_FILE"
fi

[ -n "$_SAVE_PROVIDER" ] && PROVIDER="$_SAVE_PROVIDER"
[ -n "$_SAVE_ANTHROPIC_KEY" ] && ANTHROPIC_API_KEY="$_SAVE_ANTHROPIC_KEY"
[ -n "$_SAVE_OPENAI_KEY" ] && OPENAI_API_KEY="$_SAVE_OPENAI_KEY"
unset _SAVE_PROVIDER _SAVE_ANTHROPIC_KEY _SAVE_OPENAI_KEY

PROVIDER="${PROVIDER:-none}"

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

# Save title to file and set iTerm tab title
save_title() {
  local title="$1"
  if [ -n "$title" ]; then
    mkdir -p "$title_dir"
    echo "$title" > "$title_file"
    printf '\033]1;%s\007' "$title" > /dev/tty 2>/dev/null || true
  fi
}

# "none" mode: use first user message as title, no LLM call
if [ "$PROVIDER" = "none" ]; then
  # Extract first real user text: strip XML tags and system-injected lines
  title=$(head -n 80 "$transcript_path" 2>/dev/null | jq -r '
    select(.type == "user") |
    .message.content | if type == "string" then .
    elif type == "array" then [.[] | select(.type == "text") | .text] | join("\n")
    else empty end
  ' 2>/dev/null \
    | sed 's/<[^>]*>//g; s/^[[:space:]]*//' \
    | grep -v '^$' \
    | grep -iv -e '^caveat:' -e '^clear$' -e '^\[' -e '^/' \
    | head -1 | cut -c1-40 || true)
  save_title "$title"
  exit 0
fi

# Validate API key is set
if [ "$PROVIDER" = "anthropic" ] && [ -z "${ANTHROPIC_API_KEY:-}" ]; then
  exit 0
fi
if [ "$PROVIDER" = "openai" ] && [ -z "${OPENAI_API_KEY:-}" ]; then
  exit 0
fi

# Run LLM title generation in background to avoid blocking Claude Code
(
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

  if [ "$PROVIDER" = "anthropic" ]; then
    model="${ANTHROPIC_MODEL:-claude-haiku-4-5-20251001}"
    response=$(curl -s --max-time 10 \
      -H "x-api-key: $ANTHROPIC_API_KEY" \
      -H "anthropic-version: 2023-06-01" \
      -H "content-type: application/json" \
      -d "$(jq -n --arg snippet "$snippet" --arg model "$model" '{
        model: $model,
        max_tokens: 30,
        messages: [{
          role: "user",
          content: ("Generate a short title (max 5 words, no quotes) for this coding session:\n\n" + $snippet)
        }]
      }')" \
      https://api.anthropic.com/v1/messages 2>/dev/null)
    title=$(echo "$response" | jq -r '.content[0].text // ""' 2>/dev/null)
  else
    model="${OPENAI_MODEL:-gpt-4o-mini}"
    response=$(curl -s --max-time 10 \
      -H "Authorization: Bearer $OPENAI_API_KEY" \
      -H "content-type: application/json" \
      -d "$(jq -n --arg snippet "$snippet" --arg model "$model" '{
        model: $model,
        max_tokens: 30,
        messages: [{
          role: "user",
          content: ("Generate a short title (max 5 words, no quotes) for this coding session:\n\n" + $snippet)
        }]
      }')" \
      https://api.openai.com/v1/chat/completions 2>/dev/null)
    title=$(echo "$response" | jq -r '.choices[0].message.content // ""' 2>/dev/null)
  fi

  title=$(echo "$title" | head -1 | sed 's/^"//;s/"$//' | cut -c1-50)
  save_title "$title"
) &

exit 0
