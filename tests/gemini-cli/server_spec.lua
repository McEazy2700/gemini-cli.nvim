local server = require("gemini-cli.server")
local config = require("gemini-cli.config")

describe("server", function()
  before_each(function()
    config.setup()
  end)

  after_each(function()
    server.stop()
  end)

  it("should start and create discovery file", function()
    local port = server.start()
    assert.is_number(port)
    assert.is_string(server.token)
    assert.is_string(server.discovery_file)
    
    local f = io.open(server.discovery_file, "r")
    assert.is_not_nil(f)
    local data = f:read("*a")
    f:close()
    
    local decoded = vim.json.decode(data)
    assert.are.equal(port, decoded.port)
    assert.are.equal(server.token, decoded.authToken)
    assert.are.equal("neovim", decoded.ideInfo.name)
  end)

  it("should stop and remove discovery file", function()
    server.start()
    local file = server.discovery_file
    assert.is_true(vim.fn.filereadable(file) == 1)
    
    server.stop()
    assert.is_false(vim.fn.filereadable(file) == 1)
    assert.is_nil(server.server)
  end)
end)
