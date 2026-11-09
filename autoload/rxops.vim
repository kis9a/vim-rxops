" Public API. Every function returns a Result
" {ok, code, error, count, changed} and reports it once.

let s:E35 = 'E35: No previous regular expression'

function! s:no_pattern() abort
  call rxops#compat#notify#error(s:E35)
  return {'ok': v:false, 'code': 'no_pattern', 'error': s:E35, 'count': 0, 'changed': v:false}
endfunction

function! s:error_text(r, cmd) abort
  if a:r.code ==# 'bad_spec'
    return 'usage: /pat/rep/[flags]'
  elseif a:r.code ==# 'bad_flags'
    return 'flags must be g, i or I'
  elseif a:r.code ==# 'bad_register'
    return a:r.error ==# 'empty'
          \ ? 'register ' . a:r.reg . ' is empty'
          \ : 'usage: ' . a:cmd . ' {reg}'
  elseif a:r.code ==# 'bad_args'
    return 'argument must be *, **, -, N or -N'
  elseif a:r.code ==# 'no_easyalign'
    return 'vim-easy-align is not loaded'
  elseif a:r.code ==# 'no_pattern'
    return s:E35
  endif
  " vim_error: the exception without its 'Vim(cmd):' part
  return substitute(a:r.error, '^Vim\%((\a\+)\)\=:', '', '')
endfunction

" '1 lines' -> '1 line', '1 matches' -> '1 match'.
function! s:plural(text) abort
  return substitute(a:text, '^1 \(line\|match\)\%(s\|es\)\>', '1 \1', '')
endfunction

" {done} is a printf() format for count > 0, {none} the text for count 0.
" Either may be '' (nothing to say).
function! s:report(r, cmd, done, none) abort
  if !a:r.ok
    call rxops#compat#notify#error(s:error_text(a:r, a:cmd))
  elseif a:r.count == 0
    if a:none !=# ''
      call rxops#compat#notify#info(a:none)
    endif
  elseif a:done !=# ''
    call rxops#compat#notify#info(s:plural(printf(a:done, a:r.count)))
  endif
  return a:r
endfunction

function! rxops#delete_lines(line1, line2) abort
  if @/ ==# ''
    return s:no_pattern()
  endif
  return s:report(rxops#app#edit#delete_lines(a:line1, a:line2, 0),
        \ 'RxopsDeleteLines', '%d lines deleted', 'no lines deleted')
endfunction

function! rxops#keep_lines(line1, line2) abort
  if @/ ==# ''
    return s:no_pattern()
  endif
  return s:report(rxops#app#edit#delete_lines(a:line1, a:line2, 1),
        \ 'RxopsKeepLines', '%d lines deleted', 'no lines deleted')
endfunction

function! rxops#delete_matches(line1, line2) abort
  if @/ ==# ''
    return s:no_pattern()
  endif
  return s:report(rxops#app#edit#delete_matches(a:line1, a:line2),
        \ 'RxopsDeleteMatches', '%d matches deleted', 'no matches')
endfunction

function! rxops#keep_matches(line1, line2) abort
  if @/ ==# ''
    return s:no_pattern()
  endif
  return s:report(rxops#app#edit#keep_matches(a:line1, a:line2),
        \ 'RxopsKeepMatches', '', 'no matches')
endfunction

function! rxops#yank_lines(line1, line2) abort
  if @/ ==# ''
    return s:no_pattern()
  endif
  return s:report(rxops#app#collect#yank_lines(a:line1, a:line2),
        \ 'RxopsYankLines', '%d lines yanked', 'no matches')
endfunction

function! rxops#yank_matches(line1, line2) abort
  if @/ ==# ''
    return s:no_pattern()
  endif
  return s:report(rxops#app#collect#yank_matches(a:line1, a:line2),
        \ 'RxopsYankMatches', '%d matches yanked', 'no matches')
endfunction

function! rxops#list_lines(line1, line2, invert, loc) abort
  if @/ ==# ''
    return s:no_pattern()
  endif
  let l:cmd = (a:loc ? 'RxopsLoclistLines' : 'RxopsQuickfixLines') . (a:invert ? '!' : '')
  let l:r = rxops#app#qf#lines(a:line1, a:line2, a:invert, a:loc, l:cmd . ' /' . @/)
  return s:report(l:r, l:cmd,
        \ a:loc ? '%d lines -> location list (:lopen)' : '%d lines -> quickfix (:copen)', 'no lines')
endfunction

function! rxops#list_matches(line1, line2, loc) abort
  if @/ ==# ''
    return s:no_pattern()
  endif
  let l:cmd = a:loc ? 'RxopsLoclistMatches' : 'RxopsQuickfixMatches'
  let l:r = rxops#app#qf#matches(a:line1, a:line2, a:loc, l:cmd . ' /' . @/)
  return s:report(l:r, l:cmd,
        \ a:loc ? '%d matches -> location list (:lopen)' : '%d matches -> quickfix (:copen)', 'no matches')
endfunction

function! rxops#align_matches(line1, line2, args) abort
  if @/ ==# ''
    return s:no_pattern()
  endif
  return s:report(rxops#app#align#matches(a:line1, a:line2, a:args), 'RxopsAlignMatches', '', '')
endfunction

" Restoring works with an empty @/; only narrowing needs a pattern.
function! rxops#fold_lines() abort
  let l:r = rxops#ui#fold#toggle()
  if !l:r.ok
    call rxops#compat#notify#error(s:error_text(l:r, 'RxopsFoldLines'))
  elseif l:r.action ==# 'narrow' && l:r.count == 0
    call rxops#compat#notify#info('no matches')
  elseif l:r.action ==# 'narrow' && !l:r.exact
    call rxops#compat#notify#warn('folds may differ from :g for this pattern')
  elseif l:r.action ==# 'narrow'
    call rxops#compat#notify#info('narrowed (RxopsFoldLines again restores)')
  elseif l:r.action ==# 'restored'
    call rxops#compat#notify#info('restored folds')
  elseif l:r.action ==# 'restored_opts'
    call rxops#compat#notify#info('restored fold options' . (l:r.manual ? ' (manual folds lost)' : ''))
  elseif l:r.action ==# 'reset'
    call rxops#compat#notify#info('reset folds to global settings')
  endif
  return l:r
endfunction

" A failed motion in a macro is silent in Vim: say how many runs failed.
" After an error Vim has shown it, so add nothing.
function! s:report_macro(r, cmd, unit, done, none) abort
  if a:r.code ==# 'macro_error'
    return a:r
  elseif a:r.code ==# 'macro_failed'
    call rxops#compat#notify#warn(printf('macro failed on %d of %d %s',
          \ a:r.failed, a:r.runs, a:r.runs == 1 ? a:unit : a:unit ==# 'match' ? 'matches' : 'lines'))
    return a:r
  endif
  return s:report(a:r, a:cmd, a:done, a:none)
endfunction

function! rxops#macro_lines(line1, line2, invert, reg) abort
  if @/ ==# ''
    return s:no_pattern()
  endif
  return s:report_macro(rxops#app#macro#lines(a:line1, a:line2, a:invert, a:reg),
        \ 'RxopsMacroLines' . (a:invert ? '!' : ''), 'line', '', '')
endfunction

function! rxops#macro_matches(line1, line2, reg) abort
  if @/ ==# ''
    return s:no_pattern()
  endif
  return s:report_macro(rxops#app#macro#matches(a:line1, a:line2, a:reg),
        \ 'RxopsMacroMatches', 'match', '%d matches', 'no matches')
endfunction

" With no matching line :g would say 'Pattern not found: {pattern}', without
" the prefix and as long as the pattern: say it the rxops way. A bad spec is
" still reported first.
function! rxops#substitute_lines(line1, line2, spec) abort
  if @/ ==# ''
    return s:no_pattern()
  endif
  if rxops#domain#subst#parse(a:spec, &magic, &cpoptions).ok
        \ && !rxops#app#collect#has_line(a:line1, a:line2)
    return s:report({'ok': v:true, 'code': '', 'error': '', 'count': 0, 'changed': v:false},
          \ 'RxopsSubstituteLines', '', '0 lines changed')
  endif
  return s:report(rxops#app#edit#substitute_lines(a:line1, a:line2, a:spec),
        \ 'RxopsSubstituteLines', '', '')
endfunction

function! rxops#substitute_matches(line1, line2, spec) abort
  if @/ ==# ''
    return s:no_pattern()
  endif
  return s:report(rxops#app#edit#substitute_matches(a:line1, a:line2, a:spec),
        \ 'RxopsSubstituteMatches', '%d matches changed', '0 matches changed')
endfunction
