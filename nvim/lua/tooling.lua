local M = {
  languages = {
    {
      parsers = { "lua" }, filetypes = { "lua" },
      lsp = { name = "lua_ls", package = "lua-language-server", sample = "lua" },
    },
    {
      parsers = { "javascript", "typescript", "tsx" },
      filetypes = { "javascript", "javascriptreact", "typescript", "typescriptreact" },
      lsp = { name = "ts_ls", package = "typescript-language-server", sample = "ts" },
    },
    {
      parsers = { "python" }, filetypes = { "python" },
      lsp = { name = "pyright", package = "pyright", sample = "py" },
      dap = { name = "python", package = "debugpy" },
    },
    {
      parsers = { "c", "cpp" }, filetypes = { "c", "cpp" },
      lsp = { name = "clangd", package = "clangd", sample = "cpp" },
      dap = { name = "codelldb", package = "codelldb" },
    },
    { parsers = { "markdown", "markdown_inline" }, filetypes = { "markdown" } },
  },
  parsers = {}, filetypes = {}, servers = {}, packages = {}, debuggers = {}, samples = {},
}

local function add(list, value)
  if not vim.tbl_contains(list, value) then
    list[#list + 1] = value
  end
end

for _, language in ipairs(M.languages) do
  for _, parser in ipairs(language.parsers) do add(M.parsers, parser) end
  for _, filetype in ipairs(language.filetypes) do add(M.filetypes, filetype) end
  if language.lsp then
    add(M.servers, language.lsp.name)
    add(M.packages, language.lsp.package)
    M.samples[#M.samples + 1] = { language.lsp.name, language.lsp.sample }
  end
  if language.dap then
    add(M.debuggers, language.dap.name)
    add(M.packages, language.dap.package)
  end
end

return M
