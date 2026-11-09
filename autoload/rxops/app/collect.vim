" Collect what the last search matches, without changing the buffer.
" An empty pattern in :g / :s means the last search, with the same case and
" magic state as :g// (so @/ is never rebuilt from a string). Internal
" commands run under :keeppatterns (no search history, and the last
" substitute pattern and string stay the user's).

function! s:ok(count, extra) abort
  return extend({'ok': v:true, 'code': '', 'error': '', 'count': a:count, 'changed': v:false}, a:extra)
endfunction

function! rxops#app#collect#err(code, msg) abort
  return {'ok': v:false, 'code': a:code, 'error': a:msg, 'count': 0, 'changed': v:false}
endfunction

" 'gdefault' and 'edcompatible' change what the flags of :s mean: turn them
" off around internal :s commands. Returns what to give options_restore().
function! rxops#app#collect#options_off() abort
  let l:saved = {'gdefault': &gdefault}
  set nogdefault
  if exists('+edcompatible')
    let l:saved.edcompatible = &edcompatible
    set noedcompatible
  endif
  return l:saved
endfunction

" Both options are global. (:let &g:{name} is no valid syntax: E18.)
function! rxops#app#collect#options_restore(saved) abort
  for l:name in keys(a:saved)
    execute 'let &g:' . l:name . ' = a:saved[l:name]'
  endfor
endfunction

" '' '[ '] move with :g and :s even when the cursor is put back.
function! rxops#app#collect#marks_save() abort
  return map(["''", "'[", "']"], '[v:val, getpos(v:val)]')
endfunction

function! rxops#app#collect#marks_restore(saved) abort
  for [l:mark, l:pos] in a:saved
    if l:pos[1] > 0 && l:pos[1] <= line('$')
      call setpos(l:mark, l:pos)
    endif
  endfor
endfunction

" A closed fold widens a range of two addresses to the whole fold: turn
" folding off in this window while an internal ranged command runs. Manual
" folds and their open / closed state stay. Returns what fold_restore()
" takes.
function! rxops#app#collect#fold_off() abort
  let l:saved = [win_getid(), &l:foldenable]
  setlocal nofoldenable
  return l:saved
endfunction

function! rxops#app#collect#fold_restore(saved) abort
  if !empty(a:saved)
    call setwinvar(a:saved[0], '&foldenable', a:saved[1])
  endif
endfunction

" Join the matches, each a List of lines from submatch(0, 1), into one List
" of lines. A NUL inside a line ("\n" in a String) stays in its line.
function! rxops#app#collect#flatten(items) abort
  let l:out = []
  for l:item in a:items
    call extend(l:out, l:item)
  endfor
  return l:out
endfunction

" Last line that a match starting in {lnum} touches. {lines} is the match
" as submatch(0, 1) gives it; a match that ends in a line break ends with
" an empty item, and that break does not reach the next line's text.
function! rxops#app#collect#last_line(lnum, lines) abort
  return a:lnum + len(a:lines) - 1 - (len(a:lines) > 1 && a:lines[-1] ==# '' ? 1 : 0)
endfunction

" Text of the lines in {l1},{l2} that match (or do not match, {invert}).
function! rxops#app#collect#lines(l1, l2, invert) abort
  let l:acc = []
  let l:view = winsaveview()
  let l:marks = rxops#app#collect#marks_save()
  let l:fold = rxops#app#collect#fold_off()
  try
    silent execute 'keepjumps keeppatterns ' . a:l1 . ',' . a:l2 . (a:invert ? 'v' : 'g')
          \ . '//call add(l:acc, getline("."))'
  catch
    return rxops#app#collect#err('vim_error', v:exception)
  finally
    call rxops#app#collect#fold_restore(l:fold)
    call winrestview(l:view)
    call rxops#app#collect#marks_restore(l:marks)
  endtry
  return s:ok(len(l:acc), {'items': l:acc})
endfunction

" True when a line in {l1},{l2} matches, as :g// decides; it stops at the
" first one. Also true on an error, so that the real command reports it.
function! rxops#app#collect#has_line(l1, l2) abort
  let l:view = winsaveview()
  let l:marks = rxops#app#collect#marks_save()
  let l:fold = rxops#app#collect#fold_off()
  try
    " execute() keeps the 'Pattern not found' of :g out of a caller's
    " execute() or :redir as well
    call execute('keepjumps keeppatterns ' . a:l1 . ',' . a:l2 . 'g//throw "rxops:found"')
  catch
    return 1
  finally
    call rxops#app#collect#fold_restore(l:fold)
    call winrestview(l:view)
    call rxops#app#collect#marks_restore(l:marks)
  endtry
  return 0
endfunction

" \= callback: record the match and the last line it touches; change nothing.
function! s:record(st, lines) abort
  if a:lines != ['']
    call add(a:st.items, a:lines)
    let a:st.last = max([a:st.last, rxops#app#collect#last_line(line('.'), a:lines)])
  endif
  return ''
endfunction

" Every non-empty match in {l1},{l2}, one item per match: the List of its
" lines (submatch(0, 1)). 'last' is the last line a match touches (a match
" may run past {l2}).
function! rxops#app#collect#matches(l1, l2) abort
  let l:st = {'items': [], 'last': 0}
  let l:view = winsaveview()
  let l:marks = rxops#app#collect#marks_save()
  let l:opts = rxops#app#collect#options_off()
  let l:fold = rxops#app#collect#fold_off()
  try
    silent execute 'keepjumps keeppatterns ' . a:l1 . ',' . a:l2
          \ . 's//\=s:record(l:st, submatch(0, 1))/gne'
  catch
    return rxops#app#collect#err('vim_error', v:exception)
  finally
    call rxops#app#collect#fold_restore(l:fold)
    call rxops#app#collect#options_restore(l:opts)
    call winrestview(l:view)
    call rxops#app#collect#marks_restore(l:marks)
  endtry
  return s:ok(len(l:st.items), {'items': l:st.items, 'last': l:st.last})
endfunction

" Start [lnum, col] of every match in {l1},{l2}, as :s//g finds them
" (zero-width matches included). One pass, so linear in the matches.
function! rxops#app#collect#positions(l1, l2) abort
  let l:acc = []
  let l:view = winsaveview()
  let l:marks = rxops#app#collect#marks_save()
  let l:opts = rxops#app#collect#options_off()
  let l:fold = rxops#app#collect#fold_off()
  try
    " :s puts the cursor at the start of the match before evaluating \=
    silent execute 'keepjumps keeppatterns ' . a:l1 . ',' . a:l2
          \ . 's//\=len(add(l:acc, [line("."), col(".")])) ? "" : ""/gne'
  catch
    return rxops#app#collect#err('vim_error', v:exception)
  finally
    call rxops#app#collect#fold_restore(l:fold)
    call rxops#app#collect#options_restore(l:opts)
    call winrestview(l:view)
    call rxops#app#collect#marks_restore(l:marks)
  endtry
  return s:ok(len(l:acc), {'items': l:acc})
endfunction

" Yanked {lines}: linewise into "" (which writes "0) and, following
" 'clipboard', into + or *.
function! rxops#app#collect#set_reg(lines) abort
  call setreg('"', a:lines, 'V')
  call s:set_clipboard(a:lines, 0)
endfunction

" Deleted {lines}: as a delete of Vim does, shift "1-"8 to "2-"9 and put
" them linewise into "1, which "" then points to; "0 (the last yank) is
" left alone. + or * as a delete of the editor writes them.
function! rxops#app#collect#set_deleted(lines) abort
  for l:n in range(9, 2, -1)
    call setreg(l:n, getreg(l:n - 1, 1, 1), getregtype(l:n - 1))
  endfor
  " setreg() does not change what "" points to unless it writes "" (and so
  " "0). A yank into "1 points "" there; its text is replaced right after.
  let l:pos = getcurpos()
  let l:marks = rxops#app#collect#marks_save()
  try
    noautocmd normal! "1yy
  finally
    call setpos('.', l:pos)
    call rxops#app#collect#marks_restore(l:marks)
  endtry
  call setreg('1', a:lines, 'V')
  call s:set_clipboard(a:lines, 1)
endfunction

" {deleting}: the lines were deleted (else yanked).
function! s:set_clipboard(lines, deleting) abort
  if has('clipboard')
    for l:reg in rxops#app#collect#clipboard_regs(&clipboard, a:deleting, has('nvim'))
      call setreg(l:reg, a:lines, 'V')
    endfor
  endif
endfunction

" The registers a yank ({deleting} 0) or delete ({deleting} 1) also writes
" for the 'clipboard' value {clipboard}, as the editor does: + for
" "unnamedplus", * for "unnamed". With both, a yank writes both; a delete
" writes only + in Vim (clipboard-unnamedplus) and both in Neovim ({nvim}).
function! rxops#app#collect#clipboard_regs(clipboard, deleting, nvim) abort
  let l:items = split(a:clipboard, ',')
  let l:plus = index(l:items, 'unnamedplus') >= 0
  let l:star = index(l:items, 'unnamed') >= 0 && !(l:plus && a:deleting && !a:nvim)
  return (l:plus ? ['+'] : []) + (l:star ? ['*'] : [])
endfunction

function! rxops#app#collect#yank_lines(l1, l2) abort
  let l:r = rxops#app#collect#lines(a:l1, a:l2, 0)
  if l:r.ok && l:r.count > 0
    call rxops#app#collect#set_reg(l:r.items)
  endif
  return l:r
endfunction

function! rxops#app#collect#yank_matches(l1, l2) abort
  let l:r = rxops#app#collect#matches(a:l1, a:l2)
  if l:r.ok && l:r.count > 0
    call rxops#app#collect#set_reg(rxops#app#collect#flatten(l:r.items))
  endif
  return l:r
endfunction
