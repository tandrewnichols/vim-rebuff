if exists("g:rebuff.loaded") || &cp | finish | endif

if !exists('g:rebuff')
  let g:rebuff = {}
endif

let g:rebuff = extend(g:rebuff, { 'loaded': 1 })

function! Rebuff()
  call rebuff#open()
endfunction

command! -nargs=0 Ls :call Rebuff()
command! -nargs=0 Rebuff :call Rebuff()

nnoremap <Plug>RebuffOpen :Rebuff<CR>

if !hasmapto('<Plug>RebuffOpen')
  nmap <leader>ls <Plug>RebuffOpen
endif
