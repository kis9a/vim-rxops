let s:suite = themis#suite('command_align')
let s:assert = themis#helper('assert')

function! s:suite.before_each() abort
  call RxopsTestBuffer(['a = 1', 'bb = 2', 'ccc = 3'])
  let @/ = '='
  unlet! g:rxops_test_align
endfunction

function! s:suite.after_each() abort
  if exists(':EasyAlign') == 2
    delcommand EasyAlign
  endif
  unlet! g:rxops_test_align
endfunction

function! s:stub() abort
  command! -range -nargs=* EasyAlign let g:rxops_test_align = [<line1>, <line2>, <q-args>]
endfunction

function! s:suite.without_easyalign() abort
  call s:assert.match(execute('RxopsAlignMatches'), '\[rxops\] vim-easy-align is not loaded')
  silent let l:r = rxops#align_matches(1, 3, '')
  call s:assert.equals([l:r.ok, l:r.code], [v:false, 'no_easyalign'])
endfunction

function! s:suite.prefix_of_another_command_is_not_enough() abort
  command! -nargs=* EasyAlignX echo
  try
    silent let l:r = rxops#align_matches(1, 3, '')
    call s:assert.equals(l:r.code, 'no_easyalign')
  finally
    delcommand EasyAlignX
  endtry
endfunction

function! s:suite.passes_range_and_args() abort
  call s:stub()
  silent RxopsAlignMatches
  call s:assert.equals(g:rxops_test_align, [1, 3, '//'])
  silent 2,3RxopsAlignMatches *
  call s:assert.equals(g:rxops_test_align, [2, 3, '*//'])
  for l:a in ['**', '-', '2', '-2']
    silent execute 'RxopsAlignMatches' l:a
    call s:assert.equals(g:rxops_test_align[2], l:a . '//')
  endfor
endfunction

function! s:suite.rejects_other_args() abort
  call s:stub()
  for l:a in ['* | echo 1', 'x', '0', 'ip']
    let l:msg = execute('RxopsAlignMatches ' . l:a)
    call s:assert.match(l:msg, '\[rxops\] argument must be \*, \*\*, -, N or -N', l:a)
    call s:assert.false(exists('g:rxops_test_align'), l:a)
  endfor
endfunction

function! s:suite.search_state_kept() abort
  " a :EasyAlign that searches and substitutes (as a function, like the
  " real plugin) leaves @/ alone. (The history is the aligner's business:
  " :keeppatterns does not reach the commands a user command runs.)
  let l:out = RxopsTestTopLevel([
        \ 'function! Stub() range abort',
        \ '  execute a:firstline . "," . a:lastline . "s/=/:/"',
        \ '  call search("bb")',
        \ 'endfunction',
        \ 'command! -range -nargs=* EasyAlign <line1>,<line2>call Stub()',
        \ 'call setline(1, ["a = 1", "bb = 2"])',
        \ 'let @/ = "="',
        \ 'RxopsAlignMatches',
        \ 'call add(s:out, string(getline(1, "$")))',
        \ 'call add(s:out, @/)'])
  call s:assert.equals(l:out, [string(['a : 1', 'bb : 2']), '='])
endfunction
