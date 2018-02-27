let g:rebuff = extend(g:rebuff, {
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
      \}
      \, 'keep')


hi RebuffAccent cterm=bold ctermbg=none ctermfg=red
sign define rebuff_pin text=📌
sign define rebuff_eye text=👁️
let s:pinned = []
let s:included = []
let s:logo = [
      \  '   ___      __        ______',
      \  '  / _ \___ / /  __ __/ _/ _/',
      \  ' / , _/ -_) _ \/ // / _/ _/ ',
      \  '/_/|_|\__/_.__/\_,_/_//_/   '
      \]

let s:help_legend = [
      \ ['?',            'Toggle help.'],
      \ ['[count]<CR>',  'With count, jump to or open buffer number [count]. Without count, open buffer under cursor.'],
      \ ['-',            'Delete buffer under cursor.'],
      \ ['+',            'Show only modified files.'],
      \ ['.',            'Filter by file extension.'],
      \ ['/',            'Filter by arbitrary text.'],
      \ ['~',            'Show only files in this project.'],
      \ ['%',            'Open current buffer.'],
      \ ['#',            'Open alternate buffer.'],
      \ ['}',            'Jump to bottom of list.'],
      \ ['{',            'Jump to top of list.'],
      \ ['d',            'Toggle whether directories are shown.'],
      \ ['e',            'Sort by file extension.'],
      \ ['f',            'Sort by filename.'],
      \ ['h',            'Toggle whether hidden buffers are shown.'],
      \ ['H',            'Toggle help entries.'],
      \ ['i',            'Include this file in results, even if it normally wouldn''t be'],
      \ ['j | <Down>',   'Preview next buffer.'],
      \ ['k | <Up>',     'Preview previous buffer.'],
      \ ['M',            'Sort by MRU.'],
      \ ['n',            'Sort by buffer number.'],
      \ ['p',            'Pin entry to top.'],
      \ ['P',            'Sort by project.'],
      \ ['q | <Esc>',    'Close Rebuff and revert to original buffer.'],
      \ ['r',            'Reset original buffer list.'],
      \ ['R',            'Reverse current buffer listing.'],
      \ ['s',            'Open buffer under cursor in horizontal split.'],
      \ ['S',            'Toggle sort method.'],
      \ ['t',            'Open buffer under cursor in new tab.'],
      \ ['T',            'Open buffer under cursor in background tab.'],
      \ ['u',            'Toggle whether unlisted buffers are shown.'],
      \ ['v',            'Open buffer under cursor in vertical split.'],
      \ ['w',            'Wipeout buffer under cursor.'],
      \ ['x',            'Toggle top content.'],
      \ ['y',            'Copy path of buffer under cursor.']
      \]

function! rebuff#open()
  call rum#suspend()

  let originBuffer = bufnr("%")
  silent let rawBufs = rebuff#getBufferList()

  let size = g:rebuff.window_size

  if bufexists('[Rebuff]')
    let command = !empty(g:rebuff.vertical_split) ? 'vsplit' : 'split'
  else
    let command = !empty(g:rebuff.vertical_split) ? 'vnew' : 'new'
  endif

  call rebuff#createAugroup()

  if !empty(g:rebuff.window_position)
    exec g:rebuff.window_position "keepjumps hide" size . command "[Rebuff]"
  else
    exec "keepjumps hide" size . command "[Rebuff]"
  endif

  if g:rebuff.vertical_split
    wincmd L
    exec size . "wincmd |"
  else
    wincmd J
  endif

  let b:originBuffer = originBuffer
  call rebuff#buildLogo()
  call rebuff#buildHelp()

  let b:buffer_objects = rebuff#parseBufferList(rawBufs)
  let b:orig_buffers = copy(b:buffer_objects)

  call rebuff#setBufferFlags()

  let b:current_sort = g:rebuff.default_sort_order

  call rebuff#render()

  call rebuff#configureBuffer()
  call rebuff#highlight()
endfunction

function! rebuff#getBufferList()
  redir => bufoutput

  " Show all buffers including the unlisted ones.
  " [!] tells Vim to show the unlisted ones.
  buffers!
  redir END

  return split(bufoutput, '\n')
endfunction

function! rebuff#parseBufferList(bufs)
  let returnList = []

  for str in a:bufs
    let num = rebuff#extractBufNum(str)
    let flags = rebuff#extractFlags(str)
    let name = rebuff#extractFilename(str)

    let entry = { 'num': num, 'flags': flags, 'name': name }

    call rebuff#checkFilename(entry)
    call rebuff#checkFlags(entry)
    call add(returnList, entry)
  endfor

  return returnList
endfunction

function! rebuff#getRoot(name)
  if !g:rebuff.relative_to_project
    return ''
  endif

  try
    let root = projectroot#get(a:name)
    if root == $HOME
      return '~'
    else
      let parts = split(root, '/')
      if len(parts)
        return parts[-1]
      endif
    endif
  catch
    return ''
  endtry
endfunction

function! rebuff#checkFilename(entry)
  let entry = a:entry
  let root = rebuff#getRoot(entry.name)
  let name = entry.name

  let entry.help = match(name, '\/') == -1 && match(name, '\.txt') > -1 && empty(glob(name))

  if !entry.help
    let name = fnamemodify(entry.name, ':p')
  endif

  let entry.exists = !empty(glob(name))
  let isDir = isdirectory(name)

  let entry.incwd = name =~ getcwd()
  let entry.inproject = getcwd() =~ root && !entry.help

  if entry.help || root == '.' || root == ''
    let name = entry.name
  elseif entry.incwd
    let name = fnamemodify(entry.name, ":.")
  elseif entry.inproject && entry.name =~ '^\.\.'
    let name = entry.name
  elseif entry.inproject
    let name = rebuff#relativeTo(name, root)
  elseif !empty(root)
    let name = matchstr(name, root . '/.*$')
  endif

  if isDir
    let name .= '/'
  endif

  let entry.rawname = entry.name
  let entry.project = entry.help ? '' : root
  let entry.directory = isDir
  let entry.extension = fnamemodify(entry.name, ':e')

  let entry.name = name
  let entry.filename_length = len(entry.name)
endfunction

function! rebuff#relativeTo(name, where)
  let head = fnamemodify(getcwd(), ":h")
  let partial = substitute(head, '.*' . a:where, '', '')
  let base = '..' . split(a:name, a:where)[1]
  return substitute(partial, '\/[^\/]\+', '../', 'g') . base
endfunction

let s:flags = {
      \  'unlisted': 'u',
      \  'current': '%',
      \  'alternate': '#',
      \  'active': 'a',
      \  'hidden': 'h',
      \  'unmodifiable': '-',
      \  'readonly': '=',
      \  'running': 'R',
      \  'finished': 'F',
      \  'terminal': '[RF\?]',
      \  'modified': '+',
      \  'error': 'x'
      \}

function! rebuff#checkFlags(entry)
  let entry = a:entry
  let flags = entry.flags

  for key in keys(s:flags)
    let entry[ key ] = g:_.includes(flags, s:flags[key])
  endfor

  let found = g:_.find(s:pinned, { 'num': entry.num })
  let entry.pinned = type(found) != 0

  let included = index(s:included, entry.num)
  let entry.include = included > -1

  let entry.flags = flags
  let entry.flag_length = len(flags)
endfunction

function! rebuff#createAugroup()
  augroup RebuffEnter
    autocmd!
    autocmd BufEnter \[Rebuff\] call rebuff#setTimeout()
    autocmd BufWinEnter \[Rebuff\] call rebuff#setMappings()
    autocmd BufWinLeave \[Rebuff\] call rebuff#onExit()
    autocmd BufLeave \[Rebuff\] call rebuff#resetTimeout()
    autocmd BufWipeout \[Rebuff\] call rum#resume()
  augroup END
endfunction

function! rebuff#setBufferFlags()
  let b:current_sort = 'mru'
  let b:current_filter = ''
  let b:toggles = exists('s:toggles') ? s:toggles : {
        \  'help': g:rebuff.show_help,
        \  'help_entries': g:rebuff.show_help_entries,
        \  'top_content': g:rebuff.show_top_content,
        \  'unlisted': g:rebuff.show_unlisted,
        \  'directories': g:rebuff.show_directories,
        \  'hidden': g:rebuff.show_hidden,
        \  'in_project': 0,
        \  'modified_only': 0,
        \  'reverse': 0
        \}
  if exists('b:matched_filter') && !empty(b:matched_filter)
    try
      call matchdelete(b:matched_filter)
    catch
      " If for some reason the match doesn't exist
      " just ignore the error
    endtry
  endif
  let b:matched_filter = ''
endfunction

function! rebuff#configureBuffer()
  setlocal nonumber
  setlocal foldcolumn=0
  setlocal nofoldenable
  setlocal cursorline
  setlocal nospell
  setlocal nobuflisted
  setlocal filetype=rebuff
  setlocal buftype=nofile
  setlocal nomodifiable
  setlocal noswapfile
  setlocal nowrap
endfunction

function! s:Plug(name, cmd)
  exec "nnoremap <Plug>Rebuff" . a:name  a:cmd . "\<CR>"
endfunction

call s:Plug('ToggleHelpText', ":call rebuff#mappings#toggle('help')")
call s:Plug('Select', ":\<C-u>call rebuff#mappings#wrapSelect('open(v:count)', v:count)")
call s:Plug('DeleteBuffer', ":call rebuff#mappings#bufferAction('bd')")
call s:Plug('ToggleModified', ":call rebuff#mappings#toggle('modified_only')")
call s:Plug('FilterByExtension', ":call rebuff#mappings#filterBy('extension', 1)")
call s:Plug('FilterByText', ":call rebuff#mappings#filterBy('name', 1)")
call s:Plug('ToggleHelpEntries', ":call rebuff#mappings#toggle('help_entries')")
call s:Plug('ToggleInProject', ":call rebuff#mappings#toggle('in_project')")
call s:Plug('JumpToCurrent', ":call rebuff#mappings#jumpTo('%')")
call s:Plug('JumpToAlternate', ":call rebuff#mappings#jumpTo('#')")
call s:Plug('JumpToBottom', ":call rebuff#mappings#jumpToLine(b:buffer_range[1])")
call s:Plug('JumpToTop', ":call rebuff#mappings#jumpToLine(b:buffer_range[0])")
call s:Plug('ToggleDirectories', ":call rebuff#mappings#toggle('directories')")
call s:Plug('SortByExtension', ":call rebuff#mappings#setSortTo('extension')")
call s:Plug('SortByFilename', ":call rebuff#mappings#setSortTo('name')")
call s:Plug('ToggleHidden', ":call rebuff#mappings#toggle('hidden')")
call s:Plug('Include', ":call rebuff#mappings#include(rebuff#included())")
call s:Plug('MoveDown', ":\<C-u>call rebuff#mappings#moveTo('j', v:count)")
call s:Plug('MoveUp', ":\<C-u>call rebuff#mappings#moveTo('k', v:count)")
call s:Plug('SortByMRU', "call rebuff#mappings#setSortTo('mru')")
call s:Plug('MoveDownAlt', ":\<C-u>call rebuff#mappings#moveTo('j', v:count)")
call s:Plug('MoveUpAlt', ":\<C-u>call rebuff#mappings#moveTo('k', v:count)")
call s:Plug('SortByBufferNumber', ":call rebuff#mappings#setSortTo('num')")
call s:Plug('Pin', ":call rebuff#mappings#pin(rebuff#pins())")
call s:Plug('SortByProject', ":call rebuff#mappings#setSortTo('project')")
call s:Plug('RestoreOriginal', ":call rebuff#mappings#restoreOriginalBuffer()\<CR>:q")
call s:Plug('Escape', ":call rebuff#mappings#restoreOriginalBuffer()\<CR>:q")
call s:Plug('Reverse', ":call rebuff#mappings#toggle('reverse')")
call s:Plug('Reset', ":call rebuff#mappings#reset()")
call s:Plug('HorizontalSplit', ":\<C-u>call rebuff#mappings#wrapSelect('openCurrentBufferIn(''split'', v:count)', v:count)")
call s:Plug('ToggleSort', ":call rebuff#mappings#toggleSort()")
call s:Plug('OpenInTab', ":\<C-u>call rebuff#mappings#wrapSelect('openCurrentBufferInTab(v:count)', v:count)")
call s:Plug('OpenInBackgroundTab', ":\<C-u>call rebuff#mappings#wrapSelect('openCurrentBufferInTab(v:count, ''background'')', v:count)")
call s:Plug('ToggleUnlisted', ":call rebuff#mappings#toggle('unlisted')")
call s:Plug('VerticalSplit', ":\<C-u>call rebuff#mappings#wrapSelect('openCurrentBufferIn(''vsplit'', v:count)', v:count)")
call s:Plug('WipeoutBuffer', ":call rebuff#mappings#bufferAction('bw')")
call s:Plug('ToggleTop', ":call rebuff#mappings#toggle('top_content')")
call s:Plug('CopyPath', ":call rebuff#mappings#copyPath()")

function! rebuff#map(key, plug)
  let prefix = "<Plug>Rebuff"
  let plug = match(a:plug, prefix) > -1 ? a:plug : prefix . a:plug
  if !hasmapto(plug)
    exec "nmap <buffer> <silent> <nowait>" a:key plug
  endif
endfunction

function! rebuff#setMappings()
  call rebuff#map('?', 'ToggleHelpText')
  call rebuff#map("\<CR>", 'Select')
  call rebuff#map("\<Esc>", 'Escape')
  call rebuff#map('-', 'DeleteBuffer')
  call rebuff#map('+', 'ToggleModified')
  call rebuff#map('.', 'FilterByExtension')
  call rebuff#map('/', 'FilterByText')
  call rebuff#map('~', 'ToggleInProject')
  call rebuff#map('%', 'JumpToCurrent')
  call rebuff#map('#', 'JumpToAlternate')
  call rebuff#map('}', 'JumpToBottom')
  call rebuff#map('{', 'JumpToTop')
  call rebuff#map('d', 'ToggleDirectories')
  call rebuff#map('e', 'SortByExtension')
  call rebuff#map('f', 'SortByFilename')
  call rebuff#map('h', 'ToggleHidden')
  call rebuff#map('H', 'ToggleHelpEntries')
  call rebuff#map('i', 'Include')
  call rebuff#map('j', 'MoveDown')
  call rebuff#map('k', 'MoveUp')
  call rebuff#map('M', 'SortByMRU')
  call rebuff#map('n', 'SortByBufferNumber')
  call rebuff#map('p', 'Pin')
  call rebuff#map('P', 'SortByProject')
  call rebuff#map('q', 'RestoreOriginal')
  call rebuff#map('r', 'Reset')
  call rebuff#map('R', 'Reverse')
  call rebuff#map('s', 'HorizontalSplit')
  call rebuff#map('S', 'ToggleSort')
  call rebuff#map('t', 'OpenInTab')
  call rebuff#map('T', 'OpenInBackgroundTab')
  call rebuff#map('u', 'ToggleUnlisted')
  call rebuff#map('v', 'VerticalSplit')
  call rebuff#map('w', 'WipeoutBuffer')
  call rebuff#map('x', 'ToggleTop')
  call rebuff#map('y', 'CopyPath')
  call rebuff#map("\<Down>", 'MoveDownAlt')
  call rebuff#map("\<Up>", 'MoveUpAlt')
endfunction

function! rebuff#remap(...)
  let s:remap_args = a:000
  augroup RemapRebuff
    au!
    au BufWinEnter \[Rebuff\] for pair in s:remap_args | call rebuff#map(pair[0], pair[1]) | endfor
  augroup END
endfunction

function! rebuff#pins()
  return s:pinned
endfunction

function! rebuff#included()
  return s:included
endfunction

function! rebuff#onExit()
  if !empty(g:rebuff.preserve_toggles)
    let s:toggles = copy(b:toggles)
  endif

  call rebuff#resetTimeout()
endfunction

function! rebuff#resetTimeout()
  if !empty(g:rebuff.reset_timeout)
    let &timeoutlen = s:prev_timeout
  endif
endfunction

function! rebuff#setTimeout()
  if !empty(g:rebuff.reset_timeout)
    let s:prev_timeout = &timeoutlen
    let &timeoutlen = 0
 endif
endfunction

function! rebuff#preview()
  if !empty(g:rebuff.preview)
    let buf = rebuff#getBufferFromLine()
    if !empty(buf)
      call rebuff#openInOtherSplit(buf.num)
    endif
  endif
endfunction

function! rebuff#getBufferFromLine()
  let line = getline('.')
  if !empty(line) && line =~ '^[ +]\+\d\+ [u%#ah=RF?x+ -]\+ .\+$'
    let num = rebuff#extractBufNum(line)
    return rebuff#findBuffer('num', num)
  endif
endfunction

function! rebuff#findBuffer(key, val)
  for b in b:buffer_objects
    if b[ a:key ] == a:val
      return b
    endif
  endfor
endfunction

function! rebuff#openInOtherSplit(num)
  wincmd p
  exec "b" a:num
  normal! ze
  wincmd p
endfunction

let s:filters = {
      \ 'directories': '!v:val.directory',
      \ 'hidden': '!v:val.hidden',
      \ 'help_entries': '!v:val.help',
      \}

function! rebuff#filter()
  let list = copy(b:buffer_objects)
  let predicate = ['!v:val.pinned']

  if !b:toggles.unlisted
    if b:toggles.help_entries
      call add(predicate, '(!v:val.unlisted || v:val.help)')
    else
      call add(predicate, '!v:val.unlisted')
    endif
  endif

  if b:toggles.modified_only
    call add(predicate, 'v:val.modified')
  endif

  if b:toggles.in_project
    call add(predicate, 'v:val.inproject')
  endif

  for k in keys(s:filters)
    if !b:toggles[ k ]
      call add(predicate, s:filters[ k ])
    endif
  endfor

  if !empty(b:current_filter)
    call add(predicate, b:current_filter)
  endif

  return filter(list, 'v:val.include || (' . join(predicate, ' && ') . ')')
endfunction

function! rebuff#render(...)
  " Save off the current cursor position
  let currentBuffer = rebuff#getBufferFromLine()

  setlocal modifiable

  " Clear the whole buffer
  normal! gg"_dG

  " Render the top content unless it's being hidden
  if b:toggles.top_content
    call setline(1, b:logo)
  endif

  call append('$', [rebuff#buildInfoLine(), '', ''])
  let s:sort_match = matchadd('RebuffAccent', 'Sort: \zs[a-z]\+\ze')
  let s:toggled_on_match = matchadd('RebuffAccent', ': \zs1\ze')

  let pins = rebuff#getPins()
  call rebuff#renderLines(pins)

  " Render help unless it's being hidden
  if b:toggles.help
    call append('$', b:help_text)
  endif

  setlocal nomodifiable

  if a:0 == 1 && a:1 == 1
    call search('%')
    normal! 0
  else
    call rebuff#setCursorPosition(currentBuffer)
  endif

  " And preview the current line
  call rebuff#preview()
endfunction

function! rebuff#getPins()
  let pinned = filter(copy(b:buffer_objects), 'v:val.pinned')
  if len(pinned)
    let pinned = g:_.sortBy(pinned, 'pinned')
    let pinnedLines = g:_.map(pinned, function('s:ConstructEntry'))
    return pinnedLines
  endif
endfunction

function! rebuff#renderLines(pins)
  let list = rebuff#filter()
  if len(list)
    if b:current_sort == 'mru'
      let list = rebuff#sortByMRU(list)
    else
      let list = g:_.sortBy(list, b:current_sort)
    endif
  endif
  let lines = g:_.map(list, function('s:ConstructEntry'))

  if b:toggles.reverse
    call reverse(lines)
  endif

  " Render the current list
  exec "sign unplace * buffer=" . bufnr('\[Rebuff\]')
  if !empty(a:pins)
    let lines = a:pins + lines
  endif
  call setline('$', lines)

  call rebuff#setBufferRange(lines)

  if !empty(a:pins)
    call rebuff#renderPins(a:pins)
  endif

  if !empty(s:included)
    call rebuff#renderIncludes()
  endif
endfunction

function! rebuff#renderPins(pins)
  let start = b:buffer_range[0]
  for pin in a:pins
    exec "sign place" start "line=" . start "name=rebuff_pin file=" . expand("%:p")
    let start += 1
  endfor
endfunction

function! rebuff#renderIncludes()
  let pos = getpos('.')
  for include in s:included
    call search('^[ +]*' . include, 'sw')
    let line = getpos('.')[1]
    exec "sign place" line "line=" . line "name=rebuff_eye file=" . expand("%:p")
  endfor

  call setpos('.', pos)
endfunction

function! rebuff#setBufferRange(lines)
  let start = b:toggles.top_content ? len(b:logo) + 3 : 3
  let end = start + len(a:lines)
  let b:buffer_range = [start, end]
endfunction

function! rebuff#setCursorPosition(currentBuffer)
  " Try to position onto the same buffer as before
  if empty(a:currentBuffer) || !search('^[ +]*' . string(a:currentBuffer.num))
    " If that fails, position on the current buffer
    if !search('%')
      " And then if that fails (e.g. when filtering) just
      " use the first line in the buffer range
      call setpos('.', [bufnr('%'), b:buffer_range[0], 0, 0])
    endif
  endif
  
  " Make sure we're at the beginning of the line
  normal! 0
endfunction

function! s:ConstructEntry(i, entry)
  let entry = a:entry
  let line = '  '
  let line .= entry.modified ? '+ ' : '  '
  let line .= g:_.padStart(entry.num, 3)
  let line .= ' '
  let line .= g:_.padStart(entry.flags, 5)
  let line .= ' '
  let line .= entry.name
  return line
endfunction

function! rebuff#highlight()
  if has("syntax")
    " Top content definitions
    syn match rebuffBorder     "^-\+$"
    syn match rebuffLogo       "^|\zs.\+\ze|$" contained
    syn region rebuffSide      start="|" end="|" contains=rebuffLogo


    " Buffer listing definitions
    syn match rebuffModified   "+"
    syn match rebuffBufNumber  "[^:]\s\d\+\s"
    syn match rebuffCurrent    "%.\+$"
    syn match rebuffNonCurrent "[# ][ah].\+$"
    syn match rebuffUnlisted   "u[# ][ah ].\+$"

    " Help content definitions
    syn match rebuffHelpBorder "^=\+ HELP =\+$"
    syn match rebuffDesc       " [A-Z][Ra-z ]\+\."

    let shortcuts = escape(join(map(copy(s:help_legend), 'v:val[0]'), '\|'), '[]/.~')
    exec 'syn match rebuffShortcut   "^ \(' . shortcuts . '\)"'

    " Top content highlighting
    hi def link rebuffBorder     Keyword
    hi def link rebuffSide       Keyword
    hi def link rebuffLogo       Include

    " Buffer linsting highlighting
    hi def link rebuffModified   String
    hi def link rebuffCurrent    Function
    hi def link rebuffBufNumber  Identifier
    hi def link rebuffNonCurrent Constant
    hi def link rebuffUnlisted   Type

    " Help content highlighting
    hi def link rebuffHelpBorder Keyword
    hi def link rebuffDesc       NONE
    hi def link rebuffShortcut   Include
  endif
endfunction

function! rebuff#extractFilename(entry)
  return matchstr(a:entry, '^ *\d\+[^"]\+"\zs[^"]\+\ze"')
endfunction

function! rebuff#extractFlags(entry)
  return matchstr(a:entry, '^ *\d\+\zs[^"]\+\ze"')
endfunction

function! rebuff#extractBufNum(entry)
  return matchstr(a:entry, '^[ +]*\zs\d\+\ze')
endfunction

function! rebuff#getSize()
  let size = g:rebuff.window_size
  if len(s:pinned) || len(s:included)
    let size -= 2
  endif

  return size
endfunction

function! rebuff#buildLogo()
  let size = rebuff#getSize()

  let isEven = fmod(size, 2) == 0.0
  let left = float2nr(floor((size - 30) / 2))
  let right = isEven ? left : left + 1

  let lines = [ repeat('-', size) ]
  for line in s:logo
    call add(lines, '|' . repeat(' ', left) . line . repeat(' ', right) . '|')
  endfor

  call add(lines, '|' . repeat(' ', size - 2) . '|')
  call add(lines, repeat('-', size))

  let b:logo = lines
endfunction

function! rebuff#buildHelp()
  let size = rebuff#getSize()

  let isEven = fmod(size, 2) == 0.0
  let left = float2nr(floor((size - 6) / 2))
  let right = isEven ? left : left + 1

  let header = repeat('=', left) . ' HELP ' . repeat('=', right)
  let lines = [ '', '', header ]

  for entry in s:help_legend
    let help_key = ' ' . g:_.padEnd(entry[0], 15)
    let desc = entry[1]

    let remainder = size - len(help_key)

    if len(desc) > remainder
      let idx = stridx(desc, ' ')
      let prev_idx = 0
      while len(desc[0:idx]) < remainder
        let prev_idx = idx
        let idx = stridx(desc, ' ', idx + 1)
      endwhile
      let first = desc[0:prev_idx]
      let second = repeat(' ', 15) . desc[prev_idx:]
      call add(lines, help_key . first)
      call add(lines, second)
    else
      call add(lines, help_key . desc)
    endif
  endfor

  let b:help_text = lines
endfunction

function! rebuff#buildInfoLine()
  let size = rebuff#getSize() - 1
  let line = [
        \ 'Dirs: ' . b:toggles.directories,
        \ 'Hidden: ' . b:toggles.hidden,
        \ 'Unlisted: ' . b:toggles.unlisted,
        \ 'Mod: ' . b:toggles.modified_only,
        \ 'Help: ' . b:toggles.help_entries,
        \ 'Proj: ' . b:toggles.in_project,
        \ 'Sort: ' . b:current_sort
        \]
  return g:_.padStart(join(line, ' '), size)
endfunction

function! rebuff#sortByMRU(list)
  let list = copy(a:list)
  let mru = rum#get()

  function! s:MRUIteree(memo, item, ...) closure
    let memo = a:memo
    let match = g:_.find(list, { 'num': a:item.num })
    if type(match) == 4
      call add(memo, match)
    endif
    return memo
  endfunction

  let newlist = g:_.reduce(mru, function('s:MRUIteree'), [])
  for item in list
    if index(newlist, item) == -1
      call add(newlist, item)
    endif
  endfor

  return newlist
endfunction
