-- vim:sw=2 tabstop=2

vim.cmd('source ~/.vim/common.vim')

-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

local synlangs = {
  "c", "cpp", "lua", "vim", "vimdoc", "query", "markdown", "python"
}

require("lazy").setup({
  { 'nvim-tree/nvim-tree.lua' },
  {
    'stevearc/oil.nvim',
    ---@module 'oil'
    ---@type oil.SetupOpts
    opts = {},
    -- Optional dependencies
    dependencies = { "nvim-tree/nvim-web-devicons" },
    -- Lazy loading is not recommended because it is very tricky to make it work correctly in all situations.
    lazy = false,
  },
  { 'hrsh7th/nvim-cmp', },
  { 'hrsh7th/cmp-buffer', },
  {
    'hrsh7th/cmp-nvim-lsp-signature-help',
    config = function()
      local cmp = require('cmp')
      cmp.setup({
        mapping = cmp.mapping.preset.insert({
          ['<C-s>'] = function() cmp.mapping.signature_help() end,
        }),
      })
    end,
  },

  {
    'neovim/nvim-lspconfig',
    dependencies = {
      'hrsh7th/cmp-nvim-lsp',
      'hrsh7th/nvim-cmp',
      'L3MON4D3/LuaSnip',
    },
  },

  {
    'junegunn/fzf.vim',
    dependencies = { 'junegunn/fzf' }
  },
  { 'junegunn/seoul256.vim' },

  -- Treesitter
  {
    'nvim-treesitter/nvim-treesitter',
    build = ':TSUpdate',
    config = function()
      require('nvim-treesitter.configs').setup({
        ensure_installed = synlangs,
        sync_install = false,
        auto_install = true,
        highlight = {
          enable = true,
          additional_vim_regex_highlighting = false,
        },
        indent = { enable = true },
      })
    end,
  },
  { 'folke/which-key.nvim' },

  {
    "NeogitOrg/neogit",
    dependencies = {
      "nvim-lua/plenary.nvim", -- required
      "sindrets/diffview.nvim", -- optional - Diff integration
    },
    config = true
  },

  { 'nomnivore/ollama.nvim' },
  { 'rhysd/vim-clang-format' },
  { 'NMAC427/guess-indent.nvim' },
})

vim.cmd [[colorscheme seoul256]]

vim.opt.expandtab = true
vim.opt.shiftwidth = 4
vim.opt.tabstop = 4

-- disable netrw at the very start of your init.lua
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1
vim.opt.termguicolors = true

require("nvim-tree").setup()
require("oil").setup()

vim.keymap.set('n', ']', function() require("nvim-tree.api").tree.toggle() end)

-- ~/.config/nvim/lua/finder.lua
require('finder')

-- ~/.config/nvim/lua/completion.lua
require('completion')

-- Auto detect indentation
vim.api.nvim_create_autocmd("BufReadPost", {
 callback = function()
   local indent = require("guess-indent").guess_from_buffer()
   if indent then
     vim.bo.shiftwidth = indent
     vim.bo.tabstop = indent
   end
 end,
})

-- ~/.config/nvim/lua/lsp.lua
require('lsp')

vim.diagnostic.config({
  virtual_text = false
})
vim.keymap.set('n', '<leader>,', function()
  vim.diagnostic.config({
    virtual_text = not vim.diagnostic.config().virtual_text
  })
end, opts)

require("which-key").setup{}

-- ~/.config/nvim/lua/keymaps.lua
require("keymaps")

require('ollama').setup {
  model = "qwen2.5:72b-instruct-q4_K_S",
  url = "https://api.ai.j.co",
}
