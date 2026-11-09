" Pure helpers for search patterns. Calls nothing outside this file.

" Insert {atom} at the front of {pat}, but after a leading \%#=N (E1281).
function! rxops#domain#pattern#prepend(pat, atom) abort
  let l:n = len(matchstr(a:pat, '^\\%#=\d'))
  return strpart(a:pat, 0, l:n) . a:atom . strpart(a:pat, l:n)
endfunction

" True when {pat} has a \c or \C atom: not escaped, and not inside [...]
" or \%[...] (there it is a character). {1}: 'magic' (default on); \v, \m,
" \M and \V in {pat} change it as in the regexp. A [ that is not closed is
" a plain character.
function! rxops#domain#pattern#has_case_atom(pat, ...) abort
  let l:n = len(a:pat)
  let l:i = 0
  " 2: \v, 1: magic, 0: not magic, -1: \V
  let l:mymagic = (a:0 ? a:1 : 1) ? 1 : 0
  while l:i < l:n
    let l:c = a:pat[l:i]
    let l:next = a:pat[l:i + 1]
    if (l:c ==# '[' && l:mymagic >= 1) || (l:c ==# '\' && l:next ==# '[' && l:mymagic <= 0)
      let l:end = rxops#domain#pattern#skip_anyof(a:pat, l:i + 1, '')
      let l:i = l:end < l:n ? l:end + 1 : l:i + 1
    elseif l:c ==# '\' && l:next !=# ''
      if l:next ==# 'c' || l:next ==# 'C'
        return 1
      endif
      let l:mymagic = get({'v': 2, 'm': 1, 'M': 0, 'V': -1}, l:next, l:mymagic)
      let l:i += 2
    else
      let l:i += 1
    endif
  endwhile
  return 0
endfunction

let s:classes = '\[:\%(alnum\|alpha\|blank\|cntrl\|digit\|graph\|lower\|print\|punct\|space'
      \ . '\|upper\|xdigit\|tab\|return\|backspace\|escape\|ident\|keyword\|fname\):\]'

" Length of the [:class:], [=x=] or [.x.] at {i} in {s}, or 0.
function! s:class_len(s, i) abort
  let l:class = matchstr(a:s, '\C\%' . (a:i + 1) . 'c' . s:classes)
  if l:class !=# ''
    return len(l:class)
  endif
  let l:kind = a:s[a:i + 1]
  if (l:kind ==# '=' || l:kind ==# '.') && a:i + 2 < len(a:s)
    let l:l = len(strcharpart(strpart(a:s, a:i + 2), 0, 1))
    if a:s[a:i + 2 + l:l] ==# l:kind && a:s[a:i + 3 + l:l] ==# ']'
      return l:l + 4
    endif
  endif
  return 0
endfunction

" Index of the ] that ends the collection whose items start at {i} (just
" after the [) in {s}, as Vim's skip_anyof(); len({s}) when there is none.
" {cpo} is 'cpoptions' (its l and \ flags change what \ means inside).
function! rxops#domain#pattern#skip_anyof(s, i, cpo) abort
  let l:n = len(a:s)
  let l:i = a:i
  let l:bsl = stridx(a:cpo, '\') >= 0
  let l:lit = stridx(a:cpo, 'l') >= 0
  if a:s[l:i] ==# '^'
    let l:i += 1
  endif
  if a:s[l:i] ==# ']' || a:s[l:i] ==# '-'
    let l:i += 1
  endif
  while l:i < l:n && a:s[l:i] !=# ']'
    let l:c = a:s[l:i]
    let l:next = a:s[l:i + 1]
    if l:c ==# '-'
      let l:i += 1
      if l:i < l:n && a:s[l:i] !=# ']'
        let l:i += len(strcharpart(strpart(a:s, l:i), 0, 1))
      endif
    elseif l:c ==# '\' && !l:bsl && l:next !=# ''
          \ && (stridx("]^-n\\", l:next) >= 0 || (!l:lit && stridx('nrtebdoxuU', l:next) >= 0))
      let l:i += 2
    elseif l:c ==# '['
      let l:i += max([s:class_len(a:s, l:i), 1])
    else
      let l:i += 1
    endif
  endwhile
  return l:i
endfunction

" Last magic modifier wins, as in Vim's skip_regexp(): 1 when it is \v.
function! s:very_magic(pat) abort
  let l:vm = 0
  let l:i = 0
  let l:n = len(a:pat)
  while l:i < l:n
    if a:pat[l:i] ==# '\' && l:i + 1 < l:n
      let l:d = a:pat[l:i + 1]
      if l:d =~# '^[vmMV]$'
        let l:vm = l:d ==# 'v'
      endif
      let l:i += 2
    else
      let l:i += 1
    endif
  endwhile
  return l:vm
endfunction

" Same rule as Vim's pat_has_uppercase(): \x, \_x and \%x do not count.
function! rxops#domain#pattern#has_upper(pat) abort
  let l:chars = split(a:pat, '\zs')
  let l:n = len(l:chars)
  let l:vm = s:very_magic(a:pat)
  let l:i = 0
  while l:i < l:n
    let l:c = l:chars[l:i]
    if l:c ==# '\' && !l:vm
      let l:i += (l:i + 2 < l:n && l:chars[l:i + 1] =~# '^[_%]$') ? 3 : 2
    elseif l:vm && l:c =~# '^[_%]$'
      let l:i += 2
    elseif l:c !=# tolower(l:c)
      return 1
    else
      let l:i += 1
    endif
  endwhile
  return 0
endfunction

" {pat} with an explicit \c or \C that reproduces 'ignorecase' / 'smartcase'.
function! rxops#domain#pattern#case_rule(pat, ic, scs, ...) abort
  if rxops#domain#pattern#has_case_atom(a:pat, a:0 ? a:1 : 1)
    return a:pat
  endif
  let l:upper = !a:ic || (a:scs && rxops#domain#pattern#has_upper(a:pat))
  return rxops#domain#pattern#prepend(a:pat, l:upper ? '\C' : '\c')
endfunction

" The other choice of case_rule(); {pat} itself when it fixes the case.
function! rxops#domain#pattern#flip_case(pat, ic, scs) abort
  if rxops#domain#pattern#has_case_atom(a:pat)
    return a:pat
  endif
  let l:upper = !a:ic || (a:scs && rxops#domain#pattern#has_upper(a:pat))
  return rxops#domain#pattern#prepend(a:pat, l:upper ? '\c' : '\C')
endfunction

" Arguments of the align command: '', *, **, -, N or -N.
function! rxops#domain#pattern#align_args(args) abort
  let l:a = trim(a:args)
  if l:a =~# '^\%(\*\*\=\|-\|-\=[1-9]\d*\)\=$'
    return {'ok': v:true, 'code': '', 'error': '', 'count': 0, 'changed': v:false, 'args': l:a}
  endif
  return {'ok': v:false, 'code': 'bad_args', 'error': a:args, 'count': 0, 'changed': v:false}
endfunction
