" Run a macro on matching lines or at each match.

" {reg} trimmed if it names one non-empty register. error: 'name' / 'empty'.
" : is the last command line, + and * the clipboard.
function! rxops#app#macro#register(reg) abort
  let l:reg = trim(a:reg)
  if l:reg !~# '^[a-zA-Z0-9":+*]$'
    return {'ok': v:false, 'code': 'bad_register', 'error': 'name', 'count': 0, 'changed': v:false, 'reg': l:reg}
  endif
  if empty(getreg(l:reg))
    return {'ok': v:false, 'code': 'bad_register', 'error': 'empty', 'count': 0, 'changed': v:false, 'reg': l:reg}
  endif
  return {'ok': v:true, 'code': '', 'error': '', 'count': 0, 'changed': v:false, 'reg': l:reg}
endfunction

" Deliberately not 'abort' and not under try / silent!: an error inside the
" macro must stop it (and :g) and flush the rest of the macro, as when the
" same command is typed. Under try the error becomes an exception and the
" remaining keys of the macro still run.
" vint: -ProhibitNoAbortFunction
function! s:run(cmd)
  execute a:cmd
endfunction
" vint: +ProhibitNoAbortFunction

" Each run is the macro followed by a <Cmd> that marks it done. A run that
" is aborted flushes the typeahead, so the mark never runs. Two kinds:
"   error:  an error message was shown. :g stops.
"   failed: a motion that failed (a beep, no message). :g goes on.
" A run that finishes is a success, even after a :silent! error inside it.
" A run that did not finish is an error when v:errmsg (cleared before the
" run) is set: stopping is the default. An error under :silent! sets
" v:errmsg too, but it is not kept in the message history and does not stop
" :g; so the run is a failed motion instead only when the history is large
" enough (s:min_history messages) and did not change during the run. A
" history of N messages does not change when the same error comes N+1 times
" in a row, so a small one is not trusted. A run of :RxopsMacroLines that :g
" went on from is never an error.
" The state is per call (a macro may call rxops again), keyed by an id that
" the marks carry.
let s:calls = {}
let s:next_id = 0
let s:min_history = 20

" Drop the state of calls that are not running any more: a call cut short
" by an exception (under a caller's :try) never removes its own. The calls
" still running are the newest ones, one per frame of macro#lines() or
" macro#matches() on the call stack; the one that is beginning is a frame
" too but has no state yet.
" (in a variable: vimlint does not know <stack>)
let s:stack = '<stack>'

function! s:drop_stale() abort
  let l:frames = len(split(expand(s:stack), 'rxops#app#macro#\%(lines\|matches\)\[', 1)) - 1
  let l:keep = max([l:frames - 1, 0])
  let l:ids = sort(map(keys(s:calls), 'str2nr(v:val)'), 'n')
  if len(l:ids) > l:keep
    for l:id in l:ids[0 : len(l:ids) - l:keep - 1]
      call remove(s:calls, l:id)
    endfor
  endif
endfunction

" Number of states kept (for tests).
function! rxops#app#macro#_pending() abort
  return len(s:calls)
endfunction

function! s:begin() abort
  call s:drop_stale()
  let s:next_id += 1
  let s:calls[s:next_id] = {'id': s:next_id, 'runs': 0, 'done': 0, 'failed': 0,
        \ 'error': 0, 'last_done': 1, 'fold': [],
        \ 'track': s:history_size() >= s:min_history, 'history': ''}
  return s:calls[s:next_id]
endfunction

" How many messages :messages keeps.
function! s:history_size() abort
  if exists('+messagesopt')
    return str2nr(matchstr(&messagesopt, 'history:\zs\d\+'))
  elseif exists('+msghistory')
    return eval('&msghistory')
  endif
  return 200
endfunction

" True when the run that did not finish stopped on an error that Vim showed.
function! s:stopped_on_error(st) abort
  if v:errmsg ==# ''
    return 0
  endif
  " a :silent! error, then a failed motion: nothing was added to the history
  return !(a:st.track && execute('messages') ==# a:st.history)
endfunction

" Folding is off only while :g reads its range (a closed fold would widen
" it); the macro runs with the folds as they were, as when typed.
function! s:fold_back(st) abort
  call rxops#app#collect#fold_restore(a:st.fold)
  let a:st.fold = []
endfunction

" Called before each run ({done} 0) and from the <Cmd> after it ({done} 1).
function! rxops#app#macro#_mark(id, done) abort
  let l:st = get(s:calls, a:id, {})
  if empty(l:st)
    return
  endif
  if a:done
    let l:st.done += 1
    let l:st.last_done = 1
    return
  endif
  call s:fold_back(l:st)
  " :g went on to this run, so the previous one cannot have been an error
  call s:close_run(l:st, 0)
  let l:st.runs += 1
  let l:st.last_done = 0
  if l:st.track
    let l:st.history = execute('messages')
  endif
  let v:errmsg = ''
endfunction

" Account for the previous run if it did not finish. {may_error}: 0 when
" another run has started after it (so nothing stopped).
function! s:close_run(st, may_error) abort
  if !a:st.last_done
    let a:st.failed += 1
    let a:st.error = a:may_error && s:stopped_on_error(a:st)
    let a:st.last_done = 1
  endif
endfunction

" One :normal that runs the macro and then marks it done.
function! s:normal(reg, id) abort
  return 'execute "normal! @' . escape(a:reg, '"\')
        \ . '\<Cmd>call rxops#app#macro#_mark(' . a:id . ', 1)\<CR>"'
endfunction

" code: '' / 'macro_failed' (finished, some runs failed) / 'macro_error'
" (stopped by an error, which Vim has shown). count: runs that finished.
function! s:result(st, tick) abort
  call s:close_run(a:st, 1)
  call remove(s:calls, a:st.id)
  let l:r = {'ok': a:st.failed == 0 ? v:true : v:false, 'code': '', 'error': '',
        \ 'count': a:st.done, 'failed': a:st.failed, 'runs': a:st.runs,
        \ 'changed': b:changedtick != a:tick ? v:true : v:false}
  if a:st.error
    let [l:r.code, l:r.error] = ['macro_error', v:errmsg]
  elseif a:st.failed
    let l:r.code = 'macro_failed'
  endif
  return l:r
endfunction

" :g//normal! @r. :g follows lines the macro adds or deletes.
function! rxops#app#macro#lines(l1, l2, invert, reg) abort
  let l:r = rxops#app#macro#register(a:reg)
  if !l:r.ok
    return l:r
  endif
  " An error before the first run would skip fold_back() under a caller's
  " :try (s:run() must not be in a :try itself): check the pattern first.
  try
    call search('', 'cnw')
  catch
    return {'ok': v:false, 'code': 'vim_error', 'error': v:exception, 'count': 0, 'changed': v:false}
  endtry
  let l:tick = b:changedtick
  let l:st = s:begin()
  let l:st.fold = rxops#app#collect#fold_off()
  call s:run(a:l1 . ',' . a:l2 . (a:invert ? 'v' : 'g')
        \ . '//call rxops#app#macro#_mark(' . l:st.id . ', 0) | ' . s:normal(l:r.reg, l:st.id))
  call s:fold_back(l:st)
  return s:result(l:st, l:tick)
endfunction

" Collect every match first, then run from the last one backwards, so edits
" after the cursor do not shift matches still to be visited. A failed motion
" skips that match; an error stops, as with :g.
function! rxops#app#macro#matches(l1, l2, reg) abort
  let l:r = rxops#app#macro#register(a:reg)
  if !l:r.ok
    return l:r
  endif
  let l:p = rxops#app#collect#positions(a:l1, a:l2)
  if !l:p.ok || l:p.count == 0
    return l:p
  endif
  let l:tick = b:changedtick
  let l:st = s:begin()
  let l:cmd = s:normal(l:r.reg, l:st.id)
  for [l:lnum, l:col] in reverse(copy(l:p.items))
    call cursor(l:lnum, l:col)
    call rxops#app#macro#_mark(l:st.id, 0)
    call s:run(l:cmd)
    call s:close_run(l:st, 1)
    if l:st.error
      break
    endif
  endfor
  return s:result(l:st, l:tick)
endfunction
