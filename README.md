# Claude Code Session Title

A [Claude Code](https://docs.anthropic.com/en/docs/claude-code) hook that automatically generates a short session title using Claude Haiku and displays it in your iTerm2 tab.

![iTerm2 tab title](https://img.shields.io/badge/iTerm2-tab_title-blue)

## How it works

1. After each assistant turn, the `Stop` hook fires
2. The script reads the conversation transcript and extracts user/assistant messages
3. It sends the conversation snippet to Claude Haiku to generate a concise title (max 5 words)
4. The title is cached in `~/.claude/session-titles/` and displayed in the iTerm2 tab

## Prerequisites

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI
- [jq](https://jqlang.github.io/jq/) — `brew install jq`
- [curl](https://curl.se/)
- An [Anthropic API key](https://console.anthropic.com/)
- iTerm2 (for tab title display)

## Installation

1. **Set your API key** in your shell profile (`~/.zshrc` or `~/.bashrc`):

   ```bash
   export CLAUDE_TITLE_API_KEY="sk-ant-..."
   ```

   > **Note:** We use `CLAUDE_TITLE_API_KEY` instead of `ANTHROPIC_API_KEY` to avoid conflicting with Claude Code's own authentication.

2. **Copy the script** to your Claude Code hooks directory:

   ```bash
   mkdir -p ~/.claude/hooks
   cp session-title.sh ~/.claude/hooks/session-title.sh
   chmod +x ~/.claude/hooks/session-title.sh
   ```

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

## How it looks

Each iTerm2 tab shows a short, AI-generated title based on your conversation:

```
┌─── Debug Auth Middleware ───┬─── Refactor User Schema ───┬─── Fix CI Pipeline ───┐
```

## License

MIT
