scriptencoding utf-8
let s:suite = themis#suite('domain_subst')
let s:assert = themis#helper('assert')

function! s:parse(spec) abort
  return rxops#domain#subst#parse(a:spec)
endfunction

function! s:suite.basic() abort
  let l:r = s:parse('/a/b/')
  call s:assert.true(l:r.ok)
  call s:assert.equals([l:r.pat, l:r.rep, l:r.flags, l:r.delim], ['a', 'b', '', '/'])
endfunction

function! s:suite.flags() abort
  let l:r = s:parse('/a/b/g')
  call s:assert.equals([l:r.pat, l:r.rep, l:r.flags], ['a', 'b', 'g'])
endfunction

function! s:suite.flags_omitted() abort
  let l:r = s:parse('/a/b')
  call s:assert.true(l:r.ok)
  call s:assert.equals([l:r.pat, l:r.rep, l:r.flags], ['a', 'b', ''])
endfunction

function! s:suite.empty_replacement() abort
  let l:r = s:parse('/a//g')
  call s:assert.equals([l:r.pat, l:r.rep, l:r.flags], ['a', '', 'g'])
endfunction

function! s:suite.other_delimiter() abort
  let l:r = s:parse('#a/b#c#')
  call s:assert.equals([l:r.pat, l:r.rep, l:r.flags, l:r.delim], ['a/b', 'c', '', '#'])
endfunction

function! s:suite.escaped_delimiter_kept() abort
  let l:r = s:parse('/a\/b/c\/d/')
  call s:assert.equals([l:r.pat, l:r.rep], ['a\/b', 'c\/d'])
endfunction

function! s:suite.bracket_delimiter() abort
  let l:r = s:parse(']a]b]')
  call s:assert.true(l:r.ok, string(l:r))
  call s:assert.equals([l:r.pat, l:r.rep], ['a', 'b'])
endfunction

function! s:suite.invalid() abort
  for l:spec in ['', 'a/b/', 'xaxbx', '\a\b\', '"a"b"', '|a|b|', ' a b ', '/a', '//b/', '/a/b/g/', '/a/b/1', 'éaébé']
    let l:r = s:parse(l:spec)
    call s:assert.false(l:r.ok, string(l:spec))
    call s:assert.equals(l:r.code, 'bad_spec', string(l:spec))
  endfor
endfunction

function! s:suite.sm_flags() abort
  for l:f in ['', 'g', 'gi', 'I', 'giI']
    call s:assert.true(rxops#domain#subst#sm_flags(l:f).ok, l:f)
  endfor
  for l:f in ['e', 'gc', 'n']
    call s:assert.equals(rxops#domain#subst#sm_flags(l:f).code, 'bad_flags', l:f)
  endfor
endfunction

function! s:suite.sm_pattern_case() abort
  call s:assert.equals(rxops#domain#subst#sm_pattern('foo', '', '/', 0, 0, 1), '\Cfoo')
  call s:assert.equals(rxops#domain#subst#sm_pattern('foo', '', '/', 1, 0, 1), '\cfoo')
  call s:assert.equals(rxops#domain#subst#sm_pattern('Foo', '', '/', 1, 1, 1), '\CFoo')
  call s:assert.equals(rxops#domain#subst#sm_pattern('foo', '', '/', 1, 1, 1), '\cfoo')
  call s:assert.equals(rxops#domain#subst#sm_pattern('Foo', 'i', '/', 1, 1, 1), '\cFoo')
  call s:assert.equals(rxops#domain#subst#sm_pattern('foo', 'gI', '/', 1, 0, 1), '\Cfoo')
endfunction

function! s:suite.sm_pattern_keeps_escapes() abort
  call s:assert.equals(rxops#domain#subst#sm_pattern('a\.b', '', '.', 0, 0, 1), '\Ca\.b')
  call s:assert.equals(rxops#domain#subst#sm_pattern('a\/b', '', '/', 0, 0, 1), '\Ca\/b')
  call s:assert.equals(rxops#domain#subst#sm_pattern('a\?b\\', '', '?', 0, 0, 1), '\Ca?b\\')
endfunction

function! s:suite.sm_pattern_nomagic_and_engine() abort
  call s:assert.equals(rxops#domain#subst#sm_pattern('a.b', '', '/', 0, 0, 0), '\M\Ca.b')
  call s:assert.equals(rxops#domain#subst#sm_pattern('\%#=1ab', '', '/', 0, 0, 1), '\%#=1\Cab')
endfunction

function! s:suite.control_characters_rejected() abort
  " a line break would end the Ex command built from the spec
  for l:spec in ["/foo/X\nlet g:x=1\n/e", "/a/b\r/", "/a\x01/b/", "/a/b/g\x7f", "/a/\x1b/"]
    let l:r = s:parse(l:spec)
    call s:assert.equals([l:r.ok, l:r.code], [v:false, 'bad_spec'], string(l:spec))
  endfor
  " Tab is ordinary text
  call s:assert.equals(s:parse("/a\tb/c/").pat, "a\tb")
endfunction

function! s:suite.sm_global_parity() abort
  call s:assert.equals(map(['', 'g', 'gg', 'ggg', 'gig', 'Ig'], 'rxops#domain#subst#sm_global(v:val)'),
        \ [0, 1, 0, 1, 0, 1])
endfunction

function! s:suite.sm_pattern_last_case_flag_wins() abort
  call s:assert.equals(rxops#domain#subst#sm_pattern('a', 'iI', '/', 0, 0, 1), '\Ca')
  call s:assert.equals(rxops#domain#subst#sm_pattern('a', 'Ii', '/', 0, 0, 1), '\ca')
  call s:assert.equals(rxops#domain#subst#sm_pattern('a', 'gIgi', '/', 0, 0, 1), '\ca')
endfunction
