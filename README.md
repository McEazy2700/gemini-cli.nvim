# gemini-cli.nvim

A Neovim plugin for the **Gemini CLI**, providing a seamless IDE experience with real-time context and native diffing. Inspired by `claudecode.nvim`.

## Features
- **Flexible UI Providers:** Support for Native Split, Native Float, and `snacks.nvim`.
- **Real-time Context:** Automatically shares active buffer, cursor, and visual selection with Gemini.
- **Visual Prompting:** `:GeminiAsk` command to prompt about specific code blocks.
- **Native Diffing:** Review and accept (`:w`) or reject (`:q`) AI changes using `vimdiff`.
- **File Explorer Integrations:** Hooks for `oil.nvim`, `nvim-tree`, `neo-tree`, and `mini.files`.
- **Model & Session Management:** Quickly swap models or resume sessions.
- **Zero Configuration Discovery:** Automated MCP over HTTP server setup.

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "mceazy2700/gemini-cli.nvim",
  dependencies = { 
    "nvim-lua/plenary.nvim",
    "folke/snacks.nvim", -- Optional: for the "snacks" terminal provider
  },
  opts = {
    -- See Configuration section for options
  },
  keys = {
    { "<leader>a", nil, desc = "AI/Gemini" },
    { "<leader>ac", "<cmd>Gemini<cr>", desc = "Toggle Gemini" },
    { "<leader>ar", "<cmd>GeminiResume<cr>", desc = "Resume Gemini" },
    { "<leader>am", "<cmd>GeminiSelectModel<cr>", desc = "Select Gemini model" },
    { "<leader>aa", "<cmd>GeminiAsk<cr>", desc = "Ask Gemini", mode = { "n", "v" } },
    {
      "<leader>ab",
      function()
        require("gemini-cli.integrations").add_to_context(vim.api.nvim_buf_get_name(0))
      end,
      desc = "Add current buffer to Gemini context",
    },
    -- Diff management (when in a (proposed) buffer)
    { "<leader>ay", "<cmd>GeminiDiffAccept<cr>", desc = "Accept diff" },
    { "<leader>an", "<cmd>GeminiDiffDeny<cr>", desc = "Deny diff" },
  },
}
```

## Usage

### Commands
- `:Gemini` - Toggle the Gemini terminal.
- `:GeminiAsk` (or `v:GeminiAsk`) - Prompt about a visual selection or just start a prompt with context.
- `:GeminiSelectModel` - Select the Gemini model to use (customizable in config).
- `:GeminiResume` - Resume the last session.
- `:GeminiDiffAccept` - Accept the current proposed diff.
- `:GeminiDiffDeny` - Reject the current proposed diff.
- `:checkhealth gemini-cli` - Troubleshooting.

### Diff Workflow
When Gemini proposes a change:
1. A new tab opens with `vimdiff`.
2. Review the `(proposed)` buffer.
3. **Accept:** Run `:GeminiDiffAccept` (or `<leader>ay`) or just `:w` in the proposed buffer.
4. **Reject:** Run `:GeminiDiffDeny` (or `<leader>an`) or just `:q` in the proposed buffer.

### Explorer Integrations
Add to your explorer configuration:

**Oil.nvim**
```lua
require("oil").setup({
  keymaps = {
    ["<leader>aa"] = "require('gemini-cli.integrations').oil_add()",
  }
})
```

**Nvim-tree**
```lua
-- Add a custom action
local function on_attach(bufnr)
  local api = require("nvim-tree.api")
  api.config.mappings.default_on_attach(bufnr)
  vim.keymap.set("n", "<leader>aa", require("gemini-cli.integrations").nvim_tree_add, { buffer = bufnr })
end
```

## Configuration

Detailed options and their defaults:

```lua
require("gemini-cli").setup({
  -- Path to the gemini CLI binary
  command = "gemini", 

  terminal = {
    -- "native" (standard split), "float" (Neovim floating window), or "snacks" (snacks.nvim terminal)
    provider = "native", 

    -- Only for "native" provider
    position = "right", -- "right", "left", "top", "bottom"
    size = 80,         -- width (for right/left) or height (for top/bottom)

    -- Options for "float" and "snacks" providers
    float_opts = {
      width = 0.8,     -- Percentage of screen width (0.0 to 1.0)
      height = 0.8,    -- Percentage of screen height (0.0 to 1.0)
      border = "rounded", -- "none", "single", "double", "rounded", "solid", "shadow"
    },
  },

  server = {
    -- Port for the MCP over HTTP server. If nil, a random port is selected.
    port = nil, 
  },

  -- List of models available in :GeminiSelectModel
  models = {
    "gemini-3.0-flash",
    "gemini-3.0-pro",
    "gemini-2.0-flash",
    "gemini-2.0-pro",
    "gemini-1.5-pro",
    "gemini-1.5-flash",
  },
})
```
