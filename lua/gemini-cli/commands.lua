local M = {}

local terminal = require("gemini-cli.terminal")

-- Helper to get visual selection
function M.get_visual_selection()
  local mode = vim.api.nvim_get_mode().mode
  local bufnr = vim.api.nvim_get_current_buf()
  
  -- Get positions
  local start_pos = vim.fn.getpos("v")
  local end_pos = vim.fn.getpos(".")
  
  local start_line = start_pos[2]
  local start_col = start_pos[3]
  local end_line = end_pos[2]
  local end_col = end_pos[3]
  
  -- Normalize (start before end)
  if start_line > end_line or (start_line == end_line and start_col > end_col) then
    start_line, end_line = end_line, start_line
    start_col, end_col = end_col, start_col
  end
  
  local lines = vim.api.nvim_buf_get_lines(bufnr, start_line - 1, end_line, false)
  if #lines == 0 then return "", 0 end
  
  if mode == "v" then
    -- Character-wise visual mode
    if #lines == 1 then
      lines[1] = lines[1]:sub(start_col, end_col)
    else
      lines[1] = lines[1]:sub(start_col)
      lines[#lines] = lines[#lines]:sub(1, end_col)
    end
  elseif mode == "\22" then
    -- Block-wise visual mode
    for i, line in ipairs(lines) do
      lines[i] = line:sub(start_col, end_col)
    end
  end
  -- mode == "V" (Line-wise) uses full lines already
  
  return table.concat(lines, "\n"), start_line
end

function M.ask()
  local mode = vim.api.nvim_get_mode().mode
  local selection = ""
  local start_line = 0
  local bufnr = vim.api.nvim_get_current_buf()
  local path = vim.api.nvim_buf_get_name(bufnr)

  if mode:match("^[vV\22]") then
    selection, start_line = M.get_visual_selection()
    -- Exit visual mode
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", true)
  end

  vim.ui.input({ prompt = "Gemini Ask: " }, function(input)
    if not input or input == "" then return end

    local prompt = input
    if selection ~= "" then
      -- Indent each line of the selection by 2 spaces to avoid triggering shell commands (leading $)
      -- and to provide a cleaner look for the LLM.
      local indented_selection = "  " .. selection:gsub("\n", "\n  ")
      prompt = string.format(
        "File Path: %s (Starting at line %d)\n\nHighlighted Code:\n```\n%s\n```\n\n%s",
        path,
        start_line,
        indented_selection,
        input
      )
    end

    terminal.send(prompt)
  end)
end

function M.select_model()
  local config = require("gemini-cli.config")
  local models = config.options.models
  
  vim.ui.select(models, { prompt = "Select Gemini Model: " }, function(choice)
    if choice then
      if terminal.buf and vim.api.nvim_buf_is_valid(terminal.buf) then
        -- Terminal is already running, try to send a command
        terminal.send("/model " .. choice)
      else
        -- Terminal not open, start it with the -m flag
        terminal.open({ "-m", choice })
      end
    end
  end)
end

function M.resume()
  if terminal.buf and vim.api.nvim_buf_is_valid(terminal.buf) then
    terminal.send("/resume")
  else
    terminal.open({ "--resume", "latest" })
  end
end

return M
