vim.cmd('source ~/.vim/common.vim')
vim.cmd('source ~/.config/nvim/old.vim')

vim.g.loaded_python3_provider = 0

require('nvim-web-devicons').setup {
 -- your personnal icons can go here (to override)
 -- DevIcon will be appended to `name`
 -- override = {
 --  zsh = {
 --    icon = "",
 --    color = "#428850",
 --    name = "Zsh"
 --  }
 -- };
 -- globally enable default icons (default to false)
 -- will get overriden by `get_icons` option
 default = true;
}

-- local actions = require "fzf-lua.actions"
-- require'fzf-lua'.setup {
--   winopts = {
--     -- split         = "belowright new",-- open in a split instead?
--                                         -- "belowright new"  : split below
--                                         -- "aboveleft new"   : split above
--                                         -- "belowright vnew" : split right
--                                         -- "aboveleft vnew   : split left
--     -- Only valid when using a float window
--     -- (i.e. when 'split' is not defined)
--     height           = 0.85,            -- window height
--     width            = 0.95,            -- window width
--     row              = 0.35,            -- window row position (0=top, 1=bottom)
--     col              = 0.50,            -- window col position (0=left, 1=right)
--     -- border argument passthrough to nvim_open_win(), also used
--     -- to manually draw the border characters around the preview
--     -- window, can be set to 'false' to remove all borders or to
--     -- 'none', 'single', 'double' or 'rounded' (default)
--     border           = { '╭', '─', '╮', '│', '╯', '─', '╰', '│' },
--     fullscreen       = false,           -- start fullscreen?
--     hl = {
--       normal         = 'Normal',        -- window normal color (fg+bg)
--       border         = 'Normal',        -- border color (try 'FloatBorder')
--       -- Only valid with the builtin previewer:
--       cursor         = 'Cursor',        -- cursor highlight (grep/LSP matches)
--       cursorline     = 'CursorLine',    -- cursor line
--       -- title       = 'Normal',        -- preview border title (file/buffer)
--       -- scrollbar_f = 'PmenuThumb',    -- scrollbar "full" section highlight
--       -- scrollbar_e = 'PmenuSbar',     -- scrollbar "empty" section highlight
--     },
--     preview = {
--       -- default     = 'bat',           -- override the default previewer?
--                                         -- default uses the 'builtin' previewer
--       border         = 'border',        -- border|noborder, applies only to
--                                         -- native fzf previewers (bat/cat/git/etc)
--       wrap           = 'nowrap',        -- wrap|nowrap
--       hidden         = 'nohidden',      -- hidden|nohidden
--       vertical       = 'down:45%',      -- up|down:size
--       horizontal     = 'right:60%',     -- right|left:size
--       layout         = 'flex',          -- horizontal|vertical|flex
--       flip_columns   = 120,             -- #cols to switch to horizontal on flex
--       -- Only valid with the builtin previewer:
--       title          = true,            -- preview border title (file/buf)?
--       scrollbar      = 'float',         -- `false` or string:'float|border'
--                                         -- float:  in-window floating border 
--                                         -- border: in-border chars (see below)
--       scrolloff      = '-2',            -- float scrollbar offset from right
--                                         -- applies only when scrollbar = 'float'
--       scrollchars    = {'█', '' },      -- scrollbar chars ({ <full>, <empty> }
--                                         -- applies only when scrollbar = 'border'
--     },
--   },
--   fzf_opts = {
--     -- options are sent as `<left>=<right>`
--     -- set to `false` to remove a flag
--     -- set to '' for a non-value flag
--     -- for raw args use `fzf_args` instead
--     ['--ansi']        = '',
--     ['--prompt']      = '> ',
--     ['--info']        = 'inline',
--     ['--height']      = '100%',
--     -- ['--layout']      = 'reverse',
--   },
--   files = {
--     fd_opts = '--color never --type f --hidden --follow --exclude .git ' ..
--       '--exclude __pycache__ --exclude .mypy_cache --exclude .cache ' ..
--       '--exclude node_modules --exclude venv --exclude venv3',
--   },
-- }

require("which-key").setup {
}

require('diffview').setup { 
}

local has_words_before = function()
  local line, col = unpack(vim.api.nvim_win_get_cursor(0))
  return col ~= 0 and vim.api.nvim_buf_get_lines(0, line - 1, line, true)[1]:sub(col, col):match("%s") == nil
end

local feedkey = function(key, mode)
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(key, true, true, true), mode, true)
end

local cmp = require('cmp')

local buffer_source = {
  name = 'buffer',
  option = {
    get_bufnrs = function()
      return vim.api.nvim_list_bufs()
    end
  },
}

local tabcomplete = function(fallback)
  return function(fallback, srcs)
    if cmp.visible() then
      cmp.select_next_item({ behavior = cmp.SelectBehavior.Insert })
    elseif has_words_before() then
      cmp.complete({ config = { sources = srcs } })
      cmp.open_docs()
      cmp.select_next_item({ behavior = cmp.SelectBehavior.Insert })
    else
      fallback() -- The fallback function sends a already mapped key. In this case, it's probably `<Tab>`.
    end
  end
end

local cmp_next = function(fallback)
  if cmp.visible() then cmp.select_next_item() else fallback() end
end

local cmp_prev = function(fallback)
  if cmp.visible() then cmp.select_prev_item() else fallback() end
end

local cmp_mappings = {
  ["<CR>"] = cmp.mapping.confirm({ select = true }),
  ["<Tab>"] = cmp.mapping(tabcomplete(fallback, { { name = 'nvim_lsp' }, buffer_source }), { "i", "s" }),

  -- trigger snippet completions
  ["<C-n>"] = cmp.mapping(tabcomplete(fallback, { buffer_source }), { "i", "s" }),

  ["<C-Space>"] = cmp.mapping(tabcomplete(fallback, { { name = 'nvim_lsp' } }), { "i", "s" }),

  ["<C-p>"] = cmp.mapping(cmp_prev, { 'i', 's' }),
  ["<S-Tab>"] = cmp.mapping(cmp_prev, { 'i', 's' }),
  ["<C-S-Tab>"] = cmp.mapping(cmp_prev, { 'i', 's' }),
  ["<Up>"] = cmp.mapping(cmp_prev, { 'i', 's' }),
  ["<Down>"] = cmp.mapping(cmp_next, { 'i', 's' }),

  ['<C-d>'] = cmp.mapping(cmp.mapping.scroll_docs(-4), { 'i', 'c' }),
  ['<C-u>'] = cmp.mapping(cmp.mapping.scroll_docs(4), { 'i', 'c' }),
  ['<C-y>'] = cmp.config.disable, -- Specify `cmp.config.disable` if you want to remove the default `<C-y>` mapping.
  ['<C-e>'] = cmp.mapping({
    i = cmp.mapping.abort(),
    c = cmp.mapping.close(),
  }),
  ['<CR>'] = cmp.mapping.confirm({ select = true }),
}

cmp.setup({
  snippet = {
    -- REQUIRED - you must specify a snippet engine
    expand = function(args)
      vim.fn["vsnip#anonymous"](args.body) -- For `vsnip` users.
      -- require('luasnip').lsp_expand(args.body) -- For `luasnip` users.
      -- vim.fn["UltiSnips#Anon"](args.body) -- For `ultisnips` users.
      -- require'snippy'.expand_snippet(args.body) -- For `snippy` users.
    end,
  },
  mapping = cmp_mappings,
  sources = cmp.config.sources({
    { name = 'nvim_lsp' },
    buffer_source,
    { name = 'vsnip' }
  }),
  completion = { 
    completeopt = "menu,menuone,noselect",
    autocomplete = false
  },
})

cmp.setup.cmdline({ '/', '?' }, {
    mapping = cmp.mapping.preset.cmdline(),
    sources = {
      buffer_source,
    }
  })

cmp.setup.cmdline(':', {
  mapping = cmp.mapping.preset.cmdline({
    ["<Tab>"] = cmp.mapping(function(fallback)
    if cmp.visible() then
      cmp.select_next_item({ behavior = cmp.SelectBehavior.Insert })
    else
      cmp.complete({ config = { sources = { 
        { name = 'path' }, 
        { name = 'cmdline' }, } } })
      cmp.select_next_item({ behavior = cmp.SelectBehavior.Insert })
    end
  end, { "i", "s" })
  }),
  sources = cmp.config.sources({
    { name = 'path' }
  }, {
    { name = 'cmdline' }
  })
})


-- LSP config
-- -----------------------------------------------------------------------------------

local lspconfig = require('lspconfig')
local LSP_DEBOUNCE = 400
-- Setup lspconfig.
local capabilities = require('cmp_nvim_lsp').default_capabilities()


lspconfig.clangd.setup{
  capabilities = capabilities,
  cmd = {
    -- see clangd --help-hidden
    "clangd",
    "--background-index",
    -- by default, clang-tidy use -checks=clang-diagnostic-*,clang-analyzer-*
    -- to add more checks, create .clang-tidy file in the root directory
    -- and add Checks key, see https://clang.llvm.org/extra/clang-tidy/
    "--clang-tidy",
    "--completion-style=bundled",
    "--cross-file-rename",
    "--header-insertion=iwyu",
  },
  flags = {
    debounce_text_changes = LSP_DEBOUNCE,
  },
}
lspconfig.pylsp.setup{
  capabilities = capabilities,
  flags = {
    debounce_text_changes = LSP_DEBOUNCE,
  },
  settings = {
    pylsp = {
      plugins = {
        ruff = {
          enabled = true,
        },
        autopep8 = {
          enabled = false,
        },
        yapf = {
          enabled = true,
          args = '--style={based_on_style: yapf, indent_width: 4}'
        },
      },
    },
  };
}

-- require('lspconfig').pyright.setup{
--   capabilities = capabilities,
--   flags = {
--     debounce_text_changes = LSP_DEBOUNCE,
--   },
-- }


lspconfig.rust_analyzer.setup{
  capabilities = capabilities,
  flags = {
    debounce_text_changes = LSP_DEBOUNCE,
  },
}


-- Global mappings.
-- See `:help vim.diagnostic.*` for documentation on any of the below functions
vim.keymap.set('n', '<space>e', vim.diagnostic.open_float)
vim.keymap.set('n', '[d', vim.diagnostic.goto_prev)
vim.keymap.set('n', ']d', vim.diagnostic.goto_next)
vim.keymap.set('n', '<space>q', vim.diagnostic.setloclist)

-- Use LspAttach autocommand to only map the following keys
-- after the language server attaches to the current buffer
vim.api.nvim_create_autocmd('LspAttach', {
  group = vim.api.nvim_create_augroup('UserLspConfig', {}),
  callback = function(ev)
    -- Enable completion triggered by <c-x><c-o>
    vim.bo[ev.buf].omnifunc = 'v:lua.vim.lsp.omnifunc'

    -- Buffer local mappings.
    -- See `:help vim.lsp.*` for documentation on any of the below functions
    local opts = { buffer = ev.buf }
    vim.keymap.set('n', 'gD', vim.lsp.buf.declaration, opts)
    vim.keymap.set('n', 'gt', '<cmd>tab split | lua vim.lsp.buf.definition()<cr>', opts)
    vim.keymap.set('n', 'gS', '<cmd>split | lua vim.lsp.buf.definition()<cr>', opts)
    vim.keymap.set('n', 'gd', vim.lsp.buf.definition, opts)
    vim.keymap.set('n', 'K', vim.lsp.buf.hover, opts)
    vim.keymap.set('n', 'gi', vim.lsp.buf.implementation, opts)
    vim.keymap.set('n', '<C-k>', vim.lsp.buf.signature_help, opts)
    vim.keymap.set('n', '<space>wa', vim.lsp.buf.add_workspace_folder, opts)
    vim.keymap.set('n', '<space>wr', vim.lsp.buf.remove_workspace_folder, opts)
    vim.keymap.set('n', '<space>wl', function()
      print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
      end, opts)
    vim.keymap.set('n', '<space>D', vim.lsp.buf.type_definition, opts)
    vim.keymap.set('n', '<space>rn', vim.lsp.buf.rename, opts)
    vim.keymap.set({ 'n', 'v' }, '<space>ca', vim.lsp.buf.code_action, opts)
    vim.keymap.set('n', 'gr', vim.lsp.buf.references, opts)
    vim.keymap.set('n', '<space>f', function()
      vim.lsp.buf.format { async = true }
    end, opts)

    vim.keymap.set('i', '<C-s>', vim.lsp.buf.signature_help, opts)
    vim.keymap.set('n', '<leader>dq', vim.diagnostic.setqflist, opts)

    vim.keymap.set('n', '<leader>lr', '<cmd>LspRestart<CR>', opts)
    vim.keymap.set('n', '<leader>ll', '<cmd>LspLog<CR>', opts)
    vim.keymap.set('n', '<leader>li', '<cmd>LspInfo<CR>', opts)
    vim.api.nvim_set_option_value('omnifunc', 'v:lua.vim.lsp.omnifunc', { buf = ev.buf })
  end,
})

-- local function on_list(options)
--   vim.fn.setqflist({}, ' ', options)
--   vim.api.nvim_command('cfirst')
-- end

local function on_list(options)
  vim.fn.setloclist(0, {}, ' ', options)
  vim.api.nvim_command('lopen')
end

-- Example usage:
--
-- vim.lsp.buf.definition{on_list=on_list}
-- vim.lsp.buf.references(nil, {on_list=on_list})


-- require('nvim-treesitter.configs').setup {
--   ensure_installed = { "cpp", "vim", "python", "rust", "javascript", "css", "html", "json", "tsx", "lua" }, -- one of "all", "maintained" (parsers with maintainers), or a list of languages
--   -- ignore_install = { "lua" }, -- List of parsers to ignore installing
--   highlight = {
--     enable = true,              -- false will disable the whole extension
--     -- disable = { "c", "rust" },  -- list of language that will be disabled
--   },
--   indent = {
--     disable = { "python" },
--   }
-- }

vim.g.lsp_display_on = false

vim.diagnostic.config({
  virtual_text = false,
  underline = false,
})

_G.toggle_lsp_display = function() 
  vim.g.lsp_display_on = not vim.g.lsp_display_on

  vim.diagnostic.config({
    virtual_text = vim.g.lsp_display_on,
    underline = vim.g.lsp_display_on,
  })

  vim.api.nvim_echo({{'lsp display ' .. (vim.g.lsp_display_on and 'on' or 'off'), 'None'}}, false, {})
end

local map = vim.api.nvim_set_keymap
map('n', '<Leader>,', '<cmd>lua toggle_lsp_display()<CR>', {noremap = true})

require('lspfuzzy').setup {
  fzf_preview = {
    'right:+{2}-/2'
  },
}

vim.lsp.set_log_level("debug")
