local M = {}

local function windows_interop_available()
  if vim.fn.executable("clip.exe") ~= 1 or vim.fn.executable("powershell.exe") ~= 1 then
    return false
  end
  -- executable() only checks PATH/permissions: Windows PE files can pass even
  -- when WSL interop is disabled. Probe without reading or changing the clipboard.
  local ok, result = pcall(function()
    return vim.system({ "powershell.exe", "-NoProfile", "-NonInteractive", "-Command", "exit 0" },
      { stdout = false, stderr = false }):wait(2000)
  end)
  return ok and result.code == 0
end

function M.setup()
  local is_wsl = vim.env.WSL_DISTRO_NAME or vim.uv.os_uname().release:lower():find("microsoft")
  if is_wsl and windows_interop_available() then
    -- Argument lists bypass the user's shell and its Windows-path quoting rules.
    local copy = { "clip.exe" }
    local paste = { "powershell.exe", "-NoProfile", "-NonInteractive", "-Command",
      [[(Get-Clipboard -Raw).Replace("`r`n", "`n")]] }
    vim.g.clipboard = {
      name = "wsl-clip",
      copy = { ["+"] = copy, ["*"] = copy },
      paste = { ["+"] = paste, ["*"] = paste },
      cache_enabled = 0,
    }
  elseif (is_wsl or vim.env.SSH_TTY or vim.env.SSH_CONNECTION)
    and not ((vim.env.WAYLAND_DISPLAY and vim.fn.executable("wl-copy") == 1 and vim.fn.executable("wl-paste") == 1)
      or (vim.env.DISPLAY and (vim.fn.executable("xclip") == 1 or vim.fn.executable("xsel") == 1))) then
    -- Explicitly select OSC52 so autodetection cannot select broken Windows
    -- executables again. Paste stays local: terminal clipboard queries may hang.
    local osc52 = require("vim.ui.clipboard.osc52")
    vim.g.clipboard = {
      name = "OSC52 (copy only)",
      copy = { ["+"] = osc52.copy("+"), ["*"] = osc52.copy("*") },
      paste = {
        ["+"] = function() return { vim.fn.getreg("", 1, true), vim.fn.getregtype("") } end,
        ["*"] = function() return { vim.fn.getreg("", 1, true), vim.fn.getregtype("") } end,
      },
    }
  end
  if vim.g.clipboard or vim.fn["provider#clipboard#Executable"]() ~= "" then
    vim.opt.clipboard:append("unnamedplus")
  end
end

return M
