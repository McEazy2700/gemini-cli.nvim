local M = {}

local config = require("gemini-cli.config")

M.buf = nil
M.win = nil

-- The generic open function that delegates to providers
function M.open(args)
  local opts = config.options.terminal
  args = args or {}
  
  -- If we already have a valid buffer, just toggle or reopen
  if M.buf and vim.api.nvim_buf_is_valid(M.buf) then
    if M.win and vim.api.nvim_win_is_valid(M.win) then
      vim.api.nvim_win_close(M.win, true)
      M.win = nil
    else
      M.win = M.providers[opts.provider].open(M.buf)
    end
    return
  end

  -- Create a new terminal buffer
  M.buf = vim.api.nvim_create_buf(false, true)
  M.win = M.providers[opts.provider].open(M.buf)

  local server = require("gemini-cli.server")
  local env = {
    GEMINI_CLI_IDE_SERVER_PORT = tostring(server.port),
    GEMINI_CLI_IDE_WORKSPACE_PATH = vim.fn.getcwd(),
    GEMINI_CLI_IDE_PID = tostring(vim.fn.getpid()),
  }

  local cmd_parts = { config.options.command }
  for _, arg in ipairs(args) do
    table.insert(cmd_parts, arg)
  end
  local full_cmd = table.concat(cmd_parts, " ")

  vim.fn.termopen(full_cmd, {
    env = env,
    on_exit = function()
      if M.win and vim.api.nvim_win_is_valid(M.win) then
        vim.api.nvim_win_close(M.win, true)
        M.win = nil
      end
      M.buf = nil
    end,
  })

  -- Set terminal buffer options
  vim.api.nvim_set_option_value("number", false, { scope = "local", win = M.win })
  vim.api.nvim_set_option_value("relativenumber", false, { scope = "local", win = M.win })
  vim.api.nvim_set_option_value("signcolumn", "no", { scope = "local", win = M.win })
  
  -- Enter insert mode
  vim.cmd("startinsert")
end

-- Send a raw string to the terminal process
function M.send(text)
  if M.buf and vim.api.nvim_buf_is_valid(M.buf) then
    local chan = vim.api.nvim_buf_get_var(M.buf, "terminal_job_id")
    if chan then
      -- Escape leading $ on any line to prevent gemini CLI from interpreting it as a shell command
      -- Using a space is more robust as it breaks the ^$ pattern without adding visible escape chars that the CLI might strip
      local escaped_text = text:gsub("\n%$", "\n $")
      if escaped_text:sub(1, 1) == "$" then
        escaped_text = " " .. escaped_text
      end
      
      vim.api.nvim_chan_send(chan, escaped_text .. "\n")
      -- Focus terminal if it's hidden or not active
      if not (M.win and vim.api.nvim_win_is_valid(M.win)) then
        M.open()
      else
        vim.api.nvim_set_current_win(M.win)
        vim.cmd("startinsert")
      end
    end
  end
end

M.providers = {
  native = {
    open = function(buf)
      local opts = config.options.terminal
      local pos = opts.position
      local size = opts.size
      local cmd = pos == "right" and "vsplit" or (pos == "left" and "leftabove vsplit" or (pos == "top" and "leftabove split" or "split"))
      
      vim.cmd(cmd)
      local win = vim.api.nvim_get_current_win()
      vim.api.nvim_win_set_buf(win, buf)
      
      if pos == "right" or pos == "left" then
        vim.api.nvim_win_set_width(win, size)
      else
        vim.api.nvim_win_set_height(win, size)
      end
      
      return win
    end,
  },
  float = {
    open = function(buf)
      local opts = config.options.terminal.float_opts
      local width = math.floor(vim.o.columns * (opts.width or 0.8))
      local height = math.floor(vim.o.lines * (opts.height or 0.8))
      local row = math.floor((vim.o.lines - height) / 2)
      local col = math.floor((vim.o.columns - width) / 2)

      local win = vim.api.nvim_open_win(buf, true, {
        relative = "editor",
        width = width,
        height = height,
        row = row,
        col = col,
        style = "minimal",
        border = opts.border or "rounded",
      })
      
      return win
    end,
  },
  snacks = {
    open = function(buf)
      -- Check if snacks is available
      local ok, snacks = pcall(require, "snacks")
      if not ok then
        vim.notify("Gemini CLI: snacks.nvim not found, falling back to float", vim.log.levels.WARN)
        return M.providers.float.open(buf)
      end

      local opts = config.options.terminal.float_opts
      local win_obj = snacks.win({
        buf = buf,
        position = "float",
        width = opts.width,
        height = opts.height,
        border = opts.border or "rounded",
        style = "terminal",
      })
      
      return win_obj.win
    end,
  },
}

return M
