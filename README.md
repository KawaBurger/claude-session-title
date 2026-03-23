# Claude Code Session Title

A [Claude Code](https://docs.anthropic.com/en/docs/claude-code) hook that automatically generates a short session title and displays it in your iTerm2 tab.

Supports **Anthropic**, **OpenAI**, or **no API** (uses first message as title).

## How it works

1. After each assistant turn, the `Stop` hook fires
2. The script reads the conversation transcript and extracts user/assistant messages
3. It calls an LLM to generate a concise title (max 5 words), or uses the first user message directly
4. The title is cached in `~/.claude/session-titles/` and displayed in the iTerm2 tab

## Prerequisites

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI
- [jq](https://jqlang.github.io/jq/) — `brew install jq`
- [curl](https://curl.se/) (only needed for LLM providers)
- iTerm2 (for tab title display)

## Installation

1. **Copy the script** to your Claude Code hooks directory:

   ```bash
   mkdir -p ~/.claude/hooks
   cp session-title.sh ~/.claude/hooks/session-title.sh
   chmod +x ~/.claude/hooks/session-title.sh
   ```

2. **Create the config file** at `~/.claude/session-title.env`:

   ```bash
   # Provider: "anthropic", "openai", or "none"
   PROVIDER=none

   # Anthropic
   # ANTHROPIC_API_KEY=sk-ant-...
   # ANTHROPIC_MODEL=claude-haiku-4-5-20251001

   # OpenAI
   # OPENAI_API_KEY=sk-...
   # OPENAI_MODEL=gpt-4o-mini
   ```

   The config file is a plain bash-compatible `key=value` file — no need to export variables in your shell profile.

3. **Register the hook** in your Claude Code settings (`~/.claude/settings.json`):

   ```json
   {
     "hooks": {
       "Stop": [
         {
           "hooks": [
             {
               "type": "command",
               "command": "bash ~/.claude/hooks/session-title.sh",
               "async": true
             }
           ]
         }
       ]
     }
   }
   ```

## Configuration

All configuration lives in `~/.claude/session-title.env`:

| Variable | Default | Description |
|---|---|---|
| `PROVIDER` | `none` | `anthropic`, `openai`, or `none` |
| `ANTHROPIC_API_KEY` | — | Your Anthropic API key |
| `ANTHROPIC_MODEL` | `claude-haiku-4-5-20251001` | Anthropic model to use |
| `OPENAI_API_KEY` | — | Your OpenAI API key |
| `OPENAI_MODEL` | `gpt-4o-mini` | OpenAI model to use |

- `anthropic` / `openai` — calls the respective API to generate a short title
- `none` — no LLM call, uses the first user message (truncated to 40 chars) as the title

## How it looks

Each iTerm2 tab shows a short, AI-generated title based on your conversation:

```
┌─── Debug Auth Middleware ───┬─── Refactor User Schema ───┬─── Fix CI Pipeline ───┐
```

## License

MIT
