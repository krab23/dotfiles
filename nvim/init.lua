vim.g.dotfiles_nvim_initialized = false
if vim.env.DOTFILES_NVIM_PROVISION == "1" then
  -- Lazy catches plugin config errors and reports them through vim.notify.
  local notify = vim.notify
  vim.notify = function(message, level, opts)
    if level == vim.log.levels.ERROR then
      vim.g.dotfiles_nvim_init_error = tostring(message)
    end
    return notify(message, level, opts)
  end
end
if vim.fn.has("nvim-0.12") == 0 then
  error("This lockfile requires Neovim >= 0.12 (nvim-treesitter main). Run the nvim bootstrap module.")
end

-- Use the distro pynvim host independently of a project's activated venv.
if vim.fn.executable("/usr/bin/python3") == 1 then
  vim.g.python3_host_prog = "/usr/bin/python3"
end

--bootstrap lazy plugin manager
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local output = vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    lazypath,
  })
  if vim.v.shell_error ~= 0 then
    error("Cannot clone lazy.nvim: " .. output)
  end
  local lock = vim.json.decode(table.concat(vim.fn.readfile(vim.fn.stdpath("config") .. "/lazy-lock.json"), "\n"))
  output = vim.fn.system({ "git", "-C", lazypath, "checkout", lock["lazy.nvim"].commit })
  if vim.v.shell_error ~= 0 then
    error("Cannot checkout locked lazy.nvim: " .. output)
  end
end
vim.opt.rtp:prepend(lazypath)

-- vim settings
vim.g.mapleader=" " -- Make sure to set `mapleader` before lazy so your mappings are correct
vim.g.maplocalleader="\\" -- Same for `maplocalleader`
vim.g.loaded_netrw=1
vim.g.loaded_netrwPlugin=1
vim.opt.termguicolors=true
vim.opt.expandtab=true
vim.opt.shiftwidth=2
vim.opt.tabstop=2
vim.opt.relativenumber=true
vim.opt.number=true
vim.opt.textwidth=80
vim.opt.colorcolumn="+1"
vim.opt.foldenable= true
vim.opt.foldlevel=8
vim.opt.foldlevelstart=8

-- Clipboard: Windows interop only when available; otherwise use native detection.
vim.opt.fileformat = "unix"
vim.opt.fileformats = "unix,dos"

local is_wsl = vim.env.WSL_DISTRO_NAME or vim.uv.os_uname().release:lower():find("microsoft")
if is_wsl and vim.fn.executable("clip.exe") == 1 and vim.fn.executable("powershell.exe") == 1 then
  vim.g.clipboard = {
    name = "wsl-clip",
    copy = {
      ["+"] = "clip.exe",
      ["*"] = "clip.exe",
    },
    paste = {
      ["+"] = [[powershell.exe -NoProfile -Command "(Get-Clipboard -Raw).Replace(\"`r`n\", \"`n\")"]],
      ["*"] = [[powershell.exe -NoProfile -Command "(Get-Clipboard -Raw).Replace(\"`r`n\", \"`n\")"]],
    },
    cache_enabled = 0,
  }
elseif (vim.env.SSH_TTY or vim.env.SSH_CONNECTION)
  and not ((vim.env.WAYLAND_DISPLAY and vim.fn.executable("wl-copy") == 1 and vim.fn.executable("wl-paste") == 1)
    or (vim.env.DISPLAY and (vim.fn.executable("xclip") == 1 or vim.fn.executable("xsel") == 1))) then
  -- OSC52 copy works in supporting SSH terminals. Paste uses the local register
  -- cache: remote clipboard queries often hang or are blocked by the terminal.
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

-- Lazy writes its lock during restore/install. Provision from a disposable copy
-- so failed downloads cannot rewrite the checked-in source of truth.
local lockfile = vim.fn.stdpath("config") .. "/lazy-lock.json"
if vim.env.DOTFILES_NVIM_PROVISION == "1" then
  local provision_lock = vim.fn.stdpath("state") .. "/provision-lock.json"
  vim.fn.mkdir(vim.fn.stdpath("state"), "p")
  vim.fn.writefile(vim.fn.readfile(lockfile), provision_lock)
  lockfile = provision_lock
end
require("lazy").setup("plugins", {
  lockfile = lockfile,
  install = { missing = true },
  headless = { process = false, task = false, log = false },
  checker = { enabled = false },
  change_detection = { notify = false },
})

vim.api.nvim_create_autocmd("FileType", {
  pattern = {
    "lua",
    "javascript",
    "javascriptreact",
    "typescript",
    "typescriptreact",
    "python",
    "c",
    "cpp",
    "markdown",
  },
  callback = function()
    pcall(vim.treesitter.start)
    vim.wo.foldexpr="v:lua.vim.treesitter.foldexpr()"
    vim.wo.foldmethod="expr"
  end,
})
vim.g.dotfiles_nvim_initialized = true
