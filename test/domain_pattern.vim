scriptencoding utf-8
let s:suite = themis#suite('domain_pattern')
let s:assert = themis#helper('assert')

function! s:suite.has_upper() abort
  call s:assert.true(rxops#domain#pattern#has_upper('Foo'))
  call s:assert.false(rxops#domain#pattern#has_upper('foo'))
  " escaped letters are atoms, not text
  call s:assert.false(rxops#domain#pattern#has_upper('\Sfoo\u\_S\%V'))
  call s:assert.true(rxops#domain#pattern#has_upper('\Sfoo\uX'))
  call s:assert.true(rxops#domain#pattern#has_upper('ÄB'))
  call s:assert.false(rxops#domain#pattern#has_upper('äb'))
  " very magic: %X and _X are skipped, \X is not
  call s:assert.false(rxops#domain#pattern#has_upper('\v%Vfoo'))
endfunction

function! s:suite.case_rule() abort
  call s:assert.equals(rxops#domain#pattern#case_rule('foo', 0, 0), '\Cfoo')
  call s:assert.equals(rxops#domain#pattern#case_rule('Foo', 0, 1), '\CFoo')
  call s:assert.equals(rxops#domain#pattern#case_rule('Foo', 1, 0), '\cFoo')
  call s:assert.equals(rxops#domain#pattern#case_rule('Foo', 1, 1), '\CFoo')
  call s:assert.equals(rxops#domain#pattern#case_rule('foo', 1, 1), '\cfoo')
  call s:assert.equals(rxops#domain#pattern#case_rule('fo\u', 1, 1), '\cfo\u')
endfunction

function! s:suite.case_rule_keeps_explicit_case() abort
  call s:assert.equals(rxops#domain#pattern#case_rule('foo\C', 1, 1), 'foo\C')
  call s:assert.equals(rxops#domain#pattern#case_rule('\cFoo', 0, 0), '\cFoo')
  " \\c is a backslash and a c
  call s:assert.equals(rxops#domain#pattern#case_rule('a\\c', 0, 0), '\Ca\\c')
endfunction

function! s:suite.case_rule_after_engine() abort
  call s:assert.equals(rxops#domain#pattern#case_rule('\%#=1foo', 1, 0), '\%#=1\cfoo')
endfunction

function! s:suite.flip_case() abort
  call s:assert.equals(rxops#domain#pattern#flip_case('Foo', 1, 1), '\cFoo')
  call s:assert.equals(rxops#domain#pattern#flip_case('foo', 0, 0), '\cfoo')
  call s:assert.equals(rxops#domain#pattern#flip_case('foo\c', 0, 0), 'foo\c')
endfunction

function! s:suite.case_rule_agrees_with_search() abort
  new
  setlocal buftype=nofile
  call setline(1, ['todo', 'TODO', 'Todo'])
  let l:save = [&ignorecase, &smartcase]
  try
    for [l:ic, l:scs, l:pat] in [[1, 1, 'TODO'], [1, 1, 'todo'], [1, 0, 'TODO'], [0, 0, 'Todo']]
      let [&ignorecase, &smartcase] = [l:ic, l:scs]
      let @/ = l:pat
      let l:g = []
      silent global//call add(l:g, line('.'))
      let l:p = rxops#domain#pattern#case_rule(l:pat, l:ic, l:scs)
      let l:m = filter(range(1, 3), 'getline(v:val) =~ l:p')
      call s:assert.equals(l:m, l:g, string([l:ic, l:scs, l:pat]))
    endfor
  finally
    let [&ignorecase, &smartcase] = l:save
    bwipeout!
  endtry
endfunction

function! s:suite.align_args() abort
  for l:a in ['', '*', '**', '-', '2', '-3', ' * ']
    let l:r = rxops#domain#pattern#align_args(l:a)
    call s:assert.true(l:r.ok, string(l:a))
    call s:assert.equals(l:r.args, trim(l:a))
  endfor
  for l:a in ['0', '*|echo 1', 'x', '--', '* 2', '2*']
    call s:assert.equals(rxops#domain#pattern#align_args(l:a).code, 'bad_args', string(l:a))
  endfor
endfunction
