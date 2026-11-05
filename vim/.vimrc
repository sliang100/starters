colorscheme molokai
set background=dark
set nocompatible

" Basic settings
set softtabstop=2
set tabstop=2
set backspace=indent,eol,start
set expandtab
set shiftwidth=2
set showmatch
set mouse=a
set ruler
set showcmd
set smartcase
set statusline+=%f
set ls=2
set number
set linebreak
set formatoptions+=r
set guicursor=i:block
set cursorline

" Command-line completion
set wildmenu
set wildmode=list:longest
set wildignorecase

" Syntax and filetype support
syntax enable
filetype plugin indent on

" Mouse compatibility
if has('mouse_sgr')
  set ttymouse=sgr
elseif !has('nvim')
  set ttymouse=xterm2
endif

" Setup plugins
call plug#begin()

Plug 'tpope/vim-fugitive'
Plug 'pangloss/vim-javascript'
Plug 'maxmellon/vim-jsx-pretty'
Plug 'ntpeters/vim-better-whitespace'
Plug 'ervandew/supertab'
Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'
Plug 'wsdjeg/vim-fetch'
Plug 'dense-analysis/ale'
Plug 'vim-scripts/indentpython.vim'

" Certain plugins are Neovim only
if has('nvim')
  Plug 'nvim-lua/plenary.nvim'
  Plug 'nvim-telescope/telescope.nvim', { 'branch': '0.1.x' }
endif

" All plugins must be declared before this line
call plug#end()

" ALE configuration
let g:ale_linters_explicit = 1
let g:ale_linters = {
\ 'javascript': ['eslint'],
\ 'javascriptreact': ['eslint'],
\ 'python': ['flake8'],
\}

let g:ale_python_flake8_executable = 'python3'
let g:ale_javascript_eslint_executable = 'eslint_d'

" Airline
let g:airline_powerline_fonts = 1
let g:airline_theme = 'hybridline'

" tmux settings
if !empty($TMUX)
  set t_Co=256
  if !has('nvim')
    set term=screen-256color
  endif
endif

set termguicolors

" Highlighting
highlight CursorLineNr cterm=NONE ctermbg=NONE ctermfg=NONE guibg=NONE guifg=NONE

highlight link jsGlobalObjects Special
highlight link jsTemplateBraces Special
highlight link jsGlobalNodeObjects Keyword

" SuperTab
let g:SuperTabDefaultCompletionType = '<c-n>'

" Write files as root
command WS :execute ':silent w !sudo tee % > /dev/null' | :edit!

" ESLint autofix entire buffer
nnoremap <leader>ef mF:%!eslint_d --stdin --fix-to-stdout<CR>`F

" Telescope file search (Neovim only)
if has('nvim')
  nnoremap <leader>ff <cmd>Telescope find_files<cr>
endif

" Toggle highlighting with space
let g:highlighting = 0

function! Highlighting()
  if g:highlighting == 1 && @/ =~ '^\\<'.expand('<cword>').'\\>$'
    let g:highlighting = 0
    return ":silent nohlsearch\<CR>"
  endif

  let @/ = '\<'.expand('<cword>').'\>'
  let g:highlighting = 1
  return ":silent set hlsearch\<CR>"
endfunction

nnoremap <silent> <expr> <Space> Highlighting()