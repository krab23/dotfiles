-- Offline provider-selection regressions; never launch Windows programs or
-- access the host clipboard. Run through tests/nvim.sh with -u NONE.
local real_vim = vim
local clipboard = dofile(vim.env.DOTFILES_ROOT .. "/nvim/lua/clipboard/init.lua")
local osc52 = require("vim.ui.clipboard.osc52")
local original_copy = osc52.copy
local ok, err = pcall(function()
  local function check(case)
    local probes, detections, copied = 0, 0, {}
    osc52.copy = function(reg)
      return function(lines) copied[reg] = lines end
    end
    _G.vim = {
      env = case.env or { WSL_DISTRO_NAME = "Arch" },
      uv = { os_uname = function() return { release = case.release or "Linux" } end },
      g = {},
      opt = { clipboard = { append = function(_, value) assert(value == "unnamedplus") end } },
      fn = {
        executable = function(name)
          if case.missing == name then return 0 end
          return (name == "clip.exe" or name == "powershell.exe" or name == case.gui) and 1 or 0
        end,
        ["provider#clipboard#Executable"] = function()
          detections = detections + 1
          return case.gui or ""
        end,
        getreg = function() return { "cached yank" } end,
        getregtype = function() return "V" end,
      },
      system = function(argv, opts)
        probes = probes + 1
        assert(argv[1] == "powershell.exe" and argv[#argv] == "exit 0")
        assert(opts.stdout == false and opts.stderr == false)
        if case.spawn_error then error("ENOEXEC: cannot execute binary file") end
        return { wait = function(_, timeout)
          assert(timeout == 2000)
          return { code = case.code or 0 }
        end }
      end,
    }
    clipboard.setup()
    assert(probes == case.probes, case.name .. ": probe count")
    local provider = vim.g.clipboard
    assert((provider and provider.name or "native") == case.expected, case.name)
    if provider then
      assert(detections == 0, "must not autodetect broken Windows executables")
      for _, reg in ipairs({ "+", "*" }) do
        if case.expected == "wsl-clip" then
          assert(provider.copy[reg][1] == "clip.exe")
          assert(provider.paste[reg][1] == "powershell.exe")
          assert(provider.paste[reg][5] == [[(Get-Clipboard -Raw).Replace("`r`n", "`n")]])
        else
          provider.copy[reg]({ "yank" })
          assert(copied[reg][1] == "yank")
          local paste = provider.paste[reg]()
          assert(paste[1][1] == "cached yank" and paste[2] == "V")
        end
      end
    else
      assert(detections == 1)
    end
  end
  for _, case in ipairs({
    { name = "working interop", probes = 1, expected = "wsl-clip" },
    { name = "spawn failure", spawn_error = true, probes = 1, expected = "OSC52 (copy only)" },
    { name = "execution failure", code = 126, probes = 1, expected = "OSC52 (copy only)" },
    { name = "timeout", code = 124, probes = 1, expected = "OSC52 (copy only)" },
    { name = "missing clip", missing = "clip.exe", probes = 0, expected = "OSC52 (copy only)" },
    { name = "missing PowerShell", missing = "powershell.exe", probes = 0, expected = "OSC52 (copy only)" },
    { name = "kernel detection", env = {}, release = "5.15-microsoft-standard-WSL2", probes = 1, expected = "wsl-clip" },
    { name = "WSLg fallback", env = { WSL_DISTRO_NAME = "Arch", DISPLAY = ":0" },
      code = 126, gui = "xclip", probes = 1, expected = "native" },
    { name = "SSH fallback", env = { SSH_CONNECTION = "remote" }, probes = 0, expected = "OSC52 (copy only)" },
    { name = "native Linux", env = {}, probes = 0, expected = "native" },
  }) do check(case) end
end)
_G.vim = real_vim
osc52.copy = original_copy
if not ok then error(err) end
print("Clipboard selection checks passed.")
