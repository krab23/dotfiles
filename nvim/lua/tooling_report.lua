local M = {}

-- Best effort: reporting must never hide the original provisioning error.
function M.print()
  print("Neovim toolchain report: " .. tostring(vim.version()))
  for _, binary in ipairs({ "tree-sitter", "node", "npm", "npx", "python3" }) do
    local ok, result = pcall(function()
      return vim.system({ binary, "--version" }, { text = true }):wait(5000)
    end)
    print(binary .. ": " .. (ok and vim.trim((result.stdout or "") .. (result.stderr or "")) or "unavailable"))
  end
  local ok, settings = pcall(require, "mason.settings")
  if not ok then
    print("Mason unavailable")
    return
  end
  local root = settings.current.install_root_dir
  for _, name in ipairs(require("tooling").packages) do
    local receipt = root .. "/packages/" .. name .. "/mason-receipt.json"
    local readable, contents = pcall(function()
      return vim.json.decode(table.concat(vim.fn.readfile(receipt), "\n"))
    end)
    local source = readable and (contents.source or contents.primary_source)
    print(name .. ": " .. (source and (source.id or vim.inspect(source)) or "no installed receipt"))
  end
end

return M
