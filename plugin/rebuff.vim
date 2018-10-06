if exists("g:loaded_rebuff") || &cp | finish | endif

let g:loaded_rebuff = 1

let g:rebuff_VERSION = '0.0.1'

call vigor#option#set('rebuff', {
  \  'show_unlisted': 0,
  \  'show_directories': 0,
  \  'show_hidden': 1,
  \  'show_help': 0,
  \  'show_top_content': 1,
  \  'default_sort_order': 'mru',
  \  'vertical_split': 1,
  \  'window_size': 80,
  \  'relative_to_project': 1,
  \  'show_help_entries': 0,
  \  'open_with_count': 1,
  \  'copy_absolute_path': 1,
  \  'incremental_filter': 1,
  \  'preserve_toggles': 0,
  \  'window_position': 'rightbelow',
  \  'preview': 1,
  \  'reset_timeout': 1,
  \  'debounce_preview': 150,
  \  'open_filter_single_file': 1
  \})

function! Rebuff()
  " Dependencies :(
  " Vim has no better way to deal with this at the moment.
  " Putting them here, instead of at the top, defers the
  " check until Rebuff is used, which maybe is a little more
  " annoying for users but makes the loading order for these
  " plugins not matter.
  let missing = vigor#plugin#requires('Rebuff', [
    \ 'https://github.com/tandrewnichols/vim-vigor',
    \ 'https://github.com/tandrewnichols/vim-rumrunner',
    \ 'https://github.com/dbakker/vim-projectroot'
    \ ])

  if missing
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
