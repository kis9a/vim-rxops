let s:suite = themis#suite('command_lines')
let s:assert = themis#helper('assert')

let s:text = ['a x1', 'b', 'a x2', 'c', 'a x3']

function! s:suite.before_each() abort
  let s:regs = RxopsTestSaveRegs()
  let s:clipboard = &clipboard
  call RxopsTestBuffer(s:text)
  let @/ = 'x\d'
endfunction

function! s:suite.after_each() abort
  let &clipboard = s:clipboard
  call RxopsTestRestoreRegs(s:regs)
  call setqflist([], 'r')
endfunction

function! s:suite.delete_lines() abort
  let l:msg = execute('RxopsDeleteLines')
  call s:assert.equals(RxopsTestLines(), ['b', 'c'])
  call s:assert.equals(getreg('"', 1, 1), ['a x1', 'a x2', 'a x3'])
  call s:assert.equals(getregtype('"'), 'V')
  call s:assert.match(l:msg, '\[rxops\] 3 lines deleted')
  call s:assert.equals(@/, 'x\d')
endfunction

function! s:suite.delete_lines_range_and_undo() abort
  silent 2,4RxopsDeleteLines
  call s:assert.equals(RxopsTestLines(), ['a x1', 'b', 'c', 'a x3'])
  call s:assert.equals(getreg('"', 1, 1), ['a x2'])
  silent normal! u
  call s:assert.equals(RxopsTestLines(), s:text)
endfunction

function! s:suite.delete_lines_none() abort
  let @/ = 'zzz'
  let @" = 'keep'
  let l:msg = execute('RxopsDeleteLines')
  call s:assert.equals(RxopsTestLines(), s:text)
  call s:assert.equals(@", 'keep')
  call s:assert.match(l:msg, '\[rxops\] no lines deleted')
endfunction

function! s:suite.keep_lines_and_undo() abort
  let l:msg = execute('RxopsKeepLines')
  call s:assert.equals(RxopsTestLines(), ['a x1', 'a x2', 'a x3'])
  call s:assert.equals(getreg('"', 1, 1), ['b', 'c'])
  call s:assert.match(l:msg, '2 lines deleted')
  silent normal! u
  call s:assert.equals(RxopsTestLines(), s:text)
endfunction

function! s:suite.yank_lines() abort
  call cursor(2, 1)
  let l:tick = b:changedtick
  let l:msg = execute('RxopsYankLines')
  call s:assert.equals(getreg('"', 1, 1), ['a x1', 'a x2', 'a x3'])
  call s:assert.equals(getregtype('"'), 'V')
  call s:assert.equals(b:changedtick, l:tick)
  call s:assert.equals(line('.'), 2)
  call s:assert.match(l:msg, '3 lines yanked')
  silent 3,5RxopsYankLines
  call s:assert.equals(getreg('"', 1, 1), ['a x2', 'a x3'])
  let @/ = 'nomatch'
  call s:assert.match(execute('RxopsYankLines'), 'no matches')
endfunction

function! s:suite.clipboard_unnamedplus() abort
  if !has('clipboard')
    call s:assert.skip('no clipboard')
  endif
  set clipboard=unnamedplus
  silent RxopsYankLines
  call s:assert.equals(getreg('+', 1, 1), ['a x1', 'a x2', 'a x3'])
endfunction

function! s:suite.clipboard_unnamed() abort
  if !has('clipboard')
    call s:assert.skip('no clipboard')
  endif
  set clipboard=unnamed
  silent RxopsDeleteLines
  call s:assert.equals(getreg('*', 1, 1), ['a x1', 'a x2', 'a x3'])
endfunction

function! s:suite.quickfix_lines() abort
  call setline(2, 'b x9 x8')
  let @/ = 'x8'
  let l:msg = execute('RxopsQuickfixLines')
  let l:qf = getqflist()
  call s:assert.equals(map(copy(l:qf), '[v:val.lnum, v:val.col, v:val.text]'), [[2, 6, 'b x9 x8']])
  call s:assert.equals(l:qf[0].bufnr, bufnr(''))
  call s:assert.equals(getqflist({'title': 1}).title, 'RxopsQuickfixLines /x8')
  call s:assert.match(l:msg, '\[rxops\] 1 line -> quickfix (:copen)')
endfunction

function! s:suite.quickfix_unmatched_lines() abort
  let l:msg = execute('RxopsQuickfixLines!')
  call s:assert.equals(map(getqflist(), '[v:val.lnum, v:val.col]'), [[2, 1], [4, 1]])
  call s:assert.match(l:msg, '2 lines -> quickfix')
  let @/ = '.'
  call s:assert.match(execute('RxopsQuickfixLines!'), '\[rxops\] no lines')
endfunction

function! s:suite.quickfix_column_follows_smartcase() abort
  " regression: match() ignored 'smartcase' and gave column 1
  call RxopsTestBuffer(['todo TODO'])
  set ignorecase smartcase
  try
    let @/ = 'TODO'
    silent RxopsQuickfixLines
    call s:assert.equals(map(getqflist(), 'v:val.col'), [6])
  finally
    set noignorecase nosmartcase
  endtry
endfunction

function! s:suite.loclist_lines() abort
  let l:msg = execute('2,5RxopsLoclistLines')
  call s:assert.equals(map(getloclist(0), '[v:val.lnum, v:val.col]'), [[3, 3], [5, 3]])
  call s:assert.match(l:msg, '2 lines -> location list (:lopen)')
  call s:assert.equals(getqflist(), [])
  silent RxopsLoclistLines!
  call s:assert.equals(map(getloclist(0), 'v:val.lnum'), [2, 4])
  call s:assert.equals(getloclist(0, {'title': 1}).title, 'RxopsLoclistLines! /x\d')
endfunction

function! s:suite.macro_lines_and_undo() abort
  let @q = "A!\<Esc>"
  silent RxopsMacroLines q
  call s:assert.equals(RxopsTestLines(), ['a x1!', 'b', 'a x2!', 'c', 'a x3!'])
  silent normal! u
  call s:assert.equals(RxopsTestLines(), s:text)
  silent RxopsMacroLines! q
  call s:assert.equals(RxopsTestLines(), ['a x1', 'b!', 'a x2', 'c!', 'a x3'])
  call RxopsTestCloseUndo()
  silent normal! u
  silent 2,3RxopsMacroLines q
  call s:assert.equals(RxopsTestLines(), ['a x1', 'b', 'a x2!', 'c', 'a x3'])
endfunction

function! s:suite.macro_lines_follows_added_lines() abort
  let @q = 'yyp'
  silent RxopsMacroLines q
  call s:assert.equals(RxopsTestLines(), ['a x1', 'a x1', 'b', 'a x2', 'a x2', 'c', 'a x3', 'a x3'])
endfunction

function! s:suite.macro_register_errors() abort
  call setreg('q', '')
  call s:assert.match(execute('RxopsMacroLines q'), '\[rxops\] register q is empty')
  call s:assert.match(execute('RxopsMacroLines ab'), '\[rxops\] usage: RxopsMacroLines {reg}')
  call s:assert.match(execute('RxopsMacroLines! -'), 'usage: RxopsMacroLines! {reg}')
  call s:assert.equals(RxopsTestLines(), s:text)
  silent let l:r = rxops#macro_lines(1, line('$'), 0, '%')
  call s:assert.equals([l:r.ok, l:r.code], [v:false, 'bad_register'])
endfunction

function! s:suite.keep_lines_range() abort
  silent 1,2RxopsKeepLines
  call s:assert.equals(RxopsTestLines(), ['a x1', 'a x2', 'c', 'a x3'])
  call s:assert.equals(getreg('"', 1, 1), ['b'])
endfunction

function! s:suite.delete_lines_nomodifiable() abort
  " regression: lines that were never deleted went to the register
  setlocal nomodifiable
  let @" = 'keep'
  silent let l:r = rxops#delete_lines(1, line('$'))
  setlocal modifiable
  call s:assert.equals([l:r.ok, l:r.code, l:r.count], [v:false, 'vim_error', 0])
  call s:assert.equals(@", 'keep')
  call s:assert.equals(RxopsTestLines(), s:text)
endfunction

function! s:suite.delete_lines_partial_error_registers_deleted() abort
  let l:Remove = RxopsTestFailAfter(1)
  try
    silent let l:r = rxops#delete_lines(1, line('$'))
  finally
    call l:Remove()
    setlocal modifiable
  endtry
  call s:assert.equals([l:r.ok, l:r.code, l:r.count], [v:false, 'vim_error', 1])
  call s:assert.equals(RxopsTestLines(), ['b', 'a x2', 'c', 'a x3'])
  call s:assert.equals(getreg('"', 1, 1), ['a x1'])
endfunction

function! s:suite.keep_lines_partial_error_registers_deleted() abort
  let l:Remove = RxopsTestFailAfter(1)
  try
    silent let l:r = rxops#keep_lines(1, line('$'))
  finally
    call l:Remove()
    setlocal modifiable
  endtry
  call s:assert.equals([l:r.ok, l:r.count], [v:false, 1])
  call s:assert.equals(RxopsTestLines(), ['a x1', 'a x2', 'c', 'a x3'])
  call s:assert.equals(getreg('"', 1, 1), ['b'])
endfunction

function! s:suite.read_only_commands_keep_marks_and_jumps() abort
  call cursor(2, 1)
  normal! m'
  call cursor(4, 2)
  call setpos("'[", [0, 1, 1, 0])
  call setpos("']", [0, 2, 1, 0])
  let l:before = [getpos("''"), getpos("'["), getpos("']"), len(getjumplist()[0]), getpos('.')]
  for l:cmd in ['RxopsYankLines', 'RxopsYankMatches', 'RxopsQuickfixLines', 'RxopsLoclistLines!',
        \ 'RxopsQuickfixMatches', 'RxopsLoclistMatches', 'RxopsFoldLines', 'RxopsFoldLines']
    silent execute l:cmd
    call s:assert.equals([getpos("''"), getpos("'["), getpos("']"), len(getjumplist()[0]), getpos('.')],
          \ l:before, l:cmd)
  endfor
endfunction

function! s:suite.bar_after_commands_without_argument() abort
  unlet! g:rxops_test_bar
  silent execute 'RxopsYankLines | let g:rxops_test_bar = 1'
  call s:assert.equals(g:rxops_test_bar, 1)
  silent execute '2,3RxopsQuickfixLines! | let g:rxops_test_bar = 2'
  call s:assert.equals(g:rxops_test_bar, 2)
  call s:assert.equals(map(getqflist(), 'v:val.lnum'), [2])
  unlet g:rxops_test_bar
endfunction

" An error inside the macro must stop :g and drop the rest of the macro, as
" the typed :g//normal! @q does. themis runs tests under :try (which turns
" the error into an exception), so this runs in a child editor.
function! s:macro_run(cmd, macro) abort
  return RxopsTestTopLevel([
        \ 'call setline(1, ["foo 1", "foo 2", "foo 3", "bar"])',
        \ 'let @/ = "foo"',
        \ 'call setreg("q", ' . a:macro . ')',
        \ 'function! RxopsAtExit() abort',
        \ '  return [string(getline(1, "$"))]',
        \ 'endfunction',
        \ a:cmd])
endfunction

function! s:suite.macro_error_stops_like_typed_global() abort
  for l:macro in ['"/zzz\<CR>dd"', '"A!\<Esc>/zzz\<CR>A?\<Esc>"']
    let l:typed = s:macro_run('g//normal! @q', l:macro)
    let l:ours = s:macro_run('RxopsMacroLines q', l:macro)
    call s:assert.equals(l:ours, l:typed, l:macro)
  endfor
  call s:assert.equals(s:macro_run('RxopsMacroLines q', '"/zzz\<CR>dd"'),
        \ [string(['foo 1', 'foo 2', 'foo 3', 'bar'])])
  call s:assert.equals(s:macro_run('RxopsMacroLines q', '"A!\<Esc>/zzz\<CR>A?\<Esc>"'),
        \ [string(['foo 1!', 'foo 2', 'foo 3', 'bar'])])
endfunction

function! s:suite.macro_matches_error_stops() abort
  " the last match is visited first; the error stops everything
  call s:assert.equals(s:macro_run('RxopsMacroMatches q', '"A!\<Esc>/zzz\<CR>A?\<Esc>"'),
        \ [string(['foo 1', 'foo 2', 'foo 3!', 'bar'])])
endfunction

" A macro that completes after a :silent! error is no failure (v:errmsg is
" set, but the typed :g goes on).
function! s:macro_result(cmd, macro) abort
  return RxopsTestTopLevel([
        \ 'call setline(1, ["foo 1", "bar", "foo 2", "foo 3"])',
        \ 'let @/ = "foo"',
        \ 'let v:errmsg = "E999: stale"',
        \ 'call setreg("q", ' . a:macro . ')',
        \ 'let g:r = ' . a:cmd,
        \ 'call add(s:out, string(getline(1, "$")))',
        \ 'call add(s:out, exists("g:r.code") ? g:r.code : "(typed)")'])
endfunction

function! s:suite.macro_silent_error_runs_everywhere() abort
  let l:macro = '":silent! call NoSuch()\<CR>A!\<Esc>"'
  let l:all = string(['foo 1!', 'bar', 'foo 2!', 'foo 3!'])
  call s:assert.equals(s:macro_result('execute("g//normal! @q")', l:macro)[0], l:all)
  call s:assert.equals(s:macro_result('rxops#macro_lines(1, line("$"), 0, "q")', l:macro), [l:all, ''])
  call s:assert.equals(s:macro_result('rxops#macro_matches(1, line("$"), "q")', l:macro), [l:all, ''])
  call s:assert.equals(s:macro_result('rxops#macro_lines(1, line("$"), 0, "q")', '"A!\<Esc>"'), [l:all, ''])
endfunction

function! s:suite.macro_register_double_quote() abort
  let @" = "A!\<Esc>"
  silent RxopsMacroLines "
  call s:assert.equals(RxopsTestLines(), ['a x1!', 'b', 'a x2!', 'c', 'a x3!'])
endfunction

" A motion that fails in the macro (a beep, no message) skips that run and
" goes on, as the typed :g does; the command says how many runs failed.
function! s:failed_motion(call, pattern) abort
  return RxopsTestTopLevel([
        \ 'call setline(1, ["a=1", "b 2", "a=3"])',
        \ 'let @/ = ' . string(a:pattern),
        \ 'let @q = "f=r:"',
        \ 'let s:msg = execute("let g:r = " . ' . string(a:call) . ')',
        \ 'call add(s:out, string(getline(1, "$")))',
        \ 'call add(s:out, exists("g:r") ? string([g:r.ok, g:r.code, g:r.count, g:r.failed]) : "")',
        \ 'call add(s:out, matchstr(s:msg, "\\[rxops\\][^\\n]*"))'])
endfunction

function! s:suite.macro_failed_motion() abort
  let l:lines = string(['a:1', 'b 2', 'a:3'])
  call s:assert.equals(s:failed_motion('execute("g//normal! @q")', '.')[0], l:lines)
  call s:assert.equals(s:failed_motion('rxops#macro_lines(1, line("$"), 0, "q")', '.'),
        \ [l:lines, string([v:false, 'macro_failed', 2, 1]), '[rxops] macro failed on 1 of 3 lines'])
  " every line start is a match; the one on line 2 fails, the others run
  call s:assert.equals(s:failed_motion('rxops#macro_matches(1, line("$"), "q")', '^'),
        \ [l:lines, string([v:false, 'macro_failed', 2, 1]), '[rxops] macro failed on 1 of 3 matches'])
  call s:assert.equals(s:failed_motion('rxops#macro_lines(2, 2, 0, "q")', '.')[1:],
        \ [string([v:false, 'macro_failed', 0, 1]), '[rxops] macro failed on 1 of 1 line'])
endfunction

function! s:suite.macro_error_result() abort
  " an error stops; Vim shows it and the plugin adds nothing
  let l:out = RxopsTestTopLevel([
        \ 'call setline(1, ["foo 1", "x", "foo 2", "foo 3"])',
        \ 'let @/ = "foo"',
        \ 'let @q = "A!\<Esc>:call NoSuch()\<CR>"',
        \ 'let s:msg = execute("let g:r = rxops#macro_matches(1, line(\"$\"), \"q\")")',
        \ 'call add(s:out, string(getline(1, "$")))',
        \ 'call add(s:out, string([g:r.ok, g:r.code, g:r.count, g:r.failed]))',
        \ 'call add(s:out, string(s:msg =~# "\\[rxops\\]"))'])
  call s:assert.equals(l:out, [string(['foo 1', 'x', 'foo 2', 'foo 3!']),
        \ string([v:false, 'macro_error', 0, 1]), '0'])
endfunction
