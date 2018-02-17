if exists("g:rebuff_loaded") || &cp | finish | endif

function! Rebuff()
  call rebuff#open()
endfunction

command! -nargs=0 Ls :call Rebuff()
command! -nargs=0 Rebuff :call Rebuff()

nnoremap <Plug>RebuffOpen :Rebuff<CR>

if !hasmapto('<Plug>RebuffOpen')
  nmap <leader>ls <Plug>RebuffOpen
endif
