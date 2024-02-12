set number
set expandtab

" Allow the cursor to move over everything, not just filled space.
set virtualedit=all

" Leader
let mapleader=","

" jj -> esc
inoremap jj <Esc>

" easier split nav
map <C-j> <C-w>j 
imap <C-j> <C-w>j 
map <C-k> <C-w>k
imap <C-k> <C-w>k
map <C-l> <C-w>l
imap <C-l> <C-w>l 
map <C-h> <C-w>h
imap <C-h> <C-w>h

" bindings for tabs
map <S-l> :tabn<CR>
map <C-]> :tabm +1<CR>
map <S-h> :tabp<CR>
map <C-[> :tabm -1<CR>

" save
nnoremap <leader>w :w<CR>

" easier tab closing
nnoremap <leader>x :q<CR>
nnoremap <leader>q :tabclose<CR>
nmap :tq :tabclose

" set spell when useful
au FileType gitcommit,gitrebase,ghmarkdown,markdown,text,md set spell

" Add recognized comment leaders
" Default value is s1:/*,mb:*,ex:*/,://,b:#,:%,:XCOMM,n:>,fb:-
autocmd FileType c,cpp setlocal comments -=:// comments+=b://! comments+=b://

" quickfix list nav
nnoremap <c-n> :cnext<CR>zz
nnoremap <c-p> :cprevious<CR>zz

" Automatically break on 88col when useful (grep: 80col)
autocmd FileType ghmarkdown,markdown,txt,md,org,tex set tw=87
autocmd FileType gitcommit,gitrebase set tw=72

" Case while searching
set ignorecase
set smartcase
set nowrapscan

set shortmess-=S

" Show 80 col
" 2020-08-21 Fri 12:17: now 88! whoa!
set colorcolumn=88

" Cool thin cursor in insert mode
set guicursor=n-v-c:block-Cursor/lCursor-blinkon0,i-ci:ver25-Cursor/lCursor,r-cr:hor20-Cursor/lCursor

function! MailSettings()
  set tw=72
  set colorcolumn=72
  set spell
endfunction

command! MailSettings :call MailSettings()
 
" date
nmap <leader>d i# <C-R>=strftime("%F %a %H:%M")<CR><Esc>
                
" strip whitespace
nnoremap <leader>s :let _s=@/<Bar>:%s/\s\+$//e<Bar>:let @/=_s<Bar><CR>
autocmd BufWritePre *.py,*.cpp,*.h :%s/\s\+$//e
