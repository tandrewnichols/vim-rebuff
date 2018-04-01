function! rebuff#mappings#toggle(option) abort
  let b:toggles[ a:option ] = !b:toggles[ a:option ]
  call rebuff#render()
endfunction

function! rebuff#mappings#wrapSelect(fn, count, ...) abort
  let arg = a:0 == 1 ? a:1 : ''

  if !empty(a:count)
    call rebuff#mappings#findByNumber(a:count)
    if g:rebuff_open_with_count
      exec "call rebuff#mappings#" . a:fn
    else
      call rebuff#preview()
    endif
  else
    exec "call rebuff#mappings#" . a:fn
  endif
endfunction

function! rebuff#mappings#open(count) abort
  call rebuff#wrapQ()
  if !empty(a:count)
    exec "b" a:count
  endif
  normal! ze
endfunction

function! rebuff#mappings#findByNumber(count) abort
  call search('^[ +]\+' . a:count)
  normal! 0
endfunction

function! rebuff#mappings#bufferAction(cmd) abort
  " Get the buffer to delete
  let buf = rebuff#getBufferFromLine()

  " Then delete the line from the buffer list
  setlocal modifiable
  normal! "_dd
  setlocal nomodifiable

  call rebuff#mappings#removeBuffer(buf)

  " Then switch buffers so that the
  " buffer can be deleted
  call rebuff#preview()

  " Delete the buffer
  exec a:cmd . "!"  buf.num
endfunction

function! rebuff#mappings#removeBuffer(buf) abort
  let i = index(b:buffer_objects, a:buf)
  call remove(b:buffer_objects, i)
endfunction

let s:search_indicators = { 'name': '/', 'extension': '/.' }

let s:mod_codes = [22, 8, 20, 2]

function! rebuff#mappings#filterBy(prop, start) abort
  let indicator = s:search_indicators[ a:prop ]

  if a:start
    echo indicator
  endif

  if g:rebuff_incremental_filter
    if !exists("b:filter_text")
      let b:filter_text = ''
    endif

    try
      let code = getchar()
    catch
      let code = "\<Esc>"
    endtry

    let char = type(code) == 0 ? nr2char(code) : code

    if char == "\<Esc>"
      let b:filter_text = ""
      let b:current_filter = ""
      if !empty(b:matched_filter)
        call matchdelete(b:matched_filter)
      endif
      call rebuff#render()
    elseif char == "\<CR>" || index(s:mod_codes, code) > -1
      call rebuff#mappings#tryOpen(char, code)
    else
      if char == "\<BS>"
        if len(b:filter_text)
          let b:filter_text = b:filter_text[0:-2]
        endif
      else
        let b:filter_text .= escape(char, '/.~')
      endif

      let b:current_filter = 'v:val.' . a:prop . ' =~ ''' . b:filter_text . ''''
      call rebuff#render()

      if !empty(b:matched_filter)
        call matchdelete(b:matched_filter)
      endif
      let b:matched_filter = matchadd('Search', b:filter_text)

      redraw!
      echo indicator . b:filter_text
      call rebuff#mappings#filterBy(a:prop, 0)
    endif
  else
    let text = input(indicator)
    let b:current_filter = 'v:val.' . a:prop . ' =~ ''' . escape(text, '/.~') . ''''
    call rebuff#render()
  endif
endfunction

function! rebuff#mappings#tryOpen(char, code) abort
  let char = a:char
  let code = a:code
  let numlines = b:buffer_range[1] - b:buffer_range[0]

  let b:filter_text = ""
  if g:rebuff_open_filter_single_file && numlines == 1
    if char == "\<CR>"
      call rebuff#mappings#open(0)
    elseif code == 22
      call rebuff#mappings#openCurrentBufferIn('vsplit', 0)
    elseif code == 8
      call rebuff#mappings#openCurrentBufferIn('split', 0)
    elseif code == 20
      call rebuff#mappings#openCurrentBufferInTab(0)
    elseif code == 2
      call rebuff#mappings#openCurrentBufferInTab(0, 1)
    endif
  endif
endfunction

function! rebuff#mappings#copyPath() abort
  let currentBuffer = rebuff#getBufferFromLine()
  let text = currentBuffer.name
  if g:rebuff_copy_absolute_path
    let text = fnamemodify(currentBuffer.rawname, ":p")
  endif

  let @" = text
endfunction

function! rebuff#mappings#jumpToLine(line) abort
  exec a:line
  normal! 0
  call rebuff#preview()
endfunction

function! rebuff#mappings#setSortTo(type) abort
  let b:current_sort = a:type
  call rebuff#render()
endfunction

function! rebuff#mappings#moveTo(dir, count) abort
  let suffix = !empty(a:count) ? a:count . a:dir : a:dir
  exec "normal!" suffix

  " Debounce previewing for faster scrolling
  if g:rebuff_debounce_preview
    if exists("b:preview_timeout")
      call timer_stop(b:preview_timeout)
    endif

    let b:preview_timeout = timer_start(g:rebuff_debounce_preview, function('rebuff#mappings#callPreview'))
  else
    call rebuff#preview()
  endif
endfunction

function! rebuff#mappings#callPreview(...) abort
  if exists("b:preview_timeout")
    unlet b:preview_timeout
  endif
  call rebuff#preview()
endfunction

function! rebuff#mappings#pin(pinned) abort
  let entry = rebuff#getBufferFromLine()
  if !empty(entry.pinned)
    let entry.pinned = 0
    call remove(a:pinned, index(a:pinned, entry))
  else
    let entry.pinned = localtime()
    call add(a:pinned, entry)
  endif

  call rebuff#buildLogo()
  call rebuff#buildHelp()
  call rebuff#render()
endfunction

function! rebuff#mappings#restoreOriginalBuffer() abort
  call rebuff#openInOtherSplit(b:originBuffer)
endfunction

function! rebuff#mappings#reset() abort
  call rebuff#setBufferFlags()
  call rebuff#render(1)
endfunction

function! rebuff#mappings#openCurrentBufferInTab(count, ...) abort
  let curtab = tabpagenr()
  call rebuff#mappings#restoreOriginalBuffer()
  let target = empty(a:count) ? rebuff#getBufferFromLine().num : a:count

  call rebuff#wrapQ()
  exec "tabe" bufname(str2nr(target))

  if a:0 == 1
    exec "normal!" curtab . "gt"
  endif
endfunction

function! rebuff#mappings#openCurrentBufferIn(cmd, count) abort
  call rebuff#mappings#restoreOriginalBuffer()
  let num = empty(a:count) ? rebuff#getBufferFromLine().num : a:count
  call rebuff#wrapQ()
  exec a:cmd bufname(str2nr(num))
endfunction

let s:sort_methods = ['mru', 'num', 'name', 'extension', 'project']

function! rebuff#mappings#toggleSort() abort
  let nxt = index(s:sort_methods, b:current_sort) + 1
  if nxt == len(s:sort_methods)
    let b:current_sort = s:sort_methods[0]
  else
    let b:current_sort = s:sort_methods[nxt]
  endif

  call rebuff#render()
endfunction

function! rebuff#mappings#include(included) abort
  let buf = rebuff#getBufferFromLine()
  let buf.include = 1
  let index = index(a:included, buf.num)
  if index > -1
    call remove(a:included, index)
  else
    call add(a:included, buf.num)
  endif

  call rebuff#buildLogo()
  call rebuff#buildHelp()
  call rebuff#render()
endfunction

function! rebuff#mappings#jumpTo(char) abort
  call search(a:char)
  normal! 0
  call rebuff#preview()
endfunction

let s:char_map = {
  \   'C-b': "",
  \   'C-f': "",
  \   'C-d': "",
  \   'C-u': ""
  \ }

function! rebuff#mappings#runInPreview(char, count) abort
  let char = has_key(s:char_map, a:char) ? s:char_map[ a:char ] : a:char

  wincmd p
  if a:count
    exec "normal!" a:count . char
  else
    exec "normal!" char
  endif
  wincmd p
endfunction
