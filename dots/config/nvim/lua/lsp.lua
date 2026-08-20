local LSP_DEBOUNCE = 400
local capabilities = require('cmp_nvim_lsp').default_capabilities()


vim.lsp.config['clangd'] = {
  capabilities = capabilities,
  filetypes = { 'c', 'cpp', 'objc', 'objcpp', 'cuda', 'proto' },
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
vim.lsp.enable('clangd')

vim.lsp.config['gopls'] = {
  capabilities = capabilities,
  cmd = { 'gopls' },
  filetypes = { 'go', 'gomod', 'gowork', 'gotmpl' },
  flags = {
    debounce_text_changes = LSP_DEBOUNCE,
  },
  settings = {
    gopls = {
      analyses = {
        unusedparams = true,
        shadow = true,
      },
      staticcheck = true,
      gofumpt = true,
    },
  },
}
vim.lsp.enable('gopls')

vim.lsp.config['ty'] = { cmd = { 'ty', 'server' } }
vim.lsp.enable('ty')

vim.lsp.config['ruff'] = { cmd = { 'ruff', 'server' } }
vim.lsp.enable('ruff')
