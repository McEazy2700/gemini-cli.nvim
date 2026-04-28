local context = require("gemini-cli.context")
local server = require("gemini-cli.server")

describe("context", function()
  local notifications = {}

  before_each(function()
    notifications = {}
    -- Mock server.notify
    server.notify = function(notification)
      table.insert(notifications, notification)
    end
  end)

  it("should update recent files", function()
    context.update_recent_files("test_file.lua")
    assert.are.equal("test_file.lua", context.recent_files[1].path)
    
    context.update_recent_files("another_file.lua")
    assert.are.equal("another_file.lua", context.recent_files[1].path)
    assert.are.equal("test_file.lua", context.recent_files[2].path)
  end)

  it("should send context update", function()
    -- Create a dummy buffer
    local buf = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_buf_set_name(buf, "test_context.lua")
    local full_path = vim.api.nvim_buf_get_name(buf)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "local x = 1", "print(x)" })
    vim.api.nvim_set_current_buf(buf)
    
    context.update_recent_files(full_path)
    context.send_context_update()
    
    assert.are.equal(1, #notifications)
    local update = notifications[1]
    assert.are.equal("ide/contextUpdate", update.method)
    
    local file = update.params.workspaceState.openFiles[1]
    assert.are.equal(full_path, file.path)
    assert.are.equal("local x = 1\nprint(x)", file.content)
  end)
end)
