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
      if vim.env.DOTFILES_NVIM_PROVISION ~= "1" then
        ts.install(require("tooling").parsers)
      end
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
    cmd = "Copilot",
  },

  -- LSP
  {
    "williamboman/mason.nvim",
    cmd = { "Mason", "MasonInstall", "MasonUpdate" },
    config = function()
      require("mason").setup()
    end,
  },
  {
    "williamboman/mason-lspconfig.nvim",
    lazy = false,
    dependencies = {
      "williamboman/mason.nvim",
      "neovim/nvim-lspconfig",
    },
    config = function()
      require("mason-lspconfig").setup({
        ensure_installed = vim.env.DOTFILES_NVIM_PROVISION == "1" and {} or require("tooling").servers,
        automatic_enable = false,
      })
      vim.lsp.enable(require("tooling").servers)
    end,
  },
  {
    "neovim/nvim-lspconfig",
    config = function()
      local default_capabilities = vim.lsp.protocol.make_client_capabilities()

      for _, server_name in ipairs(require("tooling").servers) do
        vim.lsp.config(server_name, { capabilities = default_capabilities })
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
                vim.env.VIMRUNTIME .. "/lua",
                vim.fn.stdpath("config") .. "/lua",
              },
            },
          },
        },
      })

    end,
  },

  -- DAP
  {
    "jay-babu/mason-nvim-dap.nvim",
    lazy = false,
    dependencies = {
      "williamboman/mason.nvim",
      "mfussenegger/nvim-dap",
    },
    config = function()
      require("mason-nvim-dap").setup({
        ensure_installed = vim.env.DOTFILES_NVIM_PROVISION == "1" and {} or {
          "codelldb",
          "python",
        },
        automatic_installation = false,
      })
    end,
  },
  {
    "mfussenegger/nvim-dap",
    dependencies = { "williamboman/mason.nvim" },
    keys = {
      { "<F5>", function() require("dap").continue() end, desc = "DAP continue" },
      { "<F10>", function() require("dap").step_over() end, desc = "DAP step over" },
      { "<F11>", function() require("dap").step_into() end, desc = "DAP step into" },
      { "<F12>", function() require("dap").step_out() end, desc = "DAP step out" },
      { "<leader>db", function() require("dap").toggle_breakpoint() end, desc = "DAP toggle breakpoint" },
    },
    config = function()
      local dap = require("dap")
      -- Mason v2 removed Package:get_install_path(). Use its configured root.
      local mason_root = require("mason.settings").current.install_root_dir

      dap.adapters.codelldb = {
        type = "server",
        port = "${port}",
        executable = {
          command = mason_root .. "/bin/codelldb",
          args = { "--port", "${port}" },
          detached = false,
        },
      }

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

      local debugpy_path = mason_root .. "/packages/debugpy/venv/bin/python"

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

            local project_python = vim.fn.getcwd() .. "/.venv/bin/python"
            if vim.fn.executable(project_python) == 1 then
              return project_python
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
