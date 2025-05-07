-- vim:sw=2 tabstop=2

vim.cmd('source ~/.vim/common.vim')

vim.g.ackprg = 'rg --vimgrep --smart-case'

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
  { 'preservim/nerdtree' },
  { 'mileszs/ack.vim' },
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

  { "tpope/vim-fugitive" },
  { "tpope/vim-rhubarb" },

  { 'nomnivore/ollama.nvim' },
  { 'rhysd/vim-clang-format' },
  { 'NMAC427/guess-indent.nvim' },
  { 'Vimjas/vim-python-pep8-indent' },
})

vim.cmd [[colorscheme seoul256]]

vim.api.nvim_create_autocmd("FileType", {
    pattern = "python",
    command = "setlocal formatoptions+=cro"
})

vim.opt.expandtab = true
vim.opt.shiftwidth = 4
vim.opt.tabstop = 4

-- continue comments on linebreaks
vim.cmd([[autocmd FileType * setlocal formatoptions+=cro]])

-- disable netrw at the very start of your init.lua
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1
vim.opt.termguicolors = true

vim.keymap.set('n', ']', ':NERDTreeToggle<CR>')

vim.api.nvim_create_autocmd("FileType", {
    pattern = "go",
    callback = function()
        vim.opt_local.formatoptions:append("ro") -- Continue comments when pressing Enter
        vim.opt_local.formatoptions:append("t")  -- Auto-wrap comments at textwidth
        vim.opt_local.textwidth = 87             -- Set max line width for wrapping
    end,
})

vim.cmd [[
  " If another buffer tries to replace NERDTree, put it in the other window, and bring back NERDTree.
  autocmd BufEnter * if winnr() == winnr('h') && bufname('#') =~ 'NERD_tree_\d\+' && bufname('%') !~ 'NERD_tree_\d\+' && winnr('$') > 1 |
      \ let buf=bufnr() | buffer# | execute "normal! \<C-W>w" | execute 'buffer'.buf | endif

  " Close the tab if NERDTree is the only window remaining in it.
  autocmd BufEnter * if winnr('$') == 1 && exists('b:NERDTree') && b:NERDTree.isTabTree() | quit | endif
]]

vim.keymap.set('n', ']', function() require("nvim-tree.api").tree.toggle() end)

-- ~/.config/nvim/lua/finder.lua
require('finder')

-- ~/.config/nvim/lua/completion.lua
require('completion')

require('guess-indent').setup {}

-- ~/.config/nvim/lua/lsp.lua
require('lsp')

-- ~/.config/nvim/lua/keymaps.lua
require("keymaps")

require('ollama').setup {
  model = "qwen2.5:72b-instruct-q4_K_S",
  url = "https://api.ai.j.co",
}
