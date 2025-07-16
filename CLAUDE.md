# Claude Code Configuration

## GitHub Repository Settings

### IMPORTANT: Repository Target
**Always create issues in the correct repository:**
- ✅ **Correct**: https://github.com/eightman999/AINanikaAIChan
- ❌ **Wrong**: https://github.com/manju-summoner/AISisterAIChan (fork source)

When using `gh issue create` commands, ensure you are working in the correct repository directory and targeting the right repository.

## Gemini MCP Usage Guidelines

### Model Selection Strategy

When using Gemini CLI MCP tools, follow this priority order:

1. **Default**: Use `gemini-2.5-pro` for best quality results
2. **Quota Exceeded**: Switch to `gemini-2.5-flash` when receiving 429 errors or quota limits
3. **Fast Operations**: Use `gemini-2.5-flash` for simple queries that don't require maximum reasoning

### Error Handling

When encountering quota exceeded errors (HTTP 429):
- Automatically retry with `gemini-2.5-flash` model
- Wait briefly before retry to respect rate limits
- Document the model fallback in responses

### Usage Examples

```bash
# Primary attempt (preferred)
mcp__gemini-cli__geminiChat --model "gemini-2.5-pro" --prompt "..."

# Fallback when quota exceeded
mcp__gemini-cli__geminiChat --model "gemini-2.5-flash" --prompt "..."
```

### Tool Configuration

Current MCP server setup in `.mcp.json`:
- Package: `@choplin/mcp-gemini-cli`
- Available tools: `googleSearch`, `geminiChat`
- Execution: stdio mode via npx

### Best Practices

1. **Monitor quota usage** - Be aware of daily limits
2. **Optimize prompts** - Use concise, specific prompts to reduce token usage
3. **Batch operations** - Combine related queries when possible
4. **Fallback gracefully** - Always have Flash model as backup