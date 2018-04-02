if exists("g:loaded_rebuff") || &cp | finish | endif

let g:loaded_rebuff = 1

if exists('*rum#ignore')
  call rum#ignore('\[Rebuff\]')
endif

function! Rebuff()
  " Dependencies :(
  " Vim has no better way to deal with this at the moment.
  " Putting them here, instead of at the top, defers the
  " check until Rebuff is used, which maybe is a little more
  " annoying for users but makes the loading order for these
  " plugins not matter.
  if !exists("g:loaded_lodash")
    echo 'Rebuff requires vim-vigor. See https://github.com/tandrewnichols/vim-vigor.'
  endif

  if !exists("g:loaded_rum")
    echo 'Rebuff requires vim-rumrunner. See https://github.com/tandrewnichols/vim-rumrunner.'
  endif

  if !exists("g:loaded_projectroot")
    echo 'Rebuff requires vim-projectroot. See https://github.com/dbakker/vim-projectroot.'
  endif

  if !exists("g:loaded_lodash") || !exists("g:loaded_rum") || !exists("g:loaded_projectroot")
    return
  endif

  call rebuff#open()
endfunction

command! -nargs=0 Ls :call Rebuff()
command! -nargs=0 Rebuff :call Rebuff()

nnoremap <Plug>RebuffOpen :Rebuff<CR>

if !hasmapto('<Plug>RebuffOpen')
  nmap <leader>ls <Plug>RebuffOpen
endif
