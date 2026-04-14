local M = {}

local context = require("gemini-cli.context")

-- Generic function to add a file to Gemini context
function M.add_to_context(path)
  if path and path ~= "" then
    context.update_recent_files(path)
    context.send_context_update()
    vim.notify("Gemini CLI: Added to context: " .. vim.fn.fnamemodify(path, ":t"), vim.log.levels.INFO)
  end
end

-- Oil.nvim integration
function M.oil_add()
  local ok, oil = pcall(require, "oil")
  if not ok then return end
  
  local entry = oil.get_cursor_entry()
  if entry and entry.type == "file" then
    local dir = oil.get_current_dir()
    M.add_to_context(dir .. entry.name)
  end
end

-- Nvim-tree integration
function M.nvim_tree_add()
  local ok, api = pcall(require, "nvim-tree.api")
  if not ok then return end
  
  local node = api.tree.get_node_under_cursor()
  if node and node.absolute_path then
    M.add_to_context(node.absolute_path)
  end
end

-- Neo-tree integration
function M.neo_tree_add(state)
  local node = state.tree:get_node()
  if node and node.path then
    M.add_to_context(node.path)
  end
end

function M.setup()
  -- This could automatically register keymaps or just provide the functions
  -- For now, let's just provide the functions and maybe a few autocmds if helpful
end

return M
