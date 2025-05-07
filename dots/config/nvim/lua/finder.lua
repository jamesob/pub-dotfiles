-- fzf
vim.env.FZF_DEFAULT_OPTS = '--bind ctrl-A:select-all'

vim.cmd([[
  command! -bang -nargs=? -complete=dir Files 
    \ call fzf#vim#files(<q-args>, fzf#vim#with_preview({'options': ['--layout=reverse', '--info=inline']}), <bang>0)
]])

-- EditConfig command
vim.cmd([[
  command! -bang EditConfig call fzf#run(fzf#wrap({ 'source': 'fd -d 2 -e vim -e lua . ~/.config/nvim ~/.vim/'}, <bang>0))
]])

local opts = { noremap = true, silent = true }
vim.keymap.set('n', '<leader>t', ':Files<CR>', opts)
vim.keymap.set('n', '<leader>T', ':Files ~/src<CR>', opts)
vim.keymap.set('n', '<leader>ob', ':Files ~/src/bitcoin/<CR>', opts)
vim.keymap.set('n', '<leader>os', ':Files ~/src/<CR>', opts)
vim.keymap.set('n', '<leader>.e', ':EditConfig<CR>', opts)
vim.keymap.set('n', '<leader>.r', ':Rg ~/.conig/nvim<CR>', opts)
vim.keymap.set('n', '<leader>e', ':Buffers<CR>', opts)
vim.keymap.set('n', '<leader>r', ':Rg<CR>', opts)

-- Function to build quickfix list
local function build_quickfix_list(lines)
  local qf_list = {}
  for _, line in ipairs(lines) do
    table.insert(qf_list, { filename = line })
  end
  vim.fn.setqflist(qf_list)
  vim.cmd('copen')
  vim.cmd('cc')
end

-- FZF actions configuration
vim.g.fzf_action = {
  ['ctrl-q'] = build_quickfix_list,
  ['ctrl-t'] = 'tab split',
  ['ctrl-x'] = 'split',
  ['ctrl-v'] = 'vsplit'
}
