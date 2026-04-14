local M = {}

function M.check()
  vim.health.start("gemini-cli.nvim")

  -- Check binary
  local config = require("gemini-cli.config")
  local cmd = config.options.command
  if vim.fn.executable(cmd) == 1 then
    vim.health.ok(string.format("Binary '%s' is executable", cmd))
  else
    vim.health.error(string.format("Binary '%s' not found or not executable", cmd))
  end

  -- Check server
  local server = require("gemini-cli.server")
  if server.server then
    vim.health.ok(string.format("MCP Server is running on port %d", server.port))
  else
    vim.health.warn("MCP Server is not running")
  end

  -- Check discovery file
  if server.discovery_file then
    if vim.fn.filereadable(server.discovery_file) == 1 then
      vim.health.ok(string.format("Discovery file exists: %s", server.discovery_file))
    else
      vim.health.error(string.format("Discovery file missing: %s", server.discovery_file))
    end
  end

  -- Check dependencies
  local has_plenary, _ = pcall(require, "plenary")
  if has_plenary then
    vim.health.ok("plenary.nvim is installed")
  else
    vim.health.warn("plenary.nvim is not installed (recommended for some utilities)")
  end
end

return M
