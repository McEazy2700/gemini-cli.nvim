# GEMINI.md - gemini-cli.nvim

## Project Overview
**gemini-cli.nvim** is a Neovim plugin designed to provide a deep, interactive integration with the **Gemini CLI**. It emulates a "Native IDE" experience by implementing the official **Gemini CLI IDE Companion Specification** using the **Model Context Protocol (MCP)** over HTTP.

The plugin enables:
- **Real-time Context Sharing:** Automatically pushes the current buffer state, cursor position, and visual selection to the Gemini CLI.
- **Native Diffing:** Allows users to review, edit, and accept (`:w`) or reject (`:q`) AI-proposed changes using Neovim's built-in `vimdiff` functionality.
- **Embedded Terminal:** Runs the Gemini CLI directly within a Neovim buffer (split or window) with automatic discovery of the local MCP server.

## Architecture & Key Components
The project is a pure Lua Neovim plugin following standard layout conventions (`lua/gemini-cli/`).

- **`init.lua`**: The entry point. Handles `setup()`, command registration (`:Gemini`), and lifecycle management (starting/stopping the server).
- **`server.lua`**: Implements a lightweight HTTP/MCP server using Neovim's internal `vim.uv` (libuv) event loop.
    - Handles **SSE (Server-Sent Events)** for pushing notifications to the CLI.
    - Manages a dynamic port and a secure authentication token.
- **`mcp.lua`**: Implements the JSON-RPC 2.0 handlers for the Model Context Protocol.
- **`context.lua`**: Manages context tracking using `autocmd` events (`BufEnter`, `CursorMoved`, visual selection) and debounces updates to the CLI.
- **`diff.lua`**: Orchestrates the native `vimdiff` view, handling buffer creation and the mapping of save/close actions to MCP success/failure responses.
- **`terminal.lua`**: Manages the terminal buffer and window where the `gemini` process is spawned, injecting the necessary `GEMINI_CLI_IDE_*` environment variables.

## Building and Running
Since this is a Neovim Lua plugin, no traditional build step is required.

### Running
1.  Add the plugin to your Neovim configuration (e.g., using `lazy.nvim`).
2.  Ensure the `gemini` CLI binary is in your `PATH`.
3.  Run `:Gemini` to start the terminal and connect the IDE context.

### Testing
- **TODO:** Implement automated tests using a framework like `plenary.test`.
- Manual verification: Check that the discovery file is created in the system cache directory and that the CLI reports "Connected to Neovim" upon startup.

## Development Conventions
- **Pure Lua:** Avoid external binary dependencies; rely on Neovim's built-in APIs and `vim.uv`.
- **Surgical Changes:** When modifying the MCP server or context tracker, ensure that performance is prioritized to avoid editor lag.
- **Protocol Adherence:** All networking must strictly follow the [Gemini CLI IDE Companion Specification](https://github.com/google/gemini-cli).
- **Style:** Follow standard Neovim Lua style: use 2-space indentation and descriptive local variable names.

## Key Files for Investigation
- `lua/gemini-cli/server.lua`: Start here for networking and HTTP/SSE logic.
- `lua/gemini-cli/context.lua`: Check here for how Neovim state is mapped to Gemini context.
- `lua/gemini-cli/diff.lua`: Review for the `vimdiff` workflow implementation.
