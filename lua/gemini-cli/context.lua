local M = {}

local server = require("gemini-cli.server")

M.recent_files = {} -- List of {path, timestamp}
M.max_recent_files = 10

function M.setup()
  local group = vim.api.nvim_create_augroup("GeminiCliContext", { clear = true })

  vim.api.nvim_create_autocmd({ "BufEnter", "WinEnter" }, {
    group = group,
    callback = function()
      M.update_recent_files(vim.api.nvim_buf_get_name(0))
      M.send_context_update()
    end,
  })

  vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
    group = group,
    callback = function()
      M.send_context_update_debounced()
    end,
  })
end

function M.update_recent_files(path)
  if path == "" or path:match("^term://") then return end
  
  -- Remove existing entry
  for i, file in ipairs(M.recent_files) do
    if file.path == path then
      table.remove(M.recent_files, i)
      break
    end
  end

  -- Insert at front
  table.insert(M.recent_files, 1, {
    path = path,
    timestamp = os.time(),
  })

  -- Trim
  if #M.recent_files > M.max_recent_files then
    table.remove(M.recent_files)
  end
end

M.timer = nil

function M.send_context_update_debounced()
  if M.timer then
    M.timer:stop()
  end
  M.timer = vim.defer_fn(function()
    M.send_context_update()
    M.timer = nil
  end, 50) -- 50ms debounce as recommended
end

function M.send_context_update()
  local bufnr = vim.api.nvim_get_current_buf()
  local path = vim.api.nvim_buf_get_name(bufnr)
  if path == "" or path:match("^term://") then return end

  local cursor = vim.api.nvim_win_get_cursor(0)
  local mode = vim.api.nvim_get_mode().mode
  local selected_text = nil
  local content = table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), "\n")

  if mode:match("^[vV\22]") then
    -- Get visual selection
    local start_pos = vim.fn.getpos("v")
    local end_pos = vim.fn.getpos(".")
    -- Simplification: just get the text between positions
    -- In a real plugin, we'd handle blockwise, etc.
    local lines = vim.api.nvim_buf_get_lines(bufnr, math.min(start_pos[2], end_pos[2]) - 1, math.max(start_pos[2], end_pos[2]), false)
    selected_text = table.concat(lines, "\n")
    if #selected_text > 16384 then
      selected_text = selected_text:sub(1, 16384)
    end
  end

  local open_files = {}
  for _, file in ipairs(M.recent_files) do
    table.insert(open_files, {
      path = file.path,
      timestamp = file.timestamp,
      isActive = file.path == path,
      content = file.path == path and content or nil,
      cursor = file.path == path and {
        line = cursor[1],
        character = cursor[2] + 1,
      } or nil,
      selectedText = file.path == path and selected_text or nil,
    })
  end

  local notification = {
    method = "ide/contextUpdate",
    params = {
      workspaceState = {
        openFiles = open_files,
        isTrusted = true,
      },
    },
  }

  server.notify(notification)
end

return M
