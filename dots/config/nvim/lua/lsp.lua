local lspconfig = require('lspconfig')
local LSP_DEBOUNCE = 400
-- Setup lspconfig.
local capabilities = require('cmp_nvim_lsp').default_capabilities()

vim.diagnostic.config({
  virtual_text = false,
  underline = false,
})
vim.keymap.set('n', '<leader>,', function()
  vim.diagnostic.config({
    virtual_text = not vim.diagnostic.config().virtual_text
  })
end, opts)


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
lspconfig.gopls.setup{}
lspconfig.golangci_lint_ls.setup{}

lspconfig.rust_analyzer.setup{
  capabilities = capabilities,
  flags = {
    debounce_text_changes = LSP_DEBOUNCE,
  },
}

lspconfig.eslint.setup{
}
