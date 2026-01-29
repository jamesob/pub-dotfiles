local LSP_DEBOUNCE = 400
local capabilities = require('cmp_nvim_lsp').default_capabilities()


vim.lsp.config('clangd', {
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
)

vim.lsp.enable('clangd')

-- vim.lsp.config('pylsp', {
--   capabilities = capabilities,
--   flags = {
--     debounce_text_changes = LSP_DEBOUNCE,
--   },
--   settings = {
--     pylsp = {
--       plugins = {
--         ruff = {
--           enabled = true,
--         },
--         autopep8 = {
--           enabled = false,
--         },
--         yapf = {
--           enabled = true,
--           args = '--style={based_on_style: yapf, indent_width: 4}'
--         },
--       },
--     },
--   };
-- })
-- vim.lsp.enable('pylsp')

vim.lsp.config('gopls', {})
vim.lsp.enable('gopls')

vim.lsp.config('ty', {})
vim.lsp.enable('ty')

vim.lsp.config('ruff', {})
vim.lsp.enable('ruff')

vim.lsp.config('zls', {})
vim.lsp.enable('zls')

vim.lsp.config('rust_analyzer', {
  capabilities = capabilities,
  flags = {
    debounce_text_changes = LSP_DEBOUNCE,
  },
})
vim.lsp.enable('rust_analyzer')

vim.lsp.config('eslint', {})
vim.lsp.enable('eslint')
