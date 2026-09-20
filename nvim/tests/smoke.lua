-- Used only by tests/nvim.sh inside a disposable HOME.
local ok, err = xpcall(function()
  for _, server in ipairs(require("tooling").servers) do
    assert(vim.lsp.is_enabled(server), server .. " is not enabled")
    assert(vim.fn.executable(vim.lsp.config[server].cmd[1]) == 1, server .. " executable missing")
  end
  for _, sample in ipairs({ { "lua_ls", "lua" }, { "ts_ls", "ts" }, { "pyright", "py" }, { "clangd", "cpp" } }) do
    local project = vim.fn.tempname()
    vim.fn.mkdir(project .. "/.git", "p")
    vim.fn.writefile({ "{}" }, project .. "/package.json")
    vim.fn.writefile({ "" }, project .. "/sample." .. sample[2])
    vim.cmd.edit(project .. "/sample." .. sample[2])
    assert(vim.wait(30000, function()
      local clients = vim.lsp.get_clients({ bufnr = 0, name = sample[1] })
      return clients[1] and clients[1].initialized
    end, 100), sample[1] .. " failed to attach")
    for _, client in ipairs(vim.lsp.get_clients()) do
      client:stop()
    end
    assert(vim.wait(10000, function() return #vim.lsp.get_clients() == 0 end, 100), "LSP shutdown timed out")
  end
  local dap = require("dap")
  local python = vim.system({ dap.adapters.python.command, "-c", "import debugpy; print(debugpy.__version__)" }):wait(10000)
  assert(python.code == 0, "debugpy import failed: " .. (python.stderr or ""))
  -- Validate the bundled LLDB shared libraries, not only the executable bit.
  local root = require("mason.settings").current.install_root_dir
  local lldb = vim.system({ root .. "/packages/codelldb/extension/lldb/bin/lldb", "--version" }):wait(10000)
  assert(lldb.code == 0, "LLDB runtime failed: " .. (lldb.stderr or ""))
  assert(vim.fn.executable(dap.adapters.codelldb.executable.command) == 1)
end, debug.traceback)
if not ok then
  vim.api.nvim_err_writeln(err)
  vim.cmd("cquit 1")
else
  print("LSP attachment and debugger runtime checks passed.")
  vim.cmd("qa!")
end
