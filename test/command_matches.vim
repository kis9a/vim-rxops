let s:suite = themis#suite('command_matches')
let s:assert = themis#helper('assert')

let s:text = ['k=1 k=22', 'none', 'k=333']

function! s:suite.before_each() abort
  let s:regs = RxopsTestSaveRegs()
  call RxopsTestBuffer(s:text)
  let @/ = 'k=\d\+'
endfunction

function! s:suite.after_each() abort
  call RxopsTestRestoreRegs(s:regs)
  call setqflist([], 'r')
endfunction

function! s:suite.delete_matches() abort
  let l:msg = execute('RxopsDeleteMatches')
  call s:assert.equals(RxopsTestLines(), [' ', 'none', ''])
  call s:assert.equals(getreg('"', 1, 1), ['k=1', 'k=22', 'k=333'])
  call s:assert.equals(getregtype('"'), 'V')
  call s:assert.match(l:msg, '3 matches deleted')
  silent normal! u
  call s:assert.equals(RxopsTestLines(), s:text)
endfunction

function! s:suite.delete_matches_range() abort
  silent 2,3RxopsDeleteMatches
  call s:assert.equals(RxopsTestLines(), ['k=1 k=22', 'none', ''])
  call s:assert.equals(getreg('"', 1, 1), ['k=333'])
  let @/ = 'zzz'
  call s:assert.match(execute('RxopsDeleteMatches'), '\[rxops\] no matches')
endfunction

function! s:suite.keep_matches_whole_buffer() abort
  let @" = 'keep'
  silent RxopsKeepMatches
  call s:assert.equals(RxopsTestLines(), ['k=1', 'k=22', 'k=333'])
  call s:assert.equals(@", 'keep')
  silent normal! u
  call s:assert.equals(RxopsTestLines(), s:text)
endfunction

function! s:suite.keep_matches_range() abort
  call RxopsTestBuffer(['k=1 k=2', 'k=3', ''])
  silent 1,2RxopsKeepMatches
  " the empty line after the range is not taken as the leftover line
  call s:assert.equals(RxopsTestLines(), ['k=1', 'k=2', 'k=3', ''])
  call RxopsTestBuffer(['top', 'k=1 x k=2', 'end'])
  silent 2RxopsKeepMatches
  call s:assert.equals(RxopsTestLines(), ['top', 'k=1', 'k=2', 'end'])
  let @/ = 'zzz'
  call s:assert.match(execute('RxopsKeepMatches'), 'no matches')
endfunction

function! s:suite.yank_matches() abort
  let l:tick = b:changedtick
  let l:msg = execute('RxopsYankMatches')
  call s:assert.equals(getreg('"', 1, 1), ['k=1', 'k=22', 'k=333'])
  call s:assert.equals(b:changedtick, l:tick)
  call s:assert.match(l:msg, '3 matches yanked')
  silent 1RxopsYankMatches
  call s:assert.equals(getreg('"', 1, 1), ['k=1', 'k=22'])
endfunction

function! s:suite.quickfix_matches() abort
  let l:msg = execute('RxopsQuickfixMatches')
  call s:assert.equals(map(getqflist(), '[v:val.lnum, v:val.col, v:val.text]'),
        \ [[1, 1, 'k=1 k=22'], [1, 5, 'k=1 k=22'], [3, 1, 'k=333']])
  call s:assert.equals(getqflist({'title': 1}).title, 'RxopsQuickfixMatches /k=\d\+')
  call s:assert.match(l:msg, '3 matches -> quickfix (:copen)')
  call s:assert.equals(line('.'), 1)
endfunction

function! s:suite.loclist_matches() abort
  call cursor(3, 2)
  let l:msg = execute('1,2RxopsLoclistMatches')
  call s:assert.equals(map(getloclist(0), '[v:val.lnum, v:val.col]'), [[1, 1], [1, 5]])
  call s:assert.match(l:msg, '2 matches -> location list (:lopen)')
  call s:assert.equals(getpos('.')[1:2], [3, 2])
  let @/ = 'zzz'
  call s:assert.match(execute('RxopsLoclistMatches'), 'no matches')
endfunction

function! s:suite.macro_matches() abort
  let @q = 'r#'
  let l:msg = execute('RxopsMacroMatches q')
  call s:assert.equals(RxopsTestLines(), ['#=1 #=22', 'none', '#=333'])
  call s:assert.match(l:msg, '\[rxops\] 3 matches')
  silent normal! u
  call s:assert.equals(RxopsTestLines(), s:text)
endfunction

function! s:suite.macro_matches_runs_backwards() abort
  " inserting before the cursor would shift later matches if run forwards
  let @q = "i<\<Esc>"
  silent 1RxopsMacroMatches q
  call s:assert.equals(RxopsTestLines(), ['<k=1 <k=22', 'none', 'k=333'])
  let @/ = 'zzz'
  call s:assert.match(execute('RxopsMacroMatches q'), 'no matches')
endfunction

function! s:suite.macro_matches_bad_register() abort
  call s:assert.match(execute('RxopsMacroMatches !'), '\[rxops\] usage: RxopsMacroMatches {reg}')
endfunction

function! s:suite.many_matches_are_linear() abort
  " regression: returning add()'s List from \= made collecting quadratic
  " (about 6 s for 20000 matches); linear is tens of ms
  call RxopsTestBuffer(map(range(1, 20000), '"k=" . v:val'))
  let l:t = reltime()
  silent RxopsYankMatches
  call s:assert.compare(reltimefloat(reltime(l:t)), '<', 1.0)
  call s:assert.equals(len(getreg('"', 1, 1)), 20000)
endfunction

function! s:suite.gdefault_does_not_change_internal_substitute() abort
  set gdefault
  try
    silent RxopsYankMatches
    call s:assert.equals(getreg('"', 1, 1), ['k=1', 'k=22', 'k=333'])
    silent RxopsQuickfixMatches
    call s:assert.equals(len(getqflist()), 3)
    silent RxopsDeleteMatches
    call s:assert.equals(RxopsTestLines(), [' ', 'none', ''])
    call RxopsTestBuffer(s:text)
    silent RxopsKeepMatches
    call s:assert.equals(RxopsTestLines(), ['k=1', 'k=22', 'k=333'])
    call RxopsTestBuffer(s:text)
    " SM is the user's own: with 'gdefault' its g means first only, as for :s
    silent RxopsSubstituteMatches /\d/N/g
    call s:assert.equals(RxopsTestLines(), ['k=N k=N2', 'none', 'k=N33'])
    call s:assert.true(&gdefault)
  finally
    set nogdefault
  endtry
endfunction

function! s:suite.edcompatible_does_not_change_internal_substitute() abort
  if !exists('+edcompatible')
    call s:assert.skip('no edcompatible')
  endif
  set edcompatible
  try
    " with edcompatible a later :s toggles the remembered g flag
    " vint: -ProhibitCommandRelyOnUser -ProhibitCommandWithUnintendedSideEffect
    silent! s/zzz/y/g
    " vint: +ProhibitCommandRelyOnUser +ProhibitCommandWithUnintendedSideEffect
    let @/ = 'k=\d\+'
    silent RxopsYankMatches
    call s:assert.equals(getreg('"', 1, 1), ['k=1', 'k=22', 'k=333'])
    call s:assert.true(&edcompatible)
  finally
    set noedcompatible
  endtry
endfunction

function! s:suite.multiline_matches_are_split_into_lines() abort
  call RxopsTestBuffer(['ab', 'cd', 'ab', 'xx'])
  let @/ = 'b\nc'
  silent RxopsYankMatches
  call s:assert.equals(getreg('"', 1, 1), ['b', 'c'])
  silent RxopsKeepMatches
  call s:assert.equals(RxopsTestLines(), ['b', 'c'])
  call RxopsTestBuffer(['ab', 'cd', 'ab', 'xx'])
  silent RxopsDeleteMatches
  call s:assert.equals(RxopsTestLines(), ['ad', 'ab', 'xx'])
  call s:assert.equals(getreg('"', 1, 1), ['b', 'c'])
  call s:assert.equals(filter(RxopsTestLines(), 'v:val =~# "\n"'), [])
endfunction

function! s:suite.keep_matches_past_range_end() abort
  " the match starting in line 1 ends in line 2: line 2 is replaced too
  call RxopsTestBuffer(['ab', 'cd', 'ab', 'xx'])
  let @/ = 'b\nc'
  silent 1RxopsKeepMatches
  call s:assert.equals(RxopsTestLines(), ['b', 'c', 'ab', 'xx'])
  " a match that only takes the line break leaves the next line alone
  call RxopsTestBuffer(['ab', 'cd'])
  let @/ = 'b\n'
  silent 1RxopsKeepMatches
  call s:assert.equals(RxopsTestLines(), ['b', '', 'cd'])
endfunction

function! s:suite.delete_matches_zero_width() abort
  " regression: reported deletions and overwrote the register
  let @/ = '^'
  let @" = 'keep'
  silent let l:r = rxops#delete_matches(1, line('$'))
  call s:assert.equals([l:r.ok, l:r.count], [v:true, 0])
  call s:assert.equals(@", 'keep')
  call s:assert.equals(RxopsTestLines(), s:text)
  let @/ = 'x*'
  call RxopsTestBuffer(['axxb'])
  silent RxopsDeleteMatches
  call s:assert.equals([getline(1), getreg('"', 1, 1)], ['ab', ['xx']])
endfunction

function! s:suite.quickfix_matches_range() abort
  silent 2,3RxopsQuickfixMatches
  call s:assert.equals(map(getqflist(), '[v:val.lnum, v:val.col]'), [[3, 1]])
endfunction

function! s:suite.many_matches_on_one_line_are_linear() abort
  " regression: searchpos() from the cursor rescans the line (4 s for 10000)
  call RxopsTestBuffer([repeat('k=1 ', 10000)])
  let l:t = reltime()
  silent RxopsQuickfixMatches
  call s:assert.compare(reltimefloat(reltime(l:t)), '<', 1.0)
  call s:assert.equals(len(getqflist()), 10000)
  call s:assert.equals(getqflist()[-1].col, 39997)
endfunction

function! s:suite.keeps_search_history_and_substitute() abort
  call RxopsTestBuffer(['a k=1', 'a k=2', 'a'])
  " vint: -ProhibitCommandRelyOnUser -ProhibitCommandWithUnintendedSideEffect
  1s/a/X/
  " vint: +ProhibitCommandRelyOnUser +ProhibitCommandWithUnintendedSideEffect
  let @/ = 'k=\d'
  let l:hist = histnr('/')
  for l:cmd in ['RxopsYankLines', 'RxopsYankMatches', 'RxopsQuickfixLines', 'RxopsQuickfixMatches',
        \ 'RxopsFoldLines', 'RxopsFoldLines', 'RxopsSubstituteMatches /k/K/',
        \ 'RxopsSubstituteLines /=/:/', 'RxopsDeleteMatches']
    silent execute l:cmd
    call s:assert.equals([histnr('/'), @/], [l:hist, 'k=\d'], l:cmd)
  endfor
  " :& still repeats the user's own :s/a/X/
  " vint: -ProhibitCommandRelyOnUser -ProhibitCommandWithUnintendedSideEffect
  3&
  " vint: +ProhibitCommandRelyOnUser +ProhibitCommandWithUnintendedSideEffect
  call s:assert.equals(getline(3), 'X')
endfunction

function! s:suite.delete_matches_error_keeps_deleted_text_in_register() abort
  " the listener throws after the first change; :s has deleted everything by
  " then, and all of it must be in the register
  let @" = 'keep'
  let l:Remove = RxopsTestThrowAfter(1)
  try
    silent let l:r = rxops#delete_matches(1, line('$'))
  finally
    call l:Remove()
  endtry
  call s:assert.equals([l:r.ok, l:r.code, l:r.count], [v:false, 'vim_error', 3])
  call s:assert.equals(RxopsTestLines(), [' ', 'none', ''])
  call s:assert.equals(getreg('"', 1, 1), ['k=1', 'k=22', 'k=333'])
endfunction

function! s:suite.macro_reentrant_call() abort
  " a macro that calls the API: each call keeps its own result
  call RxopsTestBuffer(['foo 1', 'bar', 'foo 2'])
  let @/ = 'foo'
  let @r = "A!\<Esc>"
  " charwise, as recorded with q (let @q = "...\<CR>" would be linewise)
  call setreg('q', ":call rxops#macro_matches(line('.'), line('.'), 'r')\<CR>", 'c')
  silent let l:r = rxops#macro_lines(1, line('$'), 0, 'q')
  call s:assert.equals(RxopsTestLines(), ['foo 1!', 'bar', 'foo 2!'])
  call s:assert.equals([l:r.ok, l:r.code, l:r.count, l:r.runs, l:r.failed], [v:true, '', 2, 2, 0])
endfunction

function! s:suite.macro_error_inside_try_then_next_call() abort
  " inside a :try the error is an exception and no Result comes back; a
  " later call is not confused by the abandoned one
  call RxopsTestBuffer(['foo 1', 'bar', 'foo 2'])
  let @/ = 'foo'
  let @q = ":call NoSuch()\<CR>"
  let l:caught = ''
  try
    silent call rxops#macro_lines(1, line('$'), 0, 'q')
  catch
    let l:caught = v:exception
  endtry
  call s:assert.match(l:caught, 'E117')
  let @q = "A!\<Esc>"
  silent let l:r = rxops#macro_lines(1, line('$'), 0, 'q')
  call s:assert.equals([l:r.ok, l:r.count, l:r.runs, l:r.failed], [v:true, 2, 2, 0])
endfunction
