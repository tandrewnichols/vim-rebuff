function! rebuff#mappings#toggle(option)
  let b:toggles[ a:option ] = !b:toggles[ a:option ]
  call rebuff#render()
endfunction

function! rebuff#mappings#handleEnter(count)
  if !empty(a:count)
    if g:rebuff.open_with_count
      bw
      exec "b" a:count
      normal! ze
    else
      call rebuff#mappings#findByNumber(a:count)
      call rebuff#preview()
    endif
  else
    bw
    normal! ze
  endif
endfunction

function! rebuff#mappings#findByNumber(count)
  call search('^[ +]\+' . a:count)
  normal! 0
endfunction

function! rebuff#mappings#bufferAction(cmd)
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
  exec a:cmd buf.num
endfunction

function! rebuff#mappings#removeBuffer(buf)
  let i = index(b:buffer_objects, a:buf)
  call remove(b:buffer_objects, i)
endfunction

let s:search_indicators = { 'name': '/', 'extension': '/.' }

function! rebuff#mappings#filterBy(prop, start)
  let indicator = s:search_indicators[ a:prop ]

  if a:start
    echo indicator
  endif

  if g:rebuff.incremental_filter
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
    elseif char == "\<CR>"
      let b:filter_text = ""
    else
      if char == "\<BS>"
        let b:filter_text = b:filter_text[0:-2]
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

function! rebuff#mappings#copyPath()
  let currentBuffer = rebuff#getBufferFromLine()
  let text = currentBuffer.name
  if g:rebuff.copy_absolute_path
    let text = fnamemodify(currentBuffer.rawname, ":p")
  endif

  let @" = text
endfunction

function! rebuff#mappings#jumpTo(line)
  exec a:line
  normal! 0
  call rebuff#preview()
endfunction

function! rebuff#mappings#setSortTo(type)
  let b:current_sort = a:type
  call rebuff#render()
endfunction

function! rebuff#mappings#moveTo(dir, count)
  let suffix = !empty(a:count) ? a:count . a:dir : a:dir
  exec "normal!" suffix

  " Debounce previewing for faster scrolling
  if g:rebuff.debounce_preview
    if exists("b:preview_timeout")
      call timer_stop(b:preview_timeout)
    endif

    let b:preview_timeout = timer_start(g:rebuff.debounce_preview, function('rebuff#mappings#callPreview'))
  else
    call rebuff#preview()
  endif
endfunction

function! rebuff#mappings#callPreview(...)
  if exists("b:preview_timeout")
    unlet b:preview_timeout
  endif
  call rebuff#preview()
endfunction

function! rebuff#mappings#pin(pinned)
  let entry = rebuff#getBufferFromLine()
  if !empty(entry.pinned)
    let entry.pinned = 0
    call remove(a:pinned, index(a:pinned, entry))
    call rebuff#mappings#rebuildLogo(0, a:pinned)
    call rebuff#mappings#rebuildHelp(0, a:pinned)
  else
    call rebuff#mappings#rebuildLogo(-2, a:pinned)
    call rebuff#mappings#rebuildHelp(-2, a:pinned)
    let entry.pinned = localtime()
    call add(a:pinned, entry)
  endif
  call rebuff#render()
endfunction

function! rebuff#mappings#rebuildLogo(num, pinned)
  if !len(a:pinned)
    let b:logo = rebuff#buildLogo(g:rebuff.window_size + a:num)
  endif
endfunction

function! rebuff#mappings#rebuildHelp(num)
  if !len(a:pinned)
    let b:help_text = rebuff#buildHelp(g:rebuff.window_size + a:num)
  endif
endfunction

function! rebuff#mappings#restoreOriginalBuffer()
  call rebuff#openInOtherSplit(b:originBuffer)
endfunction

function! rebuff#mappings#reset()
  call rebuff#setBufferFlags()
  call rebuff#render(1)
endfunction

function! rebuff#mappings#openCurrentBufferInTab(...)
  let curtab = tabpagenr()
  call rebuff#mappings#restoreOriginalBuffer()
  let target = rebuff#getBufferFromLine()

  bw
  tabnew
  let current = bufnr('%')
  exec "b" target.num
  " Cleanup the unnamed buffer created by tabnew
  exec "bw" current

  if a:0 == 1
    exec "normal!" curtab . "gt"
  endif
endfunction

function! rebuff#mappings#openCurrentBufferIn(cmd)
  call rebuff#mappings#restoreOriginalBuffer()
  let buf = rebuff#getBufferFromLine()
  q
  exec a:cmd buf.num
endfunction

let s:sort_methods = ['num', 'name', 'extension', 'root', 'mru']

function! rebuff#mappings#toggleSort()
  let nxt = index(s:sort_methods, b:current_sort) + 1
  if nxt == len(s:sort_methods)
    let b:current_sort = s:sort_methods[0]
  else
    let b:current_sort = s:sort_methods[nxt]
  endif

  call rebuff#render()
endfunction
