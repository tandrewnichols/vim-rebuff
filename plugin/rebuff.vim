if exists("g:rebuff_loaded") || &cp | finish | endif

let g:rebuff_loaded = 1

" Dependencies :(
" Vim has no better way to deal with this at the moment
if !exists("g:lodash_loaded")
  echo 'Rebuff requires vim-lodash. See https://github.com/tandrewnichols/vim-lodash.'
  finish
endif

if !exists("g:rum_loaded")
  echo 'Rebuff requires vim-rumrunner. See https://github.com/tandrewnichols/vim-rumrunner.'
  finish
endif

if !exists('g:rebuff')
  let g:rebuff = {}
endif

call rum#ignore('\[Rebuff\]')

function! Rebuff()
  call rebuff#open()
endfunction

command! -nargs=0 Ls :call Rebuff()
command! -nargs=0 Rebuff :call Rebuff()

nnoremap <Plug>RebuffOpen :Rebuff<CR>

if !hasmapto('<Plug>RebuffOpen')
  nmap <leader>ls <Plug>RebuffOpen
endif
