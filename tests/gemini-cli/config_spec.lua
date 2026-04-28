local config = require("gemini-cli.config")

describe("config", function()
  it("should load default options", function()
    local opts = config.setup()
    assert.are.equal("gemini", opts.command)
    assert.are.equal("native", opts.terminal.provider)
    assert.are.equal("right", opts.terminal.position)
    assert.is_table(opts.models)
  end)

  it("should override options", function()
    local opts = config.setup({
      command = "my-gemini",
      terminal = {
        provider = "float",
        size = 50,
      },
    })
    assert.are.equal("my-gemini", opts.command)
    assert.are.equal("float", opts.terminal.provider)
    assert.are.equal(50, opts.terminal.size)
    -- Ensure other defaults are still there
    assert.are.equal("right", opts.terminal.position)
  end)
end)
