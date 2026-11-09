" Send matching lines / matches to the quickfix or location list.

function! s:set(loc, title, items) abort
  try
    let l:what = {'title': a:title, 'items': a:items}
    if a:loc
      call setloclist(0, [], ' ', l:what)
    else
      call setqflist([], ' ', l:what)
    endif
  catch
    return rxops#app#collect#err('vim_error', v:exception)
  endtry
  return {'ok': v:true, 'code': '', 'error': '', 'count': len(a:items), 'changed': v:false}
endfunction

" One item per line. The column is the first match on the line, found with
" the same pattern state as :g ({invert}: non-matching lines, column 1).
function! rxops#app#qf#lines(l1, l2, invert, loc, title) abort
  let l:items = []
  let l:col = a:invert ? '1' : 'max([searchpos("", "cnW", line("."))[1], 1])'
  let l:view = winsaveview()
  let l:marks = rxops#app#collect#marks_save()
  let l:fold = rxops#app#collect#fold_off()
  try
    silent execute 'keepjumps keeppatterns ' . a:l1 . ',' . a:l2 . (a:invert ? 'v' : 'g')
          \ . '//call add(l:items, '
          \ . '{"bufnr": bufnr(""), "lnum": line("."), "col": ' . l:col . ', "text": getline(".")})'
  catch
    return rxops#app#collect#err('vim_error', v:exception)
  finally
    call rxops#app#collect#fold_restore(l:fold)
    call winrestview(l:view)
    call rxops#app#collect#marks_restore(l:marks)
  endtry
  if empty(l:items)
    return {'ok': v:true, 'code': '', 'error': '', 'count': 0, 'changed': v:false}
  endif
  return s:set(a:loc, a:title, l:items)
endfunction

" One item per match (three matches on a line are three items), as :s//g
" finds them.
function! rxops#app#qf#matches(l1, l2, loc, title) abort
  let l:p = rxops#app#collect#positions(a:l1, a:l2)
  if !l:p.ok || l:p.count == 0
    return l:p
  endif
  let l:buf = bufnr('')
  let l:items = []
  for [l:lnum, l:col] in l:p.items
    call add(l:items, {'bufnr': l:buf, 'lnum': l:lnum, 'col': l:col, 'text': getline(l:lnum)})
  endfor
  return s:set(a:loc, a:title, l:items)
endfunction
