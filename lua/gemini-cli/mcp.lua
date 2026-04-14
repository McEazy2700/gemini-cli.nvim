local M = {}

function M.handle(request)
  local method = request.method
  local params = request.params
  local id = request.id

  local handler = M.handlers[method]
  if handler then
    local ok, result = pcall(handler, params)
    if ok then
      return { jsonrpc = "2.0", id = id, result = result }
    else
      return { jsonrpc = "2.0", id = id, error = { code = -32603, message = result } }
    end
  else
    return { jsonrpc = "2.0", id = id, error = { code = -32601, message = "Method not found" } }
  end
end

M.handlers = {
  ["initialize"] = function(params)
    return {
      protocolVersion = "2024-11-05",
      capabilities = {
        tools = {
          listChanged = false,
        },
      },
      serverInfo = {
        name = "gemini-cli-nvim",
        version = "0.1.0",
      },
    }
  end,

  ["notifications/initialized"] = function(params)
    return nil
  end,

  ["tools/list"] = function(params)
    return {
      tools = {
        {
          name = "openDiff",
          description = "Open a diff view to review changes",
          inputSchema = {
            type = "object",
            properties = {
              filePath = { type = "string" },
              content = { type = "string" },
            },
            required = { "filePath", "content" },
          },
        },
      },
    }
  end,

  ["tools/call"] = function(params)
    local name = params.name
    local tool_params = params.arguments
    
    if name == "openDiff" then
      return require("gemini-cli.diff").open(tool_params.filePath, tool_params.content)
    else
      error("Tool not found: " .. name)
    end
  end,
}

return M
