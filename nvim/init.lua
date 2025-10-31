--declare python host program
vim.g.python3_host_prog="/usr/bin/python3"

--bootstrap lazy plugin manager
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", -- latest stable release
    lazypath,
  })
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


require("lazy").setup("plugins")
