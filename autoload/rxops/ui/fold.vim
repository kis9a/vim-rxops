" Fold away the lines that do not match, in the current window.
" State: w:rxops_fold = {bufnr: {pattern, bufnr, path, view, opts}}, one
" entry per buffer narrowed in this window: another buffer in the same
" window keeps the state of the first one.

let s:prefix = 'rxops#ui#fold#level('
let s:opts = ['foldexpr', 'foldlevel', 'foldminlines', 'foldenable', 'foldmethod']

" 'foldexpr': matching lines are level 0, runs of other lines one fold.
function! rxops#ui#fold#level(pat) abort
  return getline(v:lnum) =~ a:pat ? 0 : 1
endfunction

function! s:ok(action, count, exact) abort
  return {'ok': v:true, 'code': '', 'error': '', 'count': a:count, 'changed': v:false,
        \ 'action': a:action, 'exact': a:exact}
endfunction

function! s:ours() abort
  return stridx(&l:foldexpr, s:prefix) == 0
endfunction

" After switching to manual, folds made by the expr would stay: drop them.
function! s:drop_if_manual() abort
  if &l:foldmethod ==# 'manual'
    normal! zE
  endif
endfunction

function! s:reset_local() abort
  setlocal foldexpr< foldlevel< foldminlines< foldenable< foldmethod<
  call s:drop_if_manual()
endfunction

function! s:set_opts(opts) abort
  for l:o in s:opts
    execute 'let &l:' . l:o . ' = a:opts[l:o]'
  endfor
endfunction

" Only a named normal buffer can be restored with :mkview (an unnamed or
" 'buftype' buffer gets ':enew' in the view file). Others keep the options.
function! s:save_state() abort
  let l:opts = {}
  for l:o in s:opts
    let l:opts[l:o] = eval('&l:' . l:o)
  endfor
  let l:view = ''
  if &buftype ==# '' && bufname('') !=# ''
    let l:file = tempname()
    let l:vop = &viewoptions
    set viewoptions=folds
    try
      execute 'silent mkview!' fnameescape(l:file)
      let l:view = l:file
    catch
      " fall back to the options only
    finally
      let &viewoptions = l:vop
    endtry
  endif
  return {'pattern': @/, 'bufnr': bufnr(''), 'path': expand('%:p'), 'view': l:view, 'opts': l:opts}
endfunction

function! s:discard(state) abort
  if a:state.view !=# ''
    call delete(a:state.view)
  endif
endfunction

" Lines of a view file (viewoptions=folds) that restore folds. Everything
" else is dropped: argglobal, the :buffer / :edit of the file (which switches
" buffers or fails with E37 after :file or :saveas), the terminal block,
" set hlsearch, doautoall SessionLoadPost, the 'scrolloff' save.
" Vim 9.2 writes 'sil! :2,3fold', Neovim 'sil! 2,3fold', Vim 9.1 '2,3fold';
" ':' and 'silent!' are optional in every form.
let s:sil = '\%(sil\%[ent]!\s*\)\='
let s:fold_line = '^\s*' . s:sil . ':\=\(\d\+\),\(\d\+\)fo\%[ld]\s*$'
let s:zcmd_line = '^\s*' . s:sil . ':\=norm\%[al]!\s*z[EoOcC]\s*$'
let s:goto_line = '^\s*:\=\(\d\+\)\s*$'
let s:view_keep = '^\s*\%(vim9script\|setl\%[ocal]\s\+\%(no\)\=\%(fold\a*\|fd[meiln]\|fmr\|fml\|fen\)\>.*'
      \ . '\|\%(let\s\+\)\=&fdl\s*=\s*&fdl\)\s*$'

function! s:view_line_kept(line) abort
  return a:line =~# s:view_keep || a:line =~# s:fold_line
        \ || a:line =~# s:zcmd_line || a:line =~# s:goto_line
endfunction

" Also drop commands for lines that no longer exist (lines may have been
" deleted while narrowed): ':N,Mfold' past the end gives E16 even under
" silent!, and ':N' past the end is followed by a zo / zc for it.
function! s:clip_view(lines) abort
  let l:last = line('$')
  let l:out = []
  let l:skip_next = 0
  for l:line in a:lines
    if !s:view_line_kept(l:line)
      continue
    endif
    if l:skip_next && l:line =~# s:zcmd_line && l:line !~# 'zE'
      let l:skip_next = 0
      continue
    endif
    let l:skip_next = 0
    let l:fold = matchlist(l:line, s:fold_line)
    if !empty(l:fold) && str2nr(l:fold[2]) > l:last
      continue
    endif
    let l:goto = matchlist(l:line, s:goto_line)
    if !empty(l:goto) && str2nr(l:goto[1]) > l:last
      let l:skip_next = 1
      continue
    endif
    call add(l:out, l:line)
  endfor
  return l:out
endfunction

" 'restored' or 'restored_opts'. The view is used only while the buffer is
" still the same file (not after :file or :saveas).
function! s:restore(state) abort
  if a:state.view !=# '' && a:state.path ==# expand('%:p')
    " options first: setting 'foldlevel' after the view would open or close
    " the folds the view has just set
    call s:set_opts(a:state.opts)
    let l:file = tempname()
    try
      call writefile(s:clip_view(readfile(a:state.view)), l:file)
      execute 'silent source' fnameescape(l:file)
    finally
      call delete(a:state.view)
      call delete(l:file)
    endtry
    return 'restored'
  endif
  call s:discard(a:state)
  call s:set_opts(a:state.opts)
  call s:drop_if_manual()
  return 'restored_opts'
endfunction

function! s:matching(pat) abort
  return filter(range(1, line('$')), 'getline(v:val) =~ a:pat')
endfunction

" 'foldexpr' tests one line with =~, which knows neither 'smartcase' nor the
" flags @/ carries (a * search ignores 'smartcase'). Use the explicit-case
" pattern that selects the same lines as :g//, or the rule when neither does.
function! s:choose(pat) abort
  let l:g = []
  let l:marks = rxops#app#collect#marks_save()
  try
    silent keepjumps keeppatterns global//call add(l:g, line('.'))
  finally
    call rxops#app#collect#marks_restore(l:marks)
  endtry
  let l:cands = [rxops#domain#pattern#case_rule(a:pat, &ignorecase, &smartcase),
        \ rxops#domain#pattern#flip_case(a:pat, &ignorecase, &smartcase)]
  for l:p in l:cands
    if s:matching(l:p) == l:g
      return {'pattern': l:p, 'count': len(l:g), 'exact': 1}
    endif
  endfor
  return {'pattern': l:cands[0], 'count': len(l:g), 'exact': 0}
endfunction

function! s:apply(pat) abort
  let &l:foldexpr = s:prefix . string(a:pat) . ')'
  setlocal foldmethod=expr foldlevel=0 foldminlines=0 foldenable
  normal! zX
endfunction

" The state of the current buffer in this window, or {}. States of buffers
" that are gone are dropped with their view files.
function! s:state() abort
  if !exists('w:rxops_fold')
    return {}
  endif
  for l:nr in keys(w:rxops_fold)
    if !bufexists(str2nr(l:nr))
      call s:discard(remove(w:rxops_fold, l:nr))
    endif
  endfor
  return get(w:rxops_fold, bufnr(''), {})
endfunction

function! s:set_state(state) abort
  if !exists('w:rxops_fold')
    let w:rxops_fold = {}
  endif
  let w:rxops_fold[a:state.bufnr] = a:state
endfunction

function! s:unset_state() abort
  call remove(w:rxops_fold, bufnr(''))
  if empty(w:rxops_fold)
    unlet w:rxops_fold
  endif
endfunction

function! s:toggle() abort
  let l:state = s:state()
  if empty(l:state)
    if s:ours()
      " a :split copy of a narrowed window has no saved state
      call s:reset_local()
      return s:ok('reset', 0, 1)
    endif
    if @/ ==# ''
      return {'ok': v:false, 'code': 'no_pattern', 'error': '', 'count': 0, 'changed': v:false}
    endif
    let l:c = s:choose(@/)
    if l:c.count == 0
      return s:ok('narrow', 0, 1)
    endif
    call s:set_state(s:save_state())
    call s:apply(l:c.pattern)
    return s:ok('narrow', l:c.count, l:c.exact)
  endif
  if l:state.pattern ==# @/ || @/ ==# ''
    call s:unset_state()
    let l:r = s:ok(s:restore(l:state), 0, 1)
    let l:r.manual = l:state.opts.foldmethod ==# 'manual'
    return l:r
  endif
  " another search: narrow again, keep the saved original
  let l:c = s:choose(@/)
  let l:state.pattern = @/
  call s:apply(l:c.pattern)
  return s:ok('narrow', l:c.count, l:c.exact)
endfunction

function! rxops#ui#fold#toggle() abort
  let l:view = winsaveview()
  try
    return s:toggle()
  catch
    return {'ok': v:false, 'code': 'vim_error', 'error': v:exception, 'count': 0, 'changed': v:false}
  finally
    call winrestview(l:view)
  endtry
endfunction
