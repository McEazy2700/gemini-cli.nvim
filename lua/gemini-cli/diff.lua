local M = {}

local server = require("gemini-cli.server")

function M.open(filePath, content)
  local original_buf = vim.fn.bufnr(filePath, true)
  if not vim.api.nvim_buf_is_loaded(original_buf) then
    vim.fn.bufload(original_buf)
  end

  local proposed_buf = vim.api.nvim_create_buf(false, true)
  local lines = vim.split(content, "\n")
  vim.api.nvim_buf_set_lines(proposed_buf, 0, -1, false, lines)
  vim.api.nvim_set_option_value("buftype", "nofile", { buf = proposed_buf })
  vim.api.nvim_buf_set_name(proposed_buf, filePath .. " (proposed)")
  -- Conventional flag for many auto-save plugins
  vim.api.nvim_buf_set_var(proposed_buf, "auto_save_disabled", true)

  -- Open in a new tab for clarity
  vim.cmd("tabnew")
  local win1 = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(win1, original_buf)
  
  vim.cmd("vertical diffsplit")
  local win2 = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(win2, proposed_buf)

  local resolved = false

  local function cleanup()
    if not resolved then
      M.send_diff_response("ide/diffRejected", filePath)
      resolved = true
    end
    -- Close the tab
    vim.cmd("tabclose")
  end

  -- Autocmd for acceptance (saving the proposed buffer)
  vim.api.nvim_create_autocmd("BufWriteCmd", {
    buffer = proposed_buf,
    callback = function()
      if not resolved then
        -- Update the original buffer with the proposed content
        local new_lines = vim.api.nvim_buf_get_lines(proposed_buf, 0, -1, false)
        vim.api.nvim_buf_set_lines(original_buf, 0, -1, false, new_lines)
        vim.api.nvim_buf_call(original_buf, function()
          vim.cmd("w!")
        end)
        
        M.send_diff_response("ide/diffAccepted", filePath)
        resolved = true
      end
      cleanup()
    end,
  })

  -- Autocmd for rejection (closing the proposed buffer)
  vim.api.nvim_create_autocmd("BufWinLeave", {
    buffer = proposed_buf,
    callback = function()
      vim.schedule(function()
        if not resolved then
          M.send_diff_response("ide/diffRejected", filePath)
          resolved = true
        end
      end)
    end,
  })

  return { status = "opened" }
end

function M.send_diff_response(method, filePath)
  local notification = {
    method = method,
    params = {
      filePath = filePath,
    },
  }
  server.notify(notification)
end

return M
