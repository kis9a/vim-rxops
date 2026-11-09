let s:suite = themis#suite('command_subst')
let s:assert = themis#helper('assert')

let s:text = ['id=foo-123 name=foo', 'name=foo-456', 'id=foo-789 name=foo']

function! s:suite.before_each() abort
  call RxopsTestBuffer(s:text)
  let @/ = 'id=\S\+'
endfunction

function! s:suite.after_each() abort
  set noignorecase nosmartcase magic
endfunction

function! s:suite.substitute_matches_example() abort
  let l:msg = execute('RxopsSubstituteMatches /foo/bar/g')
  call s:assert.equals(RxopsTestLines(), ['id=bar-123 name=foo', 'name=foo-456', 'id=bar-789 name=foo'])
  call s:assert.match(l:msg, '\[rxops\] 2 matches changed')
  call s:assert.equals(@/, 'id=\S\+')
endfunction

function! s:suite.substitute_lines_example() abort
  silent RxopsSubstituteLines /foo/bar/g
  call s:assert.equals(RxopsTestLines(), ['id=bar-123 name=bar', 'name=foo-456', 'id=bar-789 name=bar'])
  " put back even for a caller that is a function (this test)
  call s:assert.equals(@/, 'id=\S\+')
endfunction

function! s:suite.top_level_search_unchanged() abort
  let l:out = RxopsTestTopLevel([
        \ 'call setline(1, ' . string(s:text) . ')',
        \ 'let @/ = ''id=\S\+''',
        \ 'RxopsSubstituteMatches /foo/bar/g',
        \ 'call add(s:out, @/)',
        \ 'call add(s:out, string(getline(1, "$")))',
        \ '%d _',
        \ 'call setline(1, ' . string(s:text) . ')',
        \ 'RxopsSubstituteLines /foo/bar/g',
        \ 'call add(s:out, @/)',
        \ 'call add(s:out, string(getline(1, "$")))',
        \ 'RxopsDeleteMatches',
        \ 'RxopsQuickfixLines',
        \ 'RxopsKeepLines',
        \ 'call add(s:out, @/)',
        \ ])
  call s:assert.equals(l:out, [
        \ 'id=\S\+', string(['id=bar-123 name=foo', 'name=foo-456', 'id=bar-789 name=foo']),
        \ 'id=\S\+', string(['id=bar-123 name=bar', 'name=foo-456', 'id=bar-789 name=bar']),
        \ 'id=\S\+'])
endfunction

function! s:suite.range() abort
  silent 2,3RxopsSubstituteMatches /foo/bar/g
  call s:assert.equals(RxopsTestLines(), ['id=foo-123 name=foo', 'name=foo-456', 'id=bar-789 name=foo'])
  call RxopsTestBuffer(s:text)
  silent 1,2RxopsSubstituteLines /foo/bar/g
  call s:assert.equals(RxopsTestLines(), ['id=bar-123 name=bar', 'name=foo-456', 'id=foo-789 name=foo'])
endfunction

function! s:suite.undo_once() abort
  silent RxopsSubstituteMatches /foo/bar/g
  silent normal! u
  call s:assert.equals(RxopsTestLines(), s:text)
  call RxopsTestCloseUndo()
  silent RxopsSubstituteLines /foo/bar/g
  silent normal! u
  call s:assert.equals(RxopsTestLines(), s:text)
endfunction

function! s:suite.g_flag() abort
  call RxopsTestBuffer(['id=aa-aa x=aa'])
  silent RxopsSubstituteMatches /a/b/
  call s:assert.equals(RxopsTestLines(), ['id=ba-aa x=aa'])
  call RxopsTestBuffer(['id=aa-aa x=aa'])
  silent RxopsSubstituteMatches /a/b/g
  call s:assert.equals(RxopsTestLines(), ['id=bb-bb x=aa'])
endfunction

function! s:suite.case_flags() abort
  call RxopsTestBuffer(['id=Foo-foo'])
  silent RxopsSubstituteMatches /foo/x/gi
  call s:assert.equals(RxopsTestLines(), ['id=x-x'])
  call RxopsTestBuffer(['id=Foo-foo'])
  set ignorecase
  silent RxopsSubstituteMatches /foo/x/gI
  call s:assert.equals(RxopsTestLines(), ['id=Foo-x'])
endfunction

function! s:suite.smartcase() abort
  call RxopsTestBuffer(['id=Foo-foo'])
  set ignorecase smartcase
  silent RxopsSubstituteMatches /Foo/x/g
  call s:assert.equals(RxopsTestLines(), ['id=x-foo'])
  call RxopsTestBuffer(['id=Foo-foo'])
  silent RxopsSubstituteMatches /foo/x/g
  call s:assert.equals(RxopsTestLines(), ['id=x-x'])
endfunction

function! s:suite.escaped_slash_and_other_delimiters() abort
  call RxopsTestBuffer(['id=a/b/c'])
  silent RxopsSubstituteMatches /a\/b/X\/Y/
  call s:assert.equals(RxopsTestLines(), ['id=X/Y/c'])
  call RxopsTestBuffer(['id=a/b/c'])
  silent RxopsSubstituteMatches #/#-#g
  call s:assert.equals(RxopsTestLines(), ['id=a-b-c'])
endfunction

" The match substitute reads the delimiter escapes as :s does, so it agrees
" with the line substitute.
function! s:suite.delimiters_agree_with_substitute_lines() abort
  for l:spec in ['.a\.b.X.g', '+a\+b+X+', '+a\+b+X+g', '?a\?b?X?g', '#a\#b#X#g']
    call RxopsTestBuffer(['id=a.b-aab-a?b-a#b-ab'])
    silent execute 'RxopsSubstituteMatches ' . l:spec
    let l:sm = getline(1)
    call RxopsTestBuffer(['id=a.b-aab-a?b-a#b-ab'])
    silent execute 'RxopsSubstituteLines ' . l:spec
    call s:assert.equals(l:sm, getline(1), l:spec)
  endfor
  call RxopsTestBuffer(['id=a.b-axb'])
  silent RxopsSubstituteMatches .a\.b.X.g
  call s:assert.equals(RxopsTestLines(), ['id=X-axb'])
endfunction

function! s:suite.nomagic() abort
  call RxopsTestBuffer(['id=a.b-axb'])
  set nomagic
  silent RxopsSubstituteMatches /a.b/X/g
  call s:assert.equals(RxopsTestLines(), ['id=X-axb'])
endfunction

function! s:suite.bad_spec_leaves_buffer() abort
  let l:tick = b:changedtick
  call s:assert.match(execute('RxopsSubstituteMatches foo'),
        \ '\[rxops\] usage: /pat/rep/\[flags\]')
  call s:assert.match(execute('RxopsSubstituteLines //x/'),
        \ '\[rxops\] usage: /pat/rep/\[flags\]')
  call s:assert.match(execute('RxopsSubstituteMatches /foo/bar/ge'), '\[rxops\] flags must be g, i or I')
  call s:assert.equals(b:changedtick, l:tick)
  silent let l:r = rxops#substitute_matches(1, line('$'), '/foo/bar/x')
  call s:assert.equals([l:r.ok, l:r.code, l:r.changed], [v:false, 'bad_flags', v:false])
endfunction

function! s:suite.substitute_lines_without_inner_match() abort
  " 'e' is added: lines without the inner pattern are no error
  silent let l:r = rxops#substitute_lines(1, line('$'), '/123/X/')
  call s:assert.true(l:r.ok, string(l:r))
  call s:assert.equals(RxopsTestLines(), ['id=foo-X name=foo', 'name=foo-456', 'id=foo-789 name=foo'])
endfunction

function! s:suite.no_change_count() abort
  call s:assert.match(execute('RxopsSubstituteMatches /zzz/bar/g'), '\[rxops\] 0 matches changed')
endfunction

function! s:suite.expression_replacement() abort
  silent RxopsSubstituteMatches /\d\+/\=submatch(0)*2/
  call s:assert.equals(RxopsTestLines(), ['id=foo-246 name=foo', 'name=foo-456', 'id=foo-1578 name=foo'])
endfunction

function! s:suite.bar_is_literal() abort
  silent RxopsSubstituteLines /name/a|b/
  call s:assert.equals(getline(1), 'id=foo-123 a|b=foo')
endfunction

function! s:suite.vim_error() abort
  let @/ = '\('
  silent let l:r = rxops#substitute_matches(1, line('$'), '/a/b/')
  call s:assert.equals(l:r.code, 'vim_error')
  call s:assert.equals(RxopsTestLines(), s:text)
endfunction

function! s:suite.substitute_lines_nested_keeps_search_and_history() abort
  let l:hist = histnr('/')
  silent call rxops#substitute_lines(1, line('$'), '/foo/bar/g')
  call s:assert.equals([@/, histnr('/')], ['id=\S\+', l:hist])
endfunction

function! s:suite.substitute_matches_with_gdefault() abort
  set gdefault
  try
    silent RxopsSubstituteMatches /foo/bar/
    call s:assert.equals(RxopsTestLines(), ['id=bar-123 name=foo', 'name=foo-456', 'id=bar-789 name=foo'])
  finally
    set nogdefault
  endtry
endfunction

" Vim's own :s is the oracle: SM on a match that covers the whole line must
" give what :s gives on the line.
function! s:native_vs_sm(line, spec, opts) abort
  execute 'set' a:opts
  try
    call RxopsTestBuffer([a:line])
    execute 'silent! s' . a:spec
    let l:native = getline(1)
    call RxopsTestBuffer([a:line])
    let @/ = '.*'
    silent call rxops#substitute_matches(1, 1, a:spec)
    return [l:native, getline(1)]
  finally
    set noignorecase nosmartcase magic nogdefault
  endtry
endfunction

function! s:suite.agrees_with_native_substitute() abort
  for [l:line, l:spec, l:opts] in [
        \ ['FOO foo Foo', '/\Vfoo/X/g', 'ignorecase smartcase'],
        \ ['FOO foo Foo', '/\vfoo/X/g', 'ignorecase smartcase'],
        \ ['FOO foo Foo', '/\VFoo/X/g', 'ignorecase smartcase'],
        \ ['FOO foo Foo', '/\Sfoo/X/g', 'ignorecase smartcase'],
        \ ['FOO foo Foo', '/[[:upper:]]oo/X/g', 'ignorecase smartcase'],
        \ ['a?b ab b', '?a\?b?X?g', 'noignorecase'],
        \ ['a?b ab b', '?\va\?b?X?g', 'noignorecase'],
        \ ['a.b axb', '/a.b/X/g', 'nomagic'],
        \ ['aaaa', '/a/X/g', 'noignorecase'],
        \ ['aaaa', '/a/X/gg', 'noignorecase'],
        \ ['aaaa', '/a/X/ggg', 'noignorecase'],
        \ ['aA aA', '/a/X/giI', 'noignorecase'],
        \ ['aA aA', '/a/X/gIi', 'noignorecase'],
        \ ['aA aA', '/a/X/iIg', 'ignorecase'],
        \ ['aA aA', '/a/X/Iig', 'noignorecase'],
        \ ]
    let [l:native, l:sm] = s:native_vs_sm(l:line, l:spec, l:opts)
    call s:assert.equals(l:sm, l:native, string([l:line, l:spec, l:opts]))
  endfor
endfunction

function! s:suite.control_characters_cannot_inject() abort
  " regression: a raw line break in the spec ran as another Ex command
  let g:rxops_injected = 0
  for l:F in [function('rxops#substitute_lines'), function('rxops#substitute_matches')]
    call RxopsTestBuffer(['foo'])
    let @/ = 'foo'
    silent let l:r = l:F(1, line('$'), "/foo/X\nlet g:rxops_injected=1\n/e")
    call s:assert.equals([l:r.ok, l:r.code, g:rxops_injected, getline(1)], [v:false, 'bad_spec', 0, 'foo'])
  endfor
  for l:cmd in ['RxopsSubstituteLines', 'RxopsSubstituteMatches']
    call RxopsTestBuffer(['foo'])
    let @/ = 'foo'
    silent execute l:cmd . " /foo/X\rlet g:rxops_injected=1\r/e"
    call s:assert.equals([g:rxops_injected, getline(1)], [0, 'foo'], l:cmd)
  endfor
  unlet g:rxops_injected
endfunction
