local M = {}

local config = require("gemini-cli.config")

function M.setup(opts)
  M.config = config.setup(opts)
  
  -- Start MCP server
  require("gemini-cli.server").start()
  -- Setup context tracker
  require("gemini-cli.context").setup()
  
  local commands = require("gemini-cli.commands")
  
  vim.api.nvim_create_user_command("Gemini", function()
    M.open()
  end, {})
  
  vim.api.nvim_create_user_command("GeminiAsk", function()
    commands.ask()
  end, { range = true })
  
  vim.api.nvim_create_user_command("GeminiSelectModel", function()
    commands.select_model()
  end, {})
  
  vim.api.nvim_create_user_command("GeminiResume", function()
    commands.resume()
  end, {})

  vim.api.nvim_create_autocmd("VimLeave", {
    callback = function()
      require("gemini-cli.server").stop()
    end,
  })
end

function M.open()
  require("gemini-cli.terminal").open()
end

return M
