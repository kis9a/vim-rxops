" Align at the matches of the last search (vim-easy-align).

function! rxops#app#align#matches(l1, l2, args) abort
  let l:a = rxops#domain#pattern#align_args(a:args)
  if !l:a.ok
    return l:a
  endif
  return rxops#deps#easyalign#align(a:l1, a:l2, l:a.args)
endfunction
