local M = {}

M.defaults = {
  command = "gemini", -- The binary name or path
  terminal = {
    provider = "native", -- "native" (split), "float", or "snacks"
    position = "right", -- for "native" provider: "right", "left", "top", "bottom"
    size = 80,         -- for "native" provider: Width or height
    -- for "float" and "snacks" providers:
    float_opts = {
      width = 0.8,
      height = 0.8,
      border = "rounded",
    },
  },
  server = {
    port = nil, -- Random port if nil
  },
  models = {
    "gemini-3.0-flash", -- User specifically asked for 3.0
    "gemini-3.0-pro",
    "gemini-2.0-flash",
    "gemini-2.0-pro",
    "gemini-1.5-pro",
    "gemini-1.5-flash",
  },
}

function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", M.defaults, opts or {})
  return M.options
end

return M
