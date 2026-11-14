# mizchi/llm - Pure MoonBit LLM Client Library

npm 依存なしの pure MoonBit LLM クライアントライブラリ。
6 プロバイダー (OpenAI, Anthropic, OpenRouter, Ollama, Cloudflare AI, Claude Code CLI) + OpenAI Compat を統一的に抽象化。

## Quick Commands

```bash
just           # check + test
just fmt       # format code
just check     # type check
just test      # run tests
just test-update  # update snapshot tests
just run       # run main (demo)
just info      # generate type definition files
```

## Project Structure

```
src/
  types.mbt          # Role, ContentBlock, Message, ToolCall, Usage, FinishReason, StreamEvent
  json_utils.mbt     # JSON serialization (Anthropic/OpenAI format)
  tool.mbt           # ToolDef, ToolChoice, SchemaBuilder, ToolRegistry
  client.mbt         # Provider trait, BoxedProvider, ProviderConfig, collect_text, collect, truncate_messages
  agent.mbt          # run_agent, StopCondition, agent loop (pure MoonBit)
  config.mbt         # Default model constants
  ffi/               # Minimal JS FFI (4 functions: get_env, js_fetch_sse, js_exec_sync, js_exec_stream)
  anthropic/         # AnthropicProvider (SSE parse in pure MoonBit)
  openai/            # OpenAIProvider (OpenAI/OpenRouter/Ollama/Cloudflare AI/Custom), OpenAIProvider::new_compat
  claude_code/       # ClaudeCodeProvider (CLI subprocess)
  main/              # Demo / debug harness
```

## Architecture

- **Provider trait**: `stream(messages, tools, handler)` - 1回のリクエスト
- **Agent loop**: ツール実行 → メッセージ追加 → 再リクエストを pure MoonBit で管理
- **ContentBlock enum**: `Text | ToolUse | ToolResult` でツール呼び出し履歴を型付き表現
- **FFI は最小限**: fetch + subprocess の 4 関数のみ。SSE/JSON パースは MoonBit 側
- **collect_text / collect**: ストリームを簡単に文字列/構造体に変換するヘルパー
- **SchemaBuilder**: ツール input_schema を型安全に構築
- **truncate_messages**: トークン予算に基づくメッセージ切り詰め
- **タイムアウト / リトライ**: ProviderConfig で設定可能

## Coding Convention

- Each block is separated by `///|`
- Use `moon ide` commands for code navigation (prefer over grep)
- Use `moon doc <Type>` to explore APIs
- MoonBit code uses snake_case for variables/functions (lowercase only)

## Before Commit

```bash
just release-check  # fmt + info + check + test
```
