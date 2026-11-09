" vim-easy-align is used only through its command.

" 2 also for a vim-plug on-demand stub, which loads the plugin when run.
function! rxops#deps#easyalign#available() abort
  return exists(':EasyAlign') == 2
endfunction

" :EasyAlign {args}// -- the empty regexp is the last search pattern.
" {args} must have been checked by domain/pattern#align_args().
function! rxops#deps#easyalign#align(l1, l2, args) abort
  if !rxops#deps#easyalign#available()
    return {'ok': v:false, 'code': 'no_easyalign', 'error': '', 'count': 0, 'changed': v:false}
  endif
  let l:tick = b:changedtick
  let l:fold = rxops#app#collect#fold_off()
  try
    " keeppatterns covers this command line only; it does not reach the
    " commands that :EasyAlign runs (vim-easy-align itself keeps @/, the
    " search history and the last substitute)
    execute 'keeppatterns ' . a:l1 . ',' . a:l2 . 'EasyAlign ' . a:args . '//'
  catch
    return {'ok': v:false, 'code': 'vim_error', 'error': v:exception, 'count': 0, 'changed': (b:changedtick != l:tick ? v:true : v:false)}
  finally
    call rxops#app#collect#fold_restore(l:fold)
  endtry
  return {'ok': v:true, 'code': '', 'error': '', 'count': 0, 'changed': (b:changedtick != l:tick ? v:true : v:false)}
endfunction
