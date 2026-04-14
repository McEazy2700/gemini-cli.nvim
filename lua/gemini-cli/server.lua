local M = {}

local uv = vim.uv or vim.loop
local config = require("gemini-cli.config")

M.port = nil
M.token = nil
M.server = nil
M.discovery_file = nil

function M.start()
  if M.server then return end

  M.port = config.options.server.port or M.get_random_port()
  M.token = M.generate_token()

  local server = uv.new_tcp()
  local ok, err = server:bind("127.0.0.1", M.port)
  if not ok then
    vim.notify("Gemini CLI: Failed to bind to port " .. M.port .. ": " .. err, vim.log.levels.ERROR)
    return
  end

  server:listen(128, function(err)
    if err then
      vim.notify("Gemini CLI: Server error: " .. err, vim.log.levels.ERROR)
      return
    end

    local client = uv.new_tcp()
    server:accept(client)
    M.handle_client(client)
  end)

  M.server = server
  M.create_discovery_file()

  return M.port
end

function M.stop()
  if M.server then
    M.server:close()
    M.server = nil
  end
  if M.discovery_file then
    os.remove(M.discovery_file)
    M.discovery_file = nil
  end
end

function M.get_random_port()
  -- Use a range common for ephemeral ports
  return math.random(49152, 65535)
end

function M.generate_token()
  local chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
  local token = ""
  for i = 1, 32 do
    local rand = math.random(1, #chars)
    token = token .. chars:sub(rand, rand)
  end
  return token
end

function M.create_discovery_file()
  local pid = vim.fn.getpid()
  local tmpdir = vim.fn.stdpath("cache") .. "/gemini/ide"
  vim.fn.mkdir(tmpdir, "p")
  
  local filename = string.format("%s/gemini-ide-server-%d-%d.json", tmpdir, pid, M.port)
  M.discovery_file = filename

  -- Gather all open workspace paths
  local paths = { vim.fn.getcwd() }
  -- In Neovim, we might have multiple tabs with different CWDs, or just open buffers
  -- For absolute robustness, we could list all unique directory names of open buffers
  -- but standard IDE behavior usually refers to "Project Roots".
  
  local data = {
    port = M.port,
    workspacePath = table.concat(paths, vim.loop.os_uname().sysname == "Windows" and ";" or ":"),
    authToken = M.token,
    ideInfo = {
      name = "neovim",
      displayName = "Neovim"
    }
  }

  local f = io.open(filename, "w")
  if f then
    f:write(vim.json.encode(data))
    f:close()
  end
end

M.clients = {}

function M.handle_client(client)
  client:read_start(function(err, data)
    if err or not data then
      M.remove_client(client)
      client:close()
      return
    end

    -- Basic HTTP Parser (simplified)
    local method, path, headers, body = M.parse_http(data)
    
    if path == "/mcp" then
      -- Check auth
      local auth = headers["Authorization"] or headers["authorization"]
      if auth ~= "Bearer " .. M.token then
        M.send_http_response(client, 401, "Unauthorized")
        return
      end

      if method == "POST" then
        -- Handle JSON-RPC request
        local ok, request = pcall(vim.json.decode, body)
        if ok then
          local response = require("gemini-cli.mcp").handle(request)
          M.send_http_response(client, 200, vim.json.encode(response), "application/json")
        else
          M.send_http_response(client, 400, "Bad Request")
        end
      elseif method == "GET" then
        -- Start SSE stream
        M.clients[client] = true
        local response = 
          "HTTP/1.1 200 OK\r\n" ..
          "Content-Type: text/event-stream\r\n" ..
          "Cache-Control: no-cache\r\n" ..
          "Connection: keep-alive\r\n" ..
          "\r\n"
        client:write(response)
        -- Do NOT close the client here
      else
        M.send_http_response(client, 405, "Method Not Allowed")
      end
    else
      M.send_http_response(client, 404, "Not Found")
    end
  end)
end

function M.remove_client(client)
  M.clients[client] = nil
end

function M.notify(notification)
  local data = string.format("data: %s\n\n", vim.json.encode(notification))
  for client, _ in pairs(M.clients) do
    client:write(data)
  end
end

function M.parse_http(data)
  local headers_end = data:find("\r\n\r\n")
  if not headers_end then return nil end

  local head = data:sub(1, headers_end - 1)
  local body = data:sub(headers_end + 4)

  local lines = {}
  for line in head:gmatch("([^\r\n]+)") do
    table.insert(lines, line)
  end

  local first_line = table.remove(lines, 1)
  local method, path = first_line:match("^(%A+)%s+(%S+)%s+HTTP/%d%.%d$")

  local headers = {}
  for _, line in ipairs(lines) do
    local k, v = line:match("^(%A+):%s*(.*)$")
    if k then
      headers[k] = v
    end
  end

  return method, path, headers, body
end

function M.send_http_response(client, status, body, content_type)
  content_type = content_type or "text/plain"
  local status_text = status == 200 and "OK" or (status == 401 and "Unauthorized" or (status == 404 and "Not Found" or "Error"))
  local response = string.format(
    "HTTP/1.1 %d %s\r\n" ..
    "Content-Type: %s\r\n" ..
    "Content-Length: %d\r\n" ..
    "Connection: close\r\n" ..
    "\r\n" ..
    "%s",
    status, status_text, content_type, #body, body
  )
  client:write(response, function()
    client:close()
  end)
end

return M
