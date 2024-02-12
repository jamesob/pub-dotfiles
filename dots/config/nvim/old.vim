set noswapfile
set backup
set writebackup
set backupcopy=yes
set undofile
set undodir=~/.nvim/undo//
set backupdir=~/.nvim/backup//
set directory=~/.nvim/swp//

set shiftwidth=2
" Search the pwd for a project-specific config file.
set exrc
set wildmenu
set wildmode=longest:list,full
set secure

set diffopt+=internal,algorithm:patience

set foldmethod=indent       " automatically fold by indent level
set nofoldenable            " ... but have folds open by default

" auto-install vim-plug
"
" Use :PlugInstall to load plugins.
"
if empty(glob('~/.config/nvim/autoload/plug.vim'))
  silent !curl -fLo ~/.config/nvim/autoload/plug.vim --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
  autocmd VimEnter * PlugInstall
endif
call plug#begin('~/.config/nvim/plugged')

Plug 'Vimjas/vim-python-pep8-indent'
Plug 'neovim/nvim-lspconfig'
" Plug 'ray-x/lsp_signature.nvim'
Plug 'weilbith/nvim-code-action-menu'
  nnoremap <leader>ca <cmd>CodeActionMenu<CR>
Plug 'kyazdani42/nvim-web-devicons'
Plug 'sindrets/diffview.nvim', { 'commit': '520bb5c34dd24e70fc063d28bd6d0e8181bff118' }

Plug 'nvim-lua/plenary.nvim'
Plug 'folke/which-key.nvim'

Plug 'preservim/nerdtree'
  map ] :NERDTreeToggle<CR>
  let NERDTreeIgnore=['\.o$', '\.o.tmp$', '\.a$']

Plug 'mileszs/ack.vim'
  let g:ackprg = 'rg --vimgrep'
  nnoremap <leader>a :tabnew<CR>:Ack 
  nnoremap <leader>gc <cmd>Ack '<<<<<'<CR>
       
Plug 'AndrewRadev/splitjoin.vim'
Plug 'tpope/vim-rsi'
Plug 'tpope/vim-surround'
Plug 'tpope/vim-rhubarb'
Plug 'tpope/vim-fugitive'
  nnoremap <leader>gs <cmd>Git<cr>

Plug 'junegunn/gv.vim'
Plug 'tpope/vim-sleuth'
Plug 'tpope/vim-commentary'
Plug 'tpope/vim-unimpaired'
Plug 'godlygeek/tabular'
Plug 'tpope/vim-markdown'
  let g:markdown_fenced_languages = ['html', 'python', 'bash=sh', 'sql', 'cpp', 'javascript', 'js=javascript', 'ts=typescript', 'yaml', 'json']
Plug 'craigemery/vim-autotag'
Plug 'majutsushi/tagbar'
  nnoremap <leader>b :TagbarToggle<CR>
  let g:tagbar_width = 60

Plug 'romainl/vim-qf'

Plug 'christoomey/vim-tmux-navigator', { 'commit': '6a1e58c3ca3bc7acca36c90521b3dfae83b2a602' }

Plug 'nvim-treesitter/nvim-treesitter', {'do': ':TSUpdate'}
Plug 'chikamichi/mediawiki.vim', { 'commit': '26e5737264354be41cb11d16d48132779795e168' }

" Python plugs
" Plug 'hynek/vim-python-pep8-indent'
" Plug 'Glench/Vim-Jinja2-Syntax'

Plug 'mboughaba/i3config.vim'

" Go plugs
" Plug 'fatih/vim-go', { 'do': ':GoUpdateBinaries' }

" JS/Typescript plugs
" Plug 'peitalin/vim-jsx-typescript'
" Plug 'leafgarland/typescript-vim'
" Plug 'pangloss/vim-javascript' | Plug 'mxw/vim-jsx'
" Plug 'othree/jspc.vim', { 'for': ['javascript', 'javascript.jsx'] }
Plug 'maxmellon/vim-jsx-pretty'

" Status line
" N.B. requires install of fonts: https://github.com/powerline/fonts
" Plug 'vim-airline/vim-airline'
" Plug 'vim-airline/vim-airline-themes'

" Colors
Plug 'jnurmine/Zenburn'
Plug 'noahfrederick/vim-hemisu'
" Plug 'AlessandroYorba/Alduin'
" Plug 'tlhr/anderson.vim'
Plug 'junegunn/seoul256.vim'
" Plug 'endel/vim-github-colorscheme'
" Plug 'nelstrom/vim-mac-classic-theme'
" Plug 'ajgrf/sprinkles'
Plug 'felixhummel/setcolors.vim'
" Plug 'flazz/vim-colorschemes'
Plug 'tjdevries/colorbuddy.vim'
Plug 'Th3Whit3Wolf/onebuddy'

" highlight.vim
"
" Line mode
"    <C-h><C-h>   Highlight current line
"    <C-h><C-a>   Advance color for next line highlight
"    <C-h><C-r>   Clear last line highlight
"
"  Pattern mode
"    <C-h><C-w>   Highlight word under cursor (whole word match)
"    <C-h><C-l>    Highlight all lines having word under cursor (whole word match)
"    <C-h><C-f>    Highlight word under cursor (partial word match)
"    <C-h><C-k>   Highlight all lines having word under cursor (partial word match)
"    <C-h><C-s>   Highlight last search pattern
"    <C-h><C-j>    Highlight all lines having last search pattern
"    <C-h><C-d>   Clear last pattern highlight
"
"    <C-h><C-n>   Clear all highlights
"
"  All above commands work in both normal & insert modes.
"  <C-h><C-h> also works in visual mode. (Select desired lines & hit <C-h><C-h>)
"
Plug 'vim-scripts/highlight.vim'
 
" Plug 'autozimu/LanguageClient-neovim', {
"     \ 'branch': 'next',
"     \ 'do': 'bash install.sh',
"     \ }
 
" Fuzzyfinding
Plug 'junegunn/fzf'
Plug 'junegunn/fzf.vim'
  command! -bang -nargs=? -complete=dir Files
    \ call fzf#vim#files(<q-args>, fzf#vim#with_preview({'options': ['--layout=reverse', '--info=inline']}), <bang>0)
  command! -bang -nargs=* Rg
    \ call fzf#vim#grep(
    \   'rg --column --line-number --no-heading --color=always --smart-case -- '.shellescape(<q-args>), 1,
    \   fzf#vim#with_preview(), <bang>0)
  nnoremap <leader>t :Files<CR>
  nnoremap <leader>T :Files ~<CR>
  nnoremap <leader>ob :Files ~/src/bitcoin/<CR>
  nnoremap <leader>os :Files ~/src/<CR>
  command! -bang EditConfig call fzf#run(fzf#wrap({ 'source': 'fd . ~/.config/nvim ~/.vim/ --maxdepth 1 --extension vim --extension lua'}, <bang>0))
  nnoremap <leader>.e :EditConfig<CR>
  nnoremap <leader>e :Buffers<CR>
  nnoremap <leader>r :Rg<CR>
  let g:fzf_action = {
    \ 'ctrl-t': 'tab split',
    \ 'ctrl-x': 'split',
    \ 'ctrl-v': 'vsplit' }
  let $FZF_DEFAULT_COMMAND = "rg --files --follow --no-ignore-vcs --hidden -g '!.mypy_cache/' -g '!.cache/' -g '!.git/' -g '!.pytest_cache/' -g '!**/.*.egg-info/' -g '!*.pyc'"

     
" Plug 'psf/black'
" nnoremap <leader>pb <cmd>Black<CR>

Plug 'neovim/nvim-lspconfig'
Plug 'ojroques/nvim-lspfuzzy'

" Completion

Plug 'hrsh7th/cmp-nvim-lsp'
Plug 'hrsh7th/cmp-buffer'
Plug 'hrsh7th/cmp-path'
Plug 'hrsh7th/nvim-cmp'

" Open all snips with :VsnipOpen
Plug 'hrsh7th/cmp-vsnip'
Plug 'hrsh7th/vim-vsnip'
Plug 'hrsh7th/vim-vsnip-integ'

" Plug 'ervandew/supertab'
" Plug 'Shougo/deoplete.nvim', { 'do': ':UpdateRemotePlugins' }
" Plug 'ycm-core/YouCompleteMe', { 'do': './install.py' }

Plug 'rhysd/vim-clang-format'

Plug 'leafgarland/typescript-vim'

call plug#end()
 
" let g:seoul256_srgb = 1
" let g:seoul256_background = 237
" set background=light

set termguicolors
colorscheme seoul256
  
" check one time after 4s of inactivity in normal mode
set autoread
au CursorHold * checktime

" Remove trailing whitespace on file saves.
" autocmd BufWritePre * :%s/\s\+$//e

" Remove trailing whitespace lines from end of file
autocmd BufWritePre * :%s/\($\n\s*\)\+\%$//e

nnoremap <leader><Space> gqap

" unset spell when annoying
autocmd FileType go set nospell

" Various formatoptions settings for working with comments.
au FileType * set fo+=r fo+=o fo+=q fo+=c fo+=

" Folding cheet sheet
" zR    open all folds
" zM    close all folds
" za    toggle fold at cursor position
" zj    move down to start of next fold
" zk    move up to end of previous fold
" set foldmethod=indent

nnoremap <silent> <leader>+ :exe "resize " . (winheight(0) * 3/2)<CR>
nnoremap <silent> <leader>- :exe "resize " . (winheight(0) * 2/3)<CR>

" Indent
map <Space> ==

" # nvimrc editing
nnoremap <silent> <leader>.p :exe "PlugInstall"<CR>
nnoremap <silent> <leader>.l :exe "source ~/.config/nvim/init.lua"<CR>
nnoremap <silent> <leader>.d :exe "edit ~/dotfiles/ctrl"<CR>

function! s:statusline_expr()
  let mod = "%{&modified ? '[+] ' : !&modifiable ? '[x] ' : ''}"
  let ro  = "%{&readonly ? '[RO] ' : ''}"
  let ft  = "%{len(&filetype) ? '['.&filetype.'] ' : ''}"
  let fug = "%{exists('g:loaded_fugitive') ? fugitive#statusline() : ''}"
  let sep = ' %= '
  let pos = ' %-12(%l : %c%V%) '
  let pct = ' %P'

  return '[%n] %F %<'.mod.ro.ft.fug.sep.pos.'%*'.pct
endfunction
let &statusline = s:statusline_expr()

hi DiffAdd guifg=NONE guibg=#4b5632

" TODO jamesob: is this right?
set completeopt=menu,menuone,noselect
