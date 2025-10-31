return {
  --colorschemes
  {
    "catppuccin/nvim",
    lazy = false,
    name = "catppuccin",
    priority = 1000,
    config = function()
      require("catppuccin").setup({
        flavour = "frappe",
        transparent_background = true})
        vim.cmd.colorscheme "catppuccin-frappe"
    end
  },
  {
    "rebelot/kanagawa.nvim",
    lazy = false,
    name = "kanagawa",
    priority = 1000,
    config = function()
      require("kanagawa").setup({
        theme = "dragon",
        transparent = true})
        --vim.cmd.colorscheme "kanagawa-dragon"
    end
  },


  --vim be good
  {
    "ThePrimeagen/vim-be-good",
    lazy=true
  },


  --utilities
  {
    "nvim-tree/nvim-web-devicons",
    lazy = false,
  },
  {
    "nvim-tree/nvim-tree.lua",
    lazy = false,
    dependencies = {
      "nvim-tree/nvim-web-devicons",
    },
    config = function()
      require("nvim-tree").setup({})
    end
  },
  {
    "nvim-lualine/lualine.nvim",
    lazy=false,
    dependencies = {
      "nvim-tree/nvim-web-devicons",
    },
    config = function()
      require("lualine").setup({
        options = {
          component_separators = {left = '⧽', right = '⧼'},
          section_separators = {left = '', right = ''},
          --Separator Options: 
          }
      })
    end
  },
  {
    "nvim-treesitter/nvim-treesitter",
    lazy = false,
    config = function()
      require("nvim-treesitter.configs").setup({
        highlight = {
          enable = true,
          additional_vim_regex_highlight = false,
        }
      })
    end
  },
  {
    "nvim-telescope/telescope.nvim",
    lazy = false,
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-lua/popup.nvim",
    },
    vim.keymap.set("n","<leader>ff",":Telescope find_files<CR>",{}),
    vim.keymap.set("n","<leader>fg",":Telescope live_grep<CR>",{}),
    vim.keymap.set("n","<leader>fb",":Telescope buffers<CR>",{}),
  },
  {
    "folke/which-key.nvim",
    lazy = true
  },
  {
    "github/copilot.vim",
    lazy = false
  },
  --lsp
  {
    "williamboman/mason.nvim",
    lazy = false,
    event = "BufReadPre",
    config = function()
      require("mason").setup()
    end
  },
  {
    "williamboman/mason-lspconfig.nvim",
    lazy = false,
    event = "BufReadPre",
    dependencies = {"williamboman/mason.nvim"},
    config = function()
      require("mason-lspconfig").setup({
        automatic_installation = true
      })
    end
  },
  {
    "neovim/nvim-lspconfig",
    lazy = false,
    dependencies = {"williamboman/mason-lspconfig.nvim"},
    config = function()
--      require("lspconfig").lua_ls.setup({
--        settings = {
--          Lua = {
--            diagnostics = {
--              globals = {
--                "vim"
--              },
--            },
--            workspace = {
--              library = {
--                [vim.fn.expand("$VIMRUNTIME0/lua")] = true,
--                [vim.fn.stdpath("config") .. "/lua"] = true,
--              },
--            },
--          }
--        }
--     })
    end
  },
  {
    "mfussenegger/nvim-dap",
    optional = true,
    dependencies = {
      -- Ensure C/C++ debugger is installed
      "williamboman/mason.nvim",
      optional = true,
      opts = function(_, opts)
        if type(opts.ensure_installed) == "table" then
          vim.list_extend(opts.ensure_installed, { "codelldb" })
        end
      end,
    },
    opts = function()
    local dap = require("dap")
    if not dap.adapters["codelldb"] then
      require("dap").adapters["codelldb"] = {
        type = "server",
        host = "localhost",
        port = "${port}",
        executable = {
          command = "codelldb",
          args = {
            "--port",
            "${port}",
          },
        },
      }
    end
    for _, lang in ipairs({ "c", "cpp" }) do
      dap.configurations[lang] = {
        {
          type = "codelldb",
          request = "launch",
          name = "Launch file",
          program = function()
            return vim.fn.input("Path to executable: ", vim.fn.getcwd() .. "/", "file")
          end,
          cwd = "${workspaceFolder}",
        },
        {
          type = "codelldb",
          request = "attach",
          name = "Attach to process",
          pid = require("dap.utils").pick_process,
          cwd = "${workspaceFolder}",
        },
      }
    end
  end,
  },
  {
    "MeanderingProgrammer/markdown.nvim",
    name = "render-markdown",
    dependencies = {"nvim-treesitter/nvim-treesitter"},
    config = function()
      require("render-markdown").setup({
        start_enabled = true,
      })
    end,
  }
}
