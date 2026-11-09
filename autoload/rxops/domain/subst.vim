" Pure parsing of '/pattern/replacement/flags'. Calls only domain/pattern.

function! s:bad(code, detail) abort
  return {'ok': v:false, 'code': a:code, 'error': a:detail, 'count': 0, 'changed': v:false}
endfunction

" Split {spec} at its first character, where :s splits it. The delimiter may
" be escaped with \, and inside [...] of the pattern it is no delimiter.
" {magic} and {cpo} are 'magic' and 'cpoptions' (they change what [ is).
" Returns a Result with pat / rep / flags / delim.
function! rxops#domain#subst#parse(spec, ...) abort
  let l:magic = a:0 > 0 ? a:1 : 1
  let l:cpo = a:0 > 1 ? a:2 : ''
  " a line break (or another control character but Tab) would end the Ex
  " command built from the spec and start another one
  if a:spec =~# '[\x01-\x08\x0a-\x1f\x7f]'
    return s:bad('bad_spec', 'control character')
  endif
  let l:d = a:spec[0 : 0]
  if l:d ==# '' || l:d =~# '^[[:alnum:]\\"| \t]$' || char2nr(l:d) > 127
    return s:bad('bad_spec', 'delimiter')
  endif
  let l:pend = s:pattern_end(a:spec, 1, l:d, l:magic, l:cpo)
  if l:pend < 0
    return s:bad('bad_spec', 'form')
  endif
  let l:pat = strpart(a:spec, 1, l:pend - 1)
  if l:pat ==# ''
    return s:bad('bad_spec', 'empty pattern')
  endif
  let l:rend = s:string_end(a:spec, l:pend + 1, l:d)
  if l:rend == -2
    return s:bad('bad_spec', 'form')
  endif
  let l:rep = strpart(a:spec, l:pend + 1, (l:rend < 0 ? len(a:spec) : l:rend) - l:pend - 1)
  let l:flags = l:rend < 0 ? '' : strpart(a:spec, l:rend + 1)
  if l:flags !~# '^\a*$'
    return s:bad('bad_spec', 'form')
  endif
  return {'ok': v:true, 'code': '', 'error': '', 'count': 0, 'changed': v:false,
        \ 'pat': l:pat, 'rep': l:rep, 'flags': l:flags, 'delim': l:d}
endfunction

" Index of the delimiter {d} that ends the pattern starting at {i} in {s},
" as Vim's skip_regexp() finds it: [...] (\[...] while not magic) is
" skipped, and \v / \V change what is magic. -1 when there is none, also
" for a [ that is not closed (:s would take the rest as the pattern).
" Bytes are fine here: {d} is ASCII, and no byte of a multibyte character
" is an ASCII character.
function! s:pattern_end(s, i, d, magic, cpo) abort
  let l:n = len(a:s)
  let l:i = a:i
  " 2: \v, 1: magic, 0: not magic, -1: \V
  let l:mymagic = a:magic ? 1 : 0
  while l:i < l:n
    let l:c = a:s[l:i]
    if l:c ==# a:d
      return l:i
    endif
    if (l:c ==# '[' && l:mymagic >= 1) || (l:c ==# '\' && a:s[l:i + 1] ==# '[' && l:mymagic <= 0)
      let l:i = rxops#domain#pattern#skip_anyof(a:s, l:i + 1, a:cpo)
      if l:i >= l:n
        return -1
      endif
      let l:i += 1
    elseif l:c ==# '\' && l:i + 1 < l:n
      let l:i += 1
      if a:s[l:i] ==# 'v'
        let l:mymagic = 2
      elseif a:s[l:i] ==# 'V'
        let l:mymagic = -1
      endif
      let l:i += 1
    else
      let l:i += 1
    endif
  endwhile
  return -1
endfunction

" Index of the delimiter {d} that ends the string starting at {i}, as :s
" finds it (\ escapes the next character). -1: no delimiter (the string
" runs to the end), -2: it ends in a lone \ (that would escape the
" delimiter put after it).
function! s:string_end(s, i, d) abort
  let l:n = len(a:s)
  let l:i = a:i
  while l:i < l:n
    if a:s[l:i] ==# a:d
      return l:i
    endif
    if a:s[l:i] ==# '\'
      if l:i + 1 >= l:n
        return -2
      endif
      let l:i += 1
    endif
    let l:i += 1
  endwhile
  return -1
endfunction

" Flags of the match substitute: only g, i and I.
function! rxops#domain#subst#sm_flags(flags) abort
  if a:flags =~# '^[giI]*$'
    return {'ok': v:true, 'code': '', 'error': '', 'count': 0, 'changed': v:false}
  endif
  return s:bad('bad_flags', a:flags)
endfunction

" \? -> ? (only for the ? delimiter, as :s does). Other escapes stay.
function! s:unescape_question(pat) abort
  let l:out = ''
  let l:i = 0
  let l:n = len(a:pat)
  while l:i < l:n
    if a:pat[l:i] ==# '\' && l:i + 1 < l:n
      let l:out .= a:pat[l:i + 1] ==# '?' ? '?' : a:pat[l:i : l:i + 1]
      let l:i += 2
    else
      let l:out .= a:pat[l:i]
      let l:i += 1
    endif
  endwhile
  return l:out
endfunction

" As in :s, every g toggles, starting from global when {1} ('gdefault') is
" set: without it only an odd number of g means global.
function! rxops#domain#subst#sm_global(flags, ...) abort
  let l:odd = len(substitute(a:flags, '[^g]', '', 'g')) % 2 == 1
  return (a:0 && a:1) ? !l:odd : l:odd
endfunction

" Inner pattern for substitute(): it ignores 'smartcase' and 'magic', so make
" the case and magic that :s would use explicit.
function! rxops#domain#subst#sm_pattern(pat, flags, delim, ic, scs, magic) abort
  let l:p = a:delim ==# '?' ? s:unescape_question(a:pat) : a:pat
  " as in :s, the last of i and I wins, and \c or \C in the pattern wins
  " over both
  let l:case = matchstr(a:flags, '.*\zs[iI]')
  if rxops#domain#pattern#has_case_atom(l:p, a:magic)
    " the pattern fixes the case itself
  elseif l:case ==# 'I'
    let l:p = rxops#domain#pattern#prepend(l:p, '\C')
  elseif l:case ==# 'i'
    let l:p = rxops#domain#pattern#prepend(l:p, '\c')
  else
    let l:p = rxops#domain#pattern#case_rule(l:p, a:ic, a:scs, a:magic)
  endif
  if !a:magic
    let l:p = rxops#domain#pattern#prepend(l:p, '\M')
  endif
  return l:p
endfunction
