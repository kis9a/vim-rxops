" Operations that change the buffer. Each runs as one Ex command chain, so a
" single undo puts the buffer back.

function! s:result(ok, code, msg, count, tick) abort
  return {'ok': a:ok, 'code': a:code, 'error': a:msg, 'count': a:count,
        \ 'changed': (b:changedtick != a:tick ? v:true : v:false)}
endfunction

" Delete the matching ({invert}: non-matching) lines, then register them all.
" A line is recorded only after it is really deleted.
function! rxops#app#edit#delete_lines(l1, l2, invert) abort
  let l:tick = b:changedtick
  let l:acc = []
  let l:fold = rxops#app#collect#fold_off()
  try
    silent execute 'keeppatterns ' . a:l1 . ',' . a:l2 . (a:invert ? 'v' : 'g')
          \ . '//let l:t = getline(".") | delete _ | call add(l:acc, l:t)'
  catch
    call rxops#app#collect#fold_restore(l:fold)
    " lines deleted before the error must not live only in the undo tree
    if !empty(l:acc)
      call rxops#app#collect#set_deleted(l:acc)
    endif
    return s:result(v:false, 'vim_error', v:exception, len(l:acc), l:tick)
  endtry
  call rxops#app#collect#fold_restore(l:fold)
  if !empty(l:acc)
    call rxops#app#collect#set_deleted(l:acc)
  endif
  return s:result(v:true, '', '', len(l:acc), l:tick)
endfunction

" \= callback of the deleting :s. :s replaces a line after all its matches,
" so the matches of a line are pending until :s moves to another line.
" {lines} is submatch(0, 1), so a NUL inside a line stays in its line.
function! s:record_deleted(st, lines) abort
  let l:lnum = line('.')
  if l:lnum != a:st.lnum
    call extend(a:st.items, a:st.pending)
    let a:st.pending = []
    let a:st.lnum = l:lnum
    let a:st.orig = getline(l:lnum)
  endif
  if a:lines != ['']
    call add(a:st.pending, a:lines)
  endif
  return ''
endfunction

" Delete the matched text. The text is recorded by the deleting :s itself, so
" the register holds exactly what went away, also when :s fails part way
" (the last line counts only if its text changed). Empty matches delete
" nothing and are not counted.
function! rxops#app#edit#delete_matches(l1, l2) abort
  let l:tick = b:changedtick
  let l:st = {'items': [], 'pending': [], 'lnum': 0, 'orig': ''}
  let l:opts = rxops#app#collect#options_off()
  let l:fold = rxops#app#collect#fold_off()
  let l:error = ''
  try
    silent execute 'keeppatterns ' . a:l1 . ',' . a:l2
          \ . 's//\=s:record_deleted(l:st, submatch(0, 1))/ge'
  catch
    let l:error = v:exception
  finally
    call rxops#app#collect#fold_restore(l:fold)
    call rxops#app#collect#options_restore(l:opts)
  endtry
  if l:error ==# '' || (l:st.lnum > 0 && getline(l:st.lnum) !=# l:st.orig)
    call extend(l:st.items, l:st.pending)
  endif
  if !empty(l:st.items)
    call rxops#app#collect#set_deleted(rxops#app#collect#flatten(l:st.items))
  endif
  if l:error !=# ''
    return s:result(v:false, 'vim_error', l:error, len(l:st.items), l:tick)
  endif
  return s:result(v:true, '', '', len(l:st.items), l:tick)
endfunction

" Replace the range with its matches, one per line. A match that runs past
" {l2} takes the lines it touches with it. Registers are untouched.
function! rxops#app#edit#keep_matches(l1, l2) abort
  let l:tick = b:changedtick
  let l:m = rxops#app#collect#matches(a:l1, a:l2)
  if !l:m.ok || l:m.count == 0
    return l:m
  endif
  let l:last = max([a:l2, l:m.last])
  let l:whole = a:l1 == 1 && l:last == line('$')
  let l:lines = rxops#app#collect#flatten(l:m.items)
  let l:fold = rxops#app#collect#fold_off()
  try
    silent execute a:l1 . ',' . l:last . 'delete _'
    if l:whole
      " deleting every line leaves one empty line: overwrite it
      call setline(1, l:lines)
    else
      call append(a:l1 - 1, l:lines)
    endif
  catch
    return s:result(v:false, 'vim_error', v:exception, 0, l:tick)
  finally
    call rxops#app#collect#fold_restore(l:fold)
  endtry
  return s:result(v:true, '', '', l:m.count, l:tick)
endfunction

" :g//s<spec>e. The pattern and replacement go to :s unchanged; that :s is
" the user's own, so 'gdefault' applies. keeppatterns: @/ stays even for a
" caller that is a function, and nothing goes into the search history.
function! rxops#app#edit#substitute_lines(l1, l2, spec) abort
  let l:s = rxops#domain#subst#parse(a:spec, &magic, &cpoptions)
  if !l:s.ok
    return l:s
  endif
  let l:tick = b:changedtick
  let l:d = l:s.delim
  let l:fold = rxops#app#collect#fold_off()
  try
    execute printf('keeppatterns %d,%dg//keeppatterns s%s%s%s%s%s%se', a:l1, a:l2,
          \ l:d, l:s.pat, l:d, l:s.rep, l:d, substitute(l:s.flags, 'e', '', 'g'))
  catch
    return s:result(v:false, 'vim_error', v:exception, 0, l:tick)
  finally
    call rxops#app#collect#fold_restore(l:fold)
  endtry
  return s:result(v:true, '', '', 0, l:tick)
endfunction

function! s:in_match(ctx, text) abort
  let l:new = substitute(a:text, a:ctx.pat, a:ctx.rep, a:ctx.flags)
  if l:new !=# a:text
    let a:ctx.count += 1
  endif
  return l:new
endfunction

" Substitute only inside each match of the last search.
function! rxops#app#edit#substitute_matches(l1, l2, spec) abort
  let l:s = rxops#domain#subst#parse(a:spec, &magic, &cpoptions)
  if !l:s.ok
    return l:s
  endif
  let l:f = rxops#domain#subst#sm_flags(l:s.flags)
  if !l:f.ok
    return l:f
  endif
  let l:tick = b:changedtick
  let l:ctx = {
        \ 'pat': rxops#domain#subst#sm_pattern(l:s.pat, l:s.flags, l:s.delim, &ignorecase, &smartcase, &magic),
        \ 'rep': l:s.rep, 'flags': rxops#domain#subst#sm_global(l:s.flags, &gdefault) ? 'g' : '', 'count': 0}
  let l:opts = rxops#app#collect#options_off()
  let l:fold = rxops#app#collect#fold_off()
  try
    silent execute 'keeppatterns ' . a:l1 . ',' . a:l2 . 's//\=s:in_match(l:ctx, submatch(0))/ge'
  catch
    return s:result(v:false, 'vim_error', v:exception, l:ctx.count, l:tick)
  finally
    call rxops#app#collect#fold_restore(l:fold)
    call rxops#app#collect#options_restore(l:opts)
  endtry
  return s:result(v:true, '', '', l:ctx.count, l:tick)
endfunction
