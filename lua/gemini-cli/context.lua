local M = {}

local server = require("gemini-cli.server")

M.recent_files = {} -- List of {path, timestamp}
M.max_recent_files = 10

function M.setup()
  local group = vim.api.nvim_create_augroup("GeminiCliContext", { clear = true })

  vim.api.nvim_create_autocmd({ "BufEnter", "WinEnter", "BufWritePost" }, {
    group = group,
    callback = function()
      M.update_recent_files(vim.api.nvim_buf_get_name(0))
      M.send_context_update(true)
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

M.last_content = {} -- cache for content per buffer

function M.send_context_update(force_content)
  local bufnr = vim.api.nvim_get_current_buf()
  local path = vim.api.nvim_buf_get_name(bufnr)
  if path == "" or path:match("^term://") then return end

  local cursor = vim.api.nvim_win_get_cursor(0)
  local mode = vim.api.nvim_get_mode().mode
  local selected_text = nil
  
  local content = nil
  local line_count = vim.api.nvim_buf_line_count(bufnr)
  
  -- Context Window Logic for large files
  -- If the file is small, send it all.
  -- If it's large (> 1000 lines), send a window around the cursor.
  if line_count <= 1000 then
    content = table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), "\n")
  else
    local window_size = 250 -- lines above and below
    local start_line = math.max(0, cursor[1] - window_size)
    local end_line = math.min(line_count, cursor[1] + window_size)
    
    local lines = vim.api.nvim_buf_get_lines(bufnr, start_line, end_line, false)
    content = string.format(
      "// [File: %s]\n// [Showing lines %d to %d of %d]\n%s",
      path,
      start_line + 1,
      end_line,
      line_count,
      table.concat(lines, "\n")
    )
  end

  -- Limit character count to prevent massive payloads
  if content and #content > 100000 then
    content = content:sub(1, 100000) .. "\n... [Content truncated]"
  end

  if mode:match("^[vV\22]") then
    -- Get visual selection (more robust version)
    local start_pos = vim.fn.getpos("v")
    local end_pos = vim.fn.getpos(".")
    
    local start_line = start_pos[2]
    local start_col = start_pos[3]
    local end_line = end_pos[2]
    local end_col = end_pos[3]
    
    if start_line > end_line or (start_line == end_line and start_col > end_col) then
      start_line, end_line = end_line, start_line
      start_col, end_col = end_col, start_col
    end

    local lines = vim.api.nvim_buf_get_lines(bufnr, start_line - 1, end_line, false)
    if #lines > 0 then
      if mode == "v" then
        if #lines == 1 then
          lines[1] = lines[1]:sub(start_col, end_col)
        else
          lines[1] = lines[1]:sub(start_col)
          lines[#lines] = lines[#lines]:sub(1, end_col)
        end
      elseif mode == "\22" then
        for i, line in ipairs(lines) do
          lines[i] = line:sub(start_col, end_col)
        end
      end
      selected_text = table.concat(lines, "\n")
      if #selected_text > 16384 then
        selected_text = selected_text:sub(1, 16384)
      end
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
