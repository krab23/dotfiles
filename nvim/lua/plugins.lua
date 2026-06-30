return {
  -- Colorschemes
  {
    "catppuccin/nvim",
    name = "catppuccin",
    lazy = false,
    priority = 1000,
    config = function()
      require("catppuccin").setup({
        flavour = "frappe",
        transparent_background = true,
      })
      vim.cmd.colorscheme("catppuccin-frappe")
    end,
  },
  {
    "rebelot/kanagawa.nvim",
    name = "kanagawa",
    lazy = true,
  },

  -- Practice / Utilities
  {
    "ThePrimeagen/vim-be-good",
    cmd = "VimBeGood",
  },
  {
    "nvim-tree/nvim-web-devicons",
    lazy = true,
  },
  {
    "nvim-tree/nvim-tree.lua",
    cmd = { "NvimTreeOpen", "NvimTreeToggle", "NvimTreeFocus" },
    keys = {
      { "<leader>e", "<cmd>NvimTreeToggle<CR>", desc = "Toggle file tree" },
    },
    dependencies = {
      "nvim-tree/nvim-web-devicons",
    },
    config = function()
      require("nvim-tree").setup({})
    end,
  },
  {
    "nvim-lualine/lualine.nvim",
    event = "VeryLazy",
    dependencies = {
      "nvim-tree/nvim-web-devicons",
    },
    config = function()
      require("lualine").setup({
        options = {
          component_separators = { left = "⧽", right = "⧼" },
          section_separators = { left = "", right = "" },
        },
      })
    end,
  },
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    lazy = false,
    build = ":TSUpdate",
    config = function()
      local ts = require("nvim-treesitter")

      ts.setup({})
      ts.install({
        "lua",
        "javascript",
        "typescript",
        "python",
        "markdown",
        "markdown_inline",
      })
    end,
  },
  {
    "nvim-telescope/telescope.nvim",
    cmd = "Telescope",
    dependencies = {
      "nvim-lua/plenary.nvim",
    },
    keys = {
      { "<leader>ff", "<cmd>Telescope find_files<CR>", desc = "Find files" },
      { "<leader>fg", "<cmd>Telescope live_grep<CR>", desc = "Live grep" },
      { "<leader>fb", "<cmd>Telescope buffers<CR>", desc = "Find buffers" },
    },
  },
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    config = function()
      require("which-key").setup({})
    end,
  },
  {
    "github/copilot.vim",
    event = "InsertEnter",
  },

  -- LSP
  {
    "williamboman/mason.nvim",
    cmd = { "Mason", "MasonInstall", "MasonUpdate" },
    build = ":MasonUpdate",
    config = function()
      require("mason").setup()
    end,
  },
  {
    "williamboman/mason-lspconfig.nvim",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = {
      "williamboman/mason.nvim",
      "neovim/nvim-lspconfig",
    },
    config = function()
      require("mason-lspconfig").setup({
        automatic_enable = false,
      })
    end,
  },
  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      local mason_lspconfig = require("mason-lspconfig")

      local default_capabilities = vim.lsp.protocol.make_client_capabilities()

      for _, server_name in ipairs(mason_lspconfig.get_installed_servers()) do
        if server_name ~= "lua_ls" then
          vim.lsp.config(server_name, {
            capabilities = default_capabilities,
          })
          vim.lsp.enable(server_name)
        end
      end

      vim.lsp.config("lua_ls", {
        capabilities = default_capabilities,
        settings = {
          Lua = {
            diagnostics = {
              globals = { "vim" },
            },
            workspace = {
              library = {
                [vim.fn.expand("$VIMRUNTIME/lua")] = true,
                [vim.fn.stdpath("config") .. "/lua"] = true,
              },
            },
          },
        },
      })

      vim.lsp.enable("lua_ls")
    end,
  },

  -- DAP
  {
    "jay-babu/mason-nvim-dap.nvim",
    event = "VeryLazy",
    dependencies = {
      "williamboman/mason.nvim",
      "mfussenegger/nvim-dap",
    },
    config = function()
      require("mason-nvim-dap").setup({
        ensure_installed = {
          "codelldb",
          "python",
        },
        automatic_installation = false,
      })
    end,
  },
  {
    "mfussenegger/nvim-dap",
    keys = {
      { "<F5>", function() require("dap").continue() end, desc = "DAP continue" },
      { "<F10>", function() require("dap").step_over() end, desc = "DAP step over" },
      { "<F11>", function() require("dap").step_into() end, desc = "DAP step into" },
      { "<F12>", function() require("dap").step_out() end, desc = "DAP step out" },
      { "<leader>db", function() require("dap").toggle_breakpoint() end, desc = "DAP toggle breakpoint" },
    },
    config = function()
      local dap = require("dap")
      local mason_registry = require("mason-registry")

      local codelldb_path = "codelldb"
      local liblldb_path = nil

      if mason_registry.has_package("codelldb") then
        local pkg = mason_registry.get_package("codelldb")
        local install_path = nil

        if pkg and type(pkg.get_install_path) == "function" then
          install_path = pkg:get_install_path()
        elseif pkg and type(pkg.install_path) == "string" then
          install_path = pkg.install_path
        elseif pkg and type(pkg.path) == "string" then
          install_path = pkg.path
        end

        if install_path then
          codelldb_path = install_path .. "/extension/adapter/codelldb"

          if vim.fn.has("mac") == 1 then
            liblldb_path = install_path .. "/extension/lldb/lib/liblldb.dylib"
          elseif vim.fn.has("win32") == 1 then
            liblldb_path = install_path .. "/extension/lldb/bin/liblldb.dll"
          else
            liblldb_path = install_path .. "/extension/lldb/lib/liblldb.so"
          end
        end
      end

      dap.adapters.codelldb = {
        type = "server",
        port = "${port}",
        executable = {
          command = codelldb_path,
          args = { "--port", "${port}" },
          detached = false,
        },
      }

      if liblldb_path then
        dap.adapters.codelldb.env = {
          LLDB_LAUNCH_FLAG_LAUNCH_IN_TTY = "YES",
        }
      end

      for _, lang in ipairs({ "c", "cpp" }) do
        dap.configurations[lang] = {
          {
            name = "Launch file",
            type = "codelldb",
            request = "launch",
            program = function()
              return vim.fn.input("Path to executable: ", vim.fn.getcwd() .. "/", "file")
            end,
            cwd = "${workspaceFolder}",
            stopOnEntry = false,
          },
          {
            name = "Attach to process",
            type = "codelldb",
            request = "attach",
            pid = require("dap.utils").pick_process,
            cwd = "${workspaceFolder}",
          },
        }
      end

      local debugpy_path = vim.fn.stdpath("data")
        .. "/mason/packages/debugpy/venv/bin/python"

      dap.adapters.python = {
        type = "executable",
        command = debugpy_path,
        args = { "-m", "debugpy.adapter" },
      }

      dap.configurations.python = {
        {
          type = "python",
          request = "launch",
          name = "Launch file",
          program = "${file}",
          pythonPath = function()
            local venv = vim.fn.getenv("VIRTUAL_ENV")

            if venv and venv ~= vim.NIL and venv ~= "" then
              return venv .. "/bin/python"
            end

            local python3 = vim.fn.exepath("python3")
            if python3 and python3 ~= "" then
              return python3
            end

            local python = vim.fn.exepath("python")
            if python and python ~= "" then
              return python
            end

            return "python"
          end,
        },
      }
    end,
  },

  -- Markdown rendering
  {
    "MeanderingProgrammer/render-markdown.nvim",
    ft = { "markdown" },
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
      "nvim-tree/nvim-web-devicons",
    },
    config = function()
      require("render-markdown").setup({
        start_enabled = true,
      })
    end,
  },
}
