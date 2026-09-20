-- Separate invocations ensure newly restored plugin code is loaded from disk.
local M = {}

local function run(fn)
  local ok, err = xpcall(function()
    assert(vim.g.dotfiles_nvim_initialized == true, "Neovim initialization did not complete")
    assert(not vim.g.dotfiles_nvim_init_error, vim.g.dotfiles_nvim_init_error)
    assert(vim.v.errmsg == "", "Neovim startup error: " .. vim.v.errmsg)
    fn()
  end, debug.traceback)
  if not ok then
    vim.api.nvim_err_writeln(err)
    vim.cmd("cquit 1")
  else
    vim.cmd("qa!")
  end
end

function M.plugins()
  run(function()
    local lock = vim.json.decode(table.concat(vim.fn.readfile(vim.fn.stdpath("config") .. "/lazy-lock.json"), "\n"))
    require("lazy").restore({ wait = true })
    for name, plugin in pairs(require("lazy.core.config").plugins) do
      assert(lock[name], "Missing lock entry: " .. name)
      local result = vim.system({ "git", "-C", plugin.dir, "rev-parse", "HEAD" }, { text = true }):wait()
      assert(result.code == 0 and vim.trim(result.stdout) == lock[name].commit, "Failed to restore " .. name)
    end
  end)
end

function M.tools()
  run(function()
    local tooling = require("tooling")
    require("nvim-treesitter").install(tooling.parsers):wait(600000)
    -- Update also repairs parsers left over from a different plugin revision.
    require("nvim-treesitter").update(tooling.parsers):wait(600000)
    for _, lang in ipairs(tooling.parsers) do
      assert(vim.treesitter.language.add(lang), "Parser unavailable: " .. lang)
    end

    local registry = require("mason-registry")
    local refreshed, refresh_ok = false, false
    registry.refresh(function(ok)
      refresh_ok, refreshed = ok, true
    end)
    assert(vim.wait(120000, function() return refreshed end, 100), "Mason registry refresh timed out")
    assert(refresh_ok, "Mason registry refresh failed")
    local pending, failures = 0, {}
    for _, name in ipairs(tooling.packages) do
      local pkg = registry.get_package(name)
      if not pkg:is_installed() then
        pending = pending + 1
        pkg:install():once("closed", function()
          if not pkg:is_installed() then
            failures[#failures + 1] = name
          end
          pending = pending - 1
        end)
      end
    end
    assert(vim.wait(900000, function() return pending == 0 end, 100), "Mason installation timed out; see :MasonLog")
    assert(#failures == 0, "Mason installation failed: " .. table.concat(failures, ", ") .. "; see :MasonLog")
    local dap = require("dap")
    assert(vim.fn.executable(dap.adapters.codelldb.executable.command) == 1, "Missing codelldb executable")
    assert(vim.fn.executable(dap.adapters.python.command) == 1, "Missing debugpy Python")
    print("Neovim plugins, parsers, LSP servers and DAP adapters ready.")
  end)
end

return M
