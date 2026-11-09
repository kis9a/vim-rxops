" Regressions found by the second review (R1-R11 of the plan).
let s:suite = themis#suite('regression')
let s:assert = themis#helper('assert')

let s:regnames = ['"', '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'q']

function! s:suite.before_each() abort
  let s:regs = {}
  for l:r in s:regnames
    let s:regs[l:r] = [getreg(l:r, 1, 1), getregtype(l:r)]
  endfor
  let s:clipboard = &clipboard
  set clipboard=
  call RxopsTestBuffer(['a x0', 'a x1', 'a x2', 'a x3', 'a x4'])
  let @/ = 'x\d'
endfunction

function! s:suite.after_each() abort
  for l:r in s:regnames
    call setreg(l:r, s:regs[l:r][0], s:regs[l:r][1])
  endfor
  let &clipboard = s:clipboard
  set noignorecase nosmartcase magic
  call setqflist([], 'r')
  if exists(':EasyAlign') == 2
    delcommand EasyAlign
  endif
endfunction

" ---------------------------------------------------------------------------
" R1: a closed fold must not widen the range of the internal commands.

function! s:fold_1_4() abort
  setlocal foldmethod=manual foldenable
  1,4fold
  call RxopsTestCloseUndo()
endfunction

function! s:closed() abort
  return map(range(1, line('$')), 'foldclosed(v:val)')
endfunction

function! s:suite.fold_range_of_one_line() abort
  let l:cases = [
        \ ['RxopsDeleteLines', ['a x0', 'a x2', 'a x3', 'a x4'], ['a x1']],
        \ ['RxopsKeepLines', ['a x0', 'a x1', 'a x2', 'a x3', 'a x4'], v:null],
        \ ['RxopsDeleteMatches', ['a x0', 'a ', 'a x2', 'a x3', 'a x4'], ['x1']],
        \ ['RxopsKeepMatches', ['a x0', 'x1', 'a x2', 'a x3', 'a x4'], v:null],
        \ ['RxopsSubstituteMatches /x/X/', ['a x0', 'a X1', 'a x2', 'a x3', 'a x4'], v:null],
        \ ['RxopsSubstituteLines /a/A/', ['a x0', 'A x1', 'a x2', 'a x3', 'a x4'], v:null],
        \ ['RxopsMacroLines q', ['a x0', 'a x1!', 'a x2', 'a x3', 'a x4'], v:null],
        \ ]
  for [l:cmd, l:lines, l:reg] in l:cases
    call RxopsTestBuffer(['a x0', 'a x1', 'a x2', 'a x3', 'a x4'])
    call s:fold_1_4()
    call setreg('q', "A!\<Esc>", 'c')
    let @" = 'before'
    silent execute '2' . l:cmd
    call s:assert.equals(RxopsTestLines(), l:lines, l:cmd)
    if l:reg isnot v:null
      call s:assert.equals(getreg('"', 1, 1), l:reg, l:cmd)
    endif
    call s:assert.equals(&l:foldenable, 1, l:cmd)
  endfor
endfunction

function! s:suite.fold_range_read_only_commands() abort
  call s:fold_1_4()
  silent 2RxopsYankLines
  call s:assert.equals(getreg('"', 1, 1), ['a x1'])
  silent 2RxopsYankMatches
  call s:assert.equals(getreg('"', 1, 1), ['x1'])
  " (a typed :2,3 is widened by Vim itself, as for :2,3s: call the functions)
  silent call rxops#list_lines(2, 3, 0, 0)
  call s:assert.equals(map(getqflist(), 'v:val.lnum'), [2, 3])
  silent 2RxopsQuickfixMatches
  call s:assert.equals(map(getqflist(), 'v:val.lnum'), [2])
  command! -range -nargs=* EasyAlign let g:rxops_test_align = [<line1>, <line2>]
  silent call rxops#align_matches(2, 3, '')
  call s:assert.equals(g:rxops_test_align, [2, 3])
  unlet g:rxops_test_align
  " the fold is still there and still closed
  call s:assert.equals(s:closed(), [1, 1, 1, 1, -1])
  call s:assert.equals(&l:foldenable, 1)
endfunction

function! s:suite.fold_keep_matches_past_range() abort
  " a match that runs past the range takes only the lines it touches
  call RxopsTestBuffer(['foo', 'bar', 'y', 'z', 'tail'])
  setlocal foldmethod=manual
  2,4fold
  let @/ = 'foo\nbar'
  silent 1RxopsKeepMatches
  call s:assert.equals(RxopsTestLines(), ['foo', 'bar', 'y', 'z', 'tail'])
endfunction

function! s:suite.fold_open_state_kept() abort
  call s:fold_1_4()
  normal! zo
  silent 2RxopsYankLines
  call s:assert.equals(s:closed(), [-1, -1, -1, -1, -1])
  call s:assert.equals(foldlevel(2), 1)
  setlocal nofoldenable
  silent 2RxopsYankLines
  call s:assert.equals(&l:foldenable, 0)
endfunction

" ---------------------------------------------------------------------------
" R2: a NUL inside a line ("\n" in a Vim string) is no line break.

function! s:suite.nul_keep_matches_stays_in_range() abort
  call RxopsTestBuffer(["a\nb", 'KEEP'])
  let @/ = 'a.b'
  silent let l:r = rxops#keep_matches(1, 1)
  call s:assert.equals([l:r.ok, l:r.count], [v:true, 1])
  call s:assert.equals(RxopsTestLines(), ["a\nb", 'KEEP'])
  call RxopsTestBuffer(["a\nb"])
  silent let l:r = rxops#keep_matches(1, 1)
  call s:assert.equals([l:r.ok, RxopsTestLines()], [v:true, ["a\nb"]])
endfunction

function! s:suite.nul_registers_hold_one_line() abort
  call RxopsTestBuffer(["a\nb", 'KEEP'])
  let @/ = 'a.b'
  silent RxopsYankMatches
  call s:assert.equals(getreg('"', 1, 1), ["a\nb"])
  call RxopsTestBuffer(["xa\nby", 'KEEP'])
  silent RxopsDeleteMatches
  call s:assert.equals(RxopsTestLines(), ['xy', 'KEEP'])
  call s:assert.equals(getreg('"', 1, 1), ["a\nb"])
endfunction

function! s:suite.nul_and_line_break_in_one_match() abort
  call RxopsTestBuffer(["a\nb", 'c', 'tail'])
  let @/ = 'a.b\nc'
  silent RxopsYankMatches
  call s:assert.equals(getreg('"', 1, 1), ["a\nb", 'c'])
  silent 1RxopsKeepMatches
  call s:assert.equals(RxopsTestLines(), ["a\nb", 'c', 'tail'])
  " a match that ends in a line break: one empty line after it, as before
  call RxopsTestBuffer(['foo', 'bar'])
  let @/ = 'foo\n'
  silent RxopsYankMatches
  call s:assert.equals(getreg('"', 1, 1), ['foo', ''])
endfunction

" ---------------------------------------------------------------------------
" R3: RxopsFoldLines in another buffer of the same window keeps the state
" of the first buffer.

function! s:suite.fold_other_buffer_keeps_state() abort
  let l:a = tempname() . '-a.txt'
  let l:b = tempname() . '-b.txt'
  call writefile(['foo', 'bar', 'baz', 'foo'], l:a)
  call writefile(['foo', 'bar'], l:b)
  let l:hidden = &hidden
  set hidden
  try
    silent execute 'edit' fnameescape(l:a)
    let l:abuf = bufnr('')
    setlocal foldmethod=manual
    2,3fold
    let @/ = 'foo'
    silent RxopsFoldLines
    silent execute 'edit' fnameescape(l:b)
    silent call s:assert.equals(rxops#fold_lines().action, 'narrow')
    silent execute 'buffer' l:abuf
    silent let l:r = rxops#fold_lines()
    call s:assert.equals(l:r.action, 'restored')
    call s:assert.equals(&l:foldmethod, 'manual')
    call s:assert.equals(s:closed(), [-1, 2, 2, -1])
    " the state of B is still there too
    silent execute 'buffer' bufnr(l:b)
    silent let l:r = rxops#fold_lines()
    call s:assert.equals(l:r.action, 'restored')
    call s:assert.equals(&l:foldmethod, 'manual')
  finally
    let &hidden = l:hidden
    enew!
    silent execute 'bwipeout!' bufnr(l:a) bufnr(l:b)
    call delete(l:a)
    call delete(l:b)
  endtry
endfunction

function! s:suite.fold_state_of_wiped_buffer_is_dropped() abort
  let l:a = tempname() . '-a.txt'
  call writefile(['foo', 'bar'], l:a)
  try
    silent execute 'edit' fnameescape(l:a)
    let l:abuf = bufnr('')
    let @/ = 'foo'
    silent RxopsFoldLines
    let l:view = w:rxops_fold[l:abuf].view
    call s:assert.true(filereadable(l:view))
    call RxopsTestBuffer(['foo', 'x'])
    silent execute 'bwipeout!' l:abuf
    silent RxopsFoldLines
    call s:assert.false(has_key(w:rxops_fold, l:abuf))
    call s:assert.false(filereadable(l:view))
    silent RxopsFoldLines
  finally
    call delete(l:a)
  endtry
endfunction

" ---------------------------------------------------------------------------
" R4: the deleting commands leave "0 (the last yank) alone and shift "1-"9
" as a delete of Vim does; "" points to "1.

function! s:deleted(cmd) abort
  call RxopsTestBuffer(['keep', 'foo 1', 'bar', 'foo 2'])
  let @/ = 'foo \d'
  call setreg('1', ['old one'], 'V')
  call setreg('2', ['old two'], 'V')
  normal! gg0yiw
  silent execute a:cmd
  return [getreg('0', 1, 1), getreg('1', 1, 1), getregtype('1'),
        \ getreg('2', 1, 1), getreg('3', 1, 1), getreg('"', 1, 1)]
endfunction

function! s:suite.delete_commands_keep_register_0() abort
  call s:assert.equals(s:deleted('RxopsDeleteLines'),
        \ [['keep'], ['foo 1', 'foo 2'], 'V', ['old one'], ['old two'], ['foo 1', 'foo 2']])
  call s:assert.equals(s:deleted('RxopsKeepLines'),
        \ [['keep'], ['keep', 'bar'], 'V', ['old one'], ['old two'], ['keep', 'bar']])
  call s:assert.equals(s:deleted('RxopsDeleteMatches'),
        \ [['keep'], ['foo 1', 'foo 2'], 'V', ['old one'], ['old two'], ['foo 1', 'foo 2']])
  " p puts what was deleted
  call RxopsTestBuffer(['x'])
  normal! p
  call s:assert.equals(RxopsTestLines(), ['x', 'foo 1', 'foo 2'])
endfunction

" Putting the text in "1 must not move the cursor or '[ '] (compare with
" the typed :g//d _).
function! s:after_delete(cmd) abort
  call RxopsTestBuffer(['a', 'foo 1', 'b', 'c', 'foo 2', 'd'])
  let @/ = 'foo'
  call cursor(1, 1)
  silent execute a:cmd
  return [getcurpos(), getpos("'["), getpos("']")]
endfunction

function! s:suite.delete_commands_keep_cursor_and_marks() abort
  call s:assert.equals(s:after_delete('RxopsDeleteLines'), s:after_delete('keeppatterns g//d _'))
endfunction

function! s:suite.delete_error_keeps_register_0() abort
  call RxopsTestBuffer(['keep', 'foo 1', 'foo 2', 'foo 3'])
  let @/ = 'foo'
  normal! gg0yiw
  let l:Remove = RxopsTestFailAfter(1)
  try
    silent let l:r = rxops#delete_lines(1, line('$'))
  finally
    call l:Remove()
    setlocal modifiable
  endtry
  call s:assert.equals([l:r.ok, l:r.count], [v:false, 1])
  call s:assert.equals(getreg('0', 1, 1), ['keep'])
  call s:assert.equals(getreg('1', 1, 1), ['foo 1'])
  call s:assert.equals(getreg('"', 1, 1), ['foo 1'])
endfunction

function! s:suite.yank_commands_still_use_register_0() abort
  call RxopsTestBuffer(['foo 1', 'bar'])
  let @/ = 'foo'
  call setreg('1', ['one'], 'V')
  silent RxopsYankLines
  call s:assert.equals([getreg('0', 1, 1), getreg('"', 1, 1), getreg('1', 1, 1)],
        \ [['foo 1'], ['foo 1'], ['one']])
  silent RxopsYankMatches
  call s:assert.equals([getreg('0', 1, 1), getreg('1', 1, 1)], [['foo'], ['one']])
endfunction

" ---------------------------------------------------------------------------
" R5 (documented in rxops-limitations): after RxopsSubstituteLines, ~ in a
" later :s stands for its {string}; :& still repeats your own :s.

function! s:after_sl(cmd) abort
  return RxopsTestTopLevel([
        \ 'call setline(1, ["a b c", "a b c", "a b c"])',
        \ '1s/a/OLD/',
        \ 'let @/ = "b"',
        \ '2RxopsSubstituteLines /c/NEW/',
        \ a:cmd,
        \ 'call add(s:out, getline(3))'])
endfunction

function! s:suite.substitute_lines_tilde_and_repeat() abort
  call s:assert.equals(s:after_sl('3s/c/~/'), ['a b NEW'])
  call s:assert.equals(s:after_sl('3&&'), ['OLD b c'])
endfunction

" ---------------------------------------------------------------------------
" R6: an error under :silent! and then a failed motion in the same run is a
" failed motion (the typed :g goes on), not an error.

" {1}: Ex lines to run first.
function! s:macro(lines, macro, call, ...) abort
  " not silent Ex mode in Vim: an error inside the macro must not exit it
  return RxopsTestTopLevel((a:0 ? a:1 : []) + [
        \ 'call setline(1, ' . string(a:lines) . ')',
        \ 'let @/ = "foo"',
        \ 'call setreg("q", ' . a:macro . ', "c")',
        \ 'let s:msg = execute("let g:r = " . ' . string(a:call) . ')',
        \ 'call add(s:out, string(getline(1, "$")))',
        \ 'call add(s:out, exists("g:r.code") ? string([g:r.code, g:r.runs, g:r.failed]) : "")',
        \ 'call add(s:out, matchstr(s:msg, "\\[rxops\\][^\\n]*"))'], 1)
endfunction

function! s:suite.macro_silent_error_then_failed_motion() abort
  let l:macro = '":silent! s/zzz//\<CR>f=r!"'
  let l:lines = ['foo 1', 'foo 2 =', 'foo 3']
  call s:assert.equals(s:macro(l:lines, l:macro, 'execute("g//normal! @q")')[0],
        \ string(['foo 1', 'foo 2 !', 'foo 3']))
  call s:assert.equals(s:macro(l:lines, l:macro, 'rxops#macro_matches(1, line("$"), "q")'),
        \ [string(['foo 1', 'foo 2 !', 'foo 3']), string(['macro_failed', 3, 2]),
        \  '[rxops] macro failed on 2 of 3 matches'])
  call s:assert.equals(s:macro(l:lines, l:macro, 'rxops#macro_lines(1, line("$"), 0, "q")'),
        \ [string(['foo 1', 'foo 2 !', 'foo 3']), string(['macro_failed', 3, 2]),
        \  '[rxops] macro failed on 2 of 3 lines'])
  " the last run is the one that fails
  let l:macro = '":silent! call NoSuch()\<CR>f=r!"'
  let l:lines = ['foo 1 =', 'foo 2 =', 'foo 3']
  call s:assert.equals(s:macro(l:lines, l:macro, 'rxops#macro_lines(1, line("$"), 0, "q")'),
        \ [string(['foo 1 !', 'foo 2 !', 'foo 3']), string(['macro_failed', 3, 1]),
        \  '[rxops] macro failed on 1 of 3 lines'])
  call s:assert.equals(s:macro(['foo 1 =', 'foo 2', 'foo 3 ='], l:macro,
        \ 'rxops#macro_matches(1, line("$"), "q")'),
        \ [string(['foo 1 !', 'foo 2', 'foo 3 !']), string(['macro_failed', 3, 1]),
        \  '[rxops] macro failed on 1 of 3 matches'])
endfunction

function! s:suite.macro_error_after_silent_error_still_stops() abort
  let l:macro = '":silent! call NoSuch()\<CR>A!\<Esc>:call NoSuch2()\<CR>"'
  let l:lines = ['foo 1', 'foo 2', 'foo 3']
  call s:assert.equals(s:macro(l:lines, l:macro, 'rxops#macro_matches(1, line("$"), "q")'),
        \ [string(['foo 1', 'foo 2', 'foo 3!']), string(['macro_error', 1, 1]), ''])
  call s:assert.equals(s:macro(l:lines, l:macro, 'rxops#macro_lines(1, line("$"), 0, "q")'),
        \ [string(['foo 1!', 'foo 2', 'foo 3']), string(['macro_error', 1, 1]), ''])
endfunction

" An error whose text is not one line of :messages, or with no message
" history, still stops (review 2, H1).
function! s:assert_stops(macro, label, ...) abort
  let l:pre = a:0 ? a:1 : []
  let l:lines = ['foo 1', 'foo 2', 'foo 3']
  call s:assert.equals(s:macro(l:lines, a:macro, 'rxops#macro_matches(1, line("$"), "q")', l:pre),
        \ [string(['foo 1', 'foo 2', 'foo 3!']), string(['macro_error', 1, 1]), ''], 'MM ' . a:label)
  call s:assert.equals(s:macro(l:lines, a:macro, 'rxops#macro_lines(1, line("$"), 0, "q")', l:pre),
        \ [string(['foo 1!', 'foo 2', 'foo 3']), string(['macro_error', 1, 1]), ''], 'ML ' . a:label)
endfunction

function! s:suite.macro_error_of_any_shape_stops() abort
  call s:assert_stops('"A!\<Esc>:echoerr \"a\\nb\"\<CR>"', 'echoerr with NL')
  call s:assert_stops('"A!\<Esc>:echoerr \"a\\tb\"\<CR>"', 'echoerr with Tab')
  call s:assert_stops('"A!\<Esc>:echoerr \"a\\eb\"\<CR>"', 'echoerr with ESC')
  if has('nvim')
    call s:assert_stops('"A!\<Esc>:lua error(\"x\")\<CR>"', 'lua error')
    call s:assert_stops('"A!\<Esc>:Fail\<CR>"', 'lua command',
          \ ['lua vim.api.nvim_create_user_command("Fail", function() error("failed") end, {})'])
  endif
endfunction

function! s:suite.macro_error_without_history_stops() abort
  if !exists('+messagesopt')
    call s:assert.skip('no messagesopt')
  endif
  for l:n in [0, 1]
    let l:pre = ['set messagesopt=hit-enter,history:' . l:n]
    call s:assert_stops('"A!\<Esc>:call NoSuch()\<CR>"', 'history:' . l:n, l:pre)
    " the same error a second time
    call s:assert_stops('"A!\<Esc>:call NoSuch()\<CR>"', 'history:' . l:n . ' again',
          \ l:pre + ['silent! call execute("call NoSuch()", "")'])
  endfor
endfunction

" The same error {runs} times in a row with history:{n}. E: stopped, f: went
" on over every match (review 3, M1).
function! s:repeat_errors(n, runs) abort
  return RxopsTestTopLevel([
        \ 'set messagesopt=hit-enter,history:' . a:n,
        \ 'let @/ = "a"',
        \ 'call setreg("q", "A!\<Esc>:call NoSuch()\<CR>", "c")',
        \ 'let s:codes = ""',
        \ 'for s:i in range(' . a:runs . ')',
        \ '  %delete _',
        \ '  call setline(1, ["a1", "a2", "a3"])',
        \ '  let s:r = rxops#macro_matches(1, 3, "q")',
        \ '  let s:codes .= s:r.code ==# "macro_error" ? "E" : getline(1) ==# "a1!" ? "f" : "?"',
        \ 'endfor',
        \ 'call add(s:out, s:codes)'], 1)
endfunction

function! s:suite.macro_same_error_repeated_with_small_history() abort
  if !exists('+messagesopt')
    call s:assert.skip('no messagesopt')
  endif
  for l:n in [2, 3, 10, 19]
    call s:assert.equals(s:repeat_errors(l:n, l:n + 3), [repeat('E', l:n + 3)], 'history:' . l:n)
  endfor
  " from 20 on the history tells :silent! apart; history+1 equal errors in
  " a row look like a failed motion (documented in rxops-limitations)
  call s:assert.equals(s:repeat_errors(20, 22), [repeat('E', 20) . 'fE'])
endfunction

" ---------------------------------------------------------------------------
" R7: \c or \C in {pattern} wins over the i / I flag, as in :s.

" The line after :s with {pat} and {flags}, and after SM with the same spec
" inside a match that is the whole line.
function! s:sm_and_s(pat, flags, line) abort
  call RxopsTestBuffer([a:line])
  execute 'silent! keeppatterns s/' . a:pat . '/X/' . a:flags . 'e'
  let l:std = getline(1)
  call RxopsTestBuffer([a:line])
  let @/ = '^.*$'
  silent call rxops#substitute_matches(1, 1, '/' . a:pat . '/X/' . a:flags)
  return [getline(1), l:std]
endfunction

function! s:suite.sm_case_atom_wins_over_flag() abort
  set ignorecase smartcase
  for [l:pat, l:flags, l:line] in [
        \ ['\Cfoo', 'i', 'FOO foo'], ['foo\C', 'i', 'FOO foo'],
        \ ['\Cfoo', 'ig', 'FOO foo FOO'], ['\cfoo', 'I', 'FOO foo'],
        \ ['\cFOO', 'I', 'foo FOO'], ['\Cfoo', 'g', 'FOO foo'],
        \ ['foo', 'i', 'FOO foo'], ['FOO', 'I', 'foo FOO'], ['a\\Cfoo', 'i', 'A\CFOO']]
    let [l:sm, l:std] = s:sm_and_s(l:pat, l:flags, l:line)
    call s:assert.equals(l:sm, l:std, l:pat . ' ' . l:flags)
  endfor
endfunction

" Review 2, L1: \c inside [...] or \%[...] is a character, not a case atom.
function! s:suite.sm_case_atom_inside_collection() abort
  for l:ic in [0, 1]
    let &ignorecase = l:ic
    for [l:pat, l:flags, l:line] in [
          \ ['[\c]x', 'gi', 'cx CX'], ['[\c]x', 'gI', 'cx CX'], ['\%[\c]x', 'gi', 'cx CX'],
          \ ['[\c]x\C', 'gi', 'cx CX'], ['\V[\c]x', 'gi', 'cx [\c]x [\c]X']]
      let [l:sm, l:std] = s:sm_and_s(l:pat, l:flags, l:line)
      call s:assert.equals(l:sm, l:std, l:pat . ' ' . l:flags . ' ic=' . l:ic)
    endfor
  endfor
  set noignorecase nomagic
  for l:pat in ['[\c]x', '\[\c]x']
    let [l:sm, l:std] = s:sm_and_s(l:pat, 'gi', 'cx CX [cx [CX')
    call s:assert.equals(l:sm, l:std, l:pat . ' nomagic')
  endfor
  set magic
  call s:assert.false(rxops#domain#pattern#has_case_atom('[\c]x'))
  call s:assert.true(rxops#domain#pattern#has_case_atom('[\c]x\C'))
  call s:assert.true(rxops#domain#pattern#has_case_atom('\V[\c]'))
  call s:assert.true(rxops#domain#pattern#has_case_atom('[\c', 1))
endfunction

" ---------------------------------------------------------------------------
" R9: the spec is split where :s splits it; a delimiter inside [...] is part
" of the pattern (Vim's skip_regexp()).

let s:subst_text = ['a/b x', 'c]d x', 'e[f x', 'g-h x', 'X/Y x', 'p^q x']

function! s:typed_and_sl(spec) abort
  call RxopsTestBuffer(s:subst_text)
  let @/ = 'x'
  execute 'silent! keeppatterns %g//s' . a:spec
  let l:typed = RxopsTestLines()
  call RxopsTestBuffer(s:subst_text)
  let @/ = 'x'
  silent let l:r = rxops#substitute_lines(1, line('$'), a:spec)
  return [l:r.ok, RxopsTestLines(), l:typed]
endfunction

function! s:suite.spec_split_like_substitute() abort
  for l:magic in [1, 0]
    let &magic = l:magic
    let l:specs = l:magic
          \ ? ['/[/]/', '/[/]/g', '/[/]/Z/', '/b[/]/Z/', '/[^/]/Z/', '/[]/]/Z/g',
          \    '/[^]/]/Z/', '/[\]/]/Z/g', '/[[:punct:]/]/Z/g', '/[[=/=]]/Z/', '/[!-/]/Z/g',
          \    '/\v[/]/Z/', '/\V[/Z/', '/\V\[/]/Z/', '/\[/Z/', '/[\/]/Z/g', '#[#]#Z#',
          \    ']x]Z]', ']c[]]Z]', '/[x/]\v[/]/Z/', '/\%[/]/Z/', '/\_[/]/Z/']
          \ : ['/\[/]/Z/', '/[/Z/', '/\v[/]/Z/', '/[/]/']
    for l:spec in l:specs
      let [l:ok, l:sl, l:typed] = s:typed_and_sl(l:spec)
      call s:assert.equals([l:ok, l:sl], [v:true, l:typed], l:spec . ' magic=' . l:magic)
    endfor
  endfor
  " skip_regexp() follows \v and \V only: with 'nomagic', \m[ is no
  " collection, so :s splits at the first / and fails on the flags 'Z/';
  " so does SL
  set nomagic
  let [l:ok, l:sl, l:typed] = s:typed_and_sl('/\m[/]/Z/')
  call s:assert.equals([l:ok, l:sl], [v:false, l:typed])
  call s:assert.equals(rxops#domain#subst#parse('/\m[/]/Z/', 0, '').code, 'bad_spec')
  call s:assert.equals(rxops#domain#subst#parse('/\m[/]/Z/', 1, '').pat, '\m[/]')
endfunction

function! s:suite.spec_unclosed_collection_is_rejected() abort
  " :s would take the rest of the spec as the pattern
  for l:spec in ['/a[/Z/', '/[/', '/[^/Z/g']
    call RxopsTestBuffer(s:subst_text)
    silent let l:r = rxops#substitute_lines(1, line('$'), l:spec)
    call s:assert.equals([l:r.ok, l:r.code, RxopsTestLines()], [v:false, 'bad_spec', s:subst_text], l:spec)
  endfor
endfunction

function! s:suite.spec_split_for_substitute_matches() abort
  " SM uses the same split: [/] is one pattern
  call RxopsTestBuffer(['a/b x/y'])
  let @/ = '\S\+'
  silent let l:r = rxops#substitute_matches(1, 1, '/[/]/-/g')
  call s:assert.equals([l:r.ok, RxopsTestLines()], [v:true, ['a-b x-y']])
endfunction

" ---------------------------------------------------------------------------
" R11: RxopsSubstituteLines with no matching line says so in a short rxops
" message, not with the unprefixed 'Pattern not found: {pattern}' of :g.

function! s:suite.substitute_lines_no_matching_line() abort
  let @/ = repeat('z', 80)
  let l:tick = b:changedtick
  let l:msg = execute('RxopsSubstituteLines /a/b/')
  call s:assert.equals(split(l:msg, "\n"), ['[rxops] 0 lines changed'])
  call s:assert.equals(b:changedtick, l:tick)
  " a match outside the range does not count
  let @/ = 'x4'
  let l:msg = execute('1,2RxopsSubstituteLines /a/b/')
  call s:assert.equals(split(l:msg, "\n"), ['[rxops] 0 lines changed'])
  call s:assert.equals(RxopsTestLines(), ['a x0', 'a x1', 'a x2', 'a x3', 'a x4'])
  silent let l:r = rxops#substitute_lines(1, 2, '/a/b/')
  call s:assert.equals([l:r.ok, l:r.code, l:r.count, l:r.changed], [v:true, '', 0, v:false])
  " a bad spec is still reported first
  call s:assert.match(execute('RxopsSubstituteLines /a'), '\[rxops\] usage: ')
  " and matching lines still work, with the message of :s
  let @/ = 'x\d'
  silent RxopsSubstituteLines /a/b/
  call s:assert.equals(RxopsTestLines(), ['b x0', 'b x1', 'b x2', 'b x3', 'b x4'])
endfunction

" ---------------------------------------------------------------------------
" Review 2, M1: RxopsMacroLines that fails before its first run (a bad @/)
" leaves 'foldenable' as it was, also inside :try.

function! s:suite.macro_lines_bad_pattern_keeps_foldenable() abort
  call s:fold_1_4()
  let @/ = '\('
  call setreg('q', 'l', 'c')
  let l:caught = ''
  try
    silent let l:r = rxops#macro_lines(1, line('$'), 0, 'q')
  catch
    let l:caught = v:exception
  endtry
  call s:assert.equals(l:caught, '')
  call s:assert.equals([l:r.ok, l:r.code], [v:false, 'vim_error'])
  call s:assert.match(l:r.error, 'E54')
  call s:assert.equals(&l:foldenable, 1)
  call s:assert.equals(s:closed(), [1, 1, 1, 1, -1])
endfunction

" ---------------------------------------------------------------------------
" Additions (second round)

" A: with 'gdefault' each g of RxopsSubstituteMatches toggles from global,
" as for :s and RxopsSubstituteLines.
function! s:suite.sm_gdefault_inverts_g() abort
  set gdefault
  try
    for l:flags in ['', 'g', 'gg', 'gi']
      let [l:sm, l:std] = s:sm_and_s('a', l:flags, 'aaa bab')
      call s:assert.equals(l:sm, l:std, 'flags=' . l:flags)
    endfor
    let [l:sm, l:std] = s:sm_and_s('a', '', 'aaa')
    call s:assert.equals(l:sm, 'XXX')
    call s:assert.true(&gdefault)
  finally
    set nogdefault
  endtry
endfunction

" B: the macro may be the last command line (@:). + and * are accepted
" too; they are not tried here, so that the real clipboard is not read.
function! s:suite.macro_register_colon() abort
  " typed, so that it becomes the last command line
  silent call feedkeys(":call setline('.', getline('.') . '!')\<CR>", 'xt')
  call s:assert.match(getreg(':'), '^call setline')
  call RxopsTestBuffer(['a x0', 'a x1', 'a x2', 'a x3', 'a x4'])
  silent RxopsMacroLines :
  call s:assert.equals(RxopsTestLines(), ['a x0!', 'a x1!', 'a x2!', 'a x3!', 'a x4!'])
  call RxopsTestBuffer(['a x0', 'b', 'a x1'])
  silent RxopsMacroMatches :
  call s:assert.equals(RxopsTestLines(), ['a x0!', 'b', 'a x1!'])
  silent let l:r = rxops#macro_lines(1, 1, 0, '_')
  call s:assert.equals([l:r.code, l:r.error], ['bad_register', 'name'])
endfunction

" C (documented): with 'nomagic', & in the SM {string} is still the whole
" match, while :s takes it literally.
function! s:suite.sm_ampersand_with_nomagic() abort
  set nomagic
  call s:assert.equals(s:sm_and_s('x', '', 'x'), ['X', 'X'])
  call RxopsTestBuffer(['x'])
  let @/ = 'x'
  silent call rxops#substitute_matches(1, 1, '/x/[&]/')
  call s:assert.equals(getline(1), '[x]')
  call RxopsTestBuffer(['x'])
  " :s that depends on 'magic' on purpose
  execute 'silent keeppatterns s/x/[&]/'
  call s:assert.equals(getline(1), '[&]')
endfunction

" D: the state of a macro call cut short by an exception (inside :try) is
" dropped by the next call; the state of calls still running is kept.
function! s:suite.macro_stale_calls_dropped() abort
  let @q = ":call NoSuch()\<CR>"
  for l:i in range(2)
    try
      silent call rxops#macro_lines(1, line('$'), 0, 'q')
    catch /E117/
    endtry
  endfor
  call s:assert.compare(rxops#app#macro#_pending(), '<=', 1)
  " a macro that calls the API again, and reads the count from inside
  call RxopsTestBuffer(['foo 1', 'bar', 'foo 2'])
  let @/ = 'foo'
  call setreg('r', ":let g:rxops_test_pending = rxops#app#macro#_pending()\<CR>A!\<Esc>", 'c')
  call setreg('q', ":call rxops#macro_matches(line('.'), line('.'), 'r')\<CR>", 'c')
  silent let l:r = rxops#macro_lines(1, line('$'), 0, 'q')
  call s:assert.equals(RxopsTestLines(), ['foo 1!', 'bar', 'foo 2!'])
  call s:assert.equals([l:r.ok, l:r.count, l:r.runs], [v:true, 2, 2])
  " the outer call and the inner one
  call s:assert.equals(g:rxops_test_pending, 2)
  call s:assert.equals(rxops#app#macro#_pending(), 0)
  unlet g:rxops_test_pending
endfunction

" E: which clipboard registers are written, from the option value only (the
" real clipboard is not touched).
function! s:suite.clipboard_registers() abort
  let l:cases = [['', []], ['unnamed', ['*']], ['unnamedplus', ['+']],
        \ ['unnamed,unnamedplus', ['+', '*']], ['unnamedplus,unnamed', ['+', '*']],
        \ ['autoselect,unnamedplus', ['+']], ['exclude:cons\|linux,unnamed', ['*']]]
  " a yank, in both editors
  for [l:value, l:regs] in l:cases
    call s:assert.equals(rxops#app#collect#clipboard_regs(l:value, 0, 0), l:regs, l:value)
    call s:assert.equals(rxops#app#collect#clipboard_regs(l:value, 0, 1), l:regs, l:value)
  endfor
  " a delete: Vim writes only + when both are there (clipboard-unnamedplus),
  " Neovim writes both
  for l:value in ['unnamed,unnamedplus', 'unnamedplus,unnamed']
    call s:assert.equals(rxops#app#collect#clipboard_regs(l:value, 1, 0), ['+'], l:value)
    call s:assert.equals(rxops#app#collect#clipboard_regs(l:value, 1, 1), ['+', '*'], l:value)
  endfor
  call s:assert.equals(rxops#app#collect#clipboard_regs('unnamed', 1, 0), ['*'])
  call s:assert.equals(rxops#app#collect#clipboard_regs('unnamedplus', 1, 0), ['+'])
endfunction
