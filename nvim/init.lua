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

vim.opt.fileformat = "unix"
vim.opt.fileformats = "unix,dos"
require("clipboard").setup()

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
