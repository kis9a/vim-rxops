" Messages. echomsg keeps them in :messages; echohl is reset in finally.

" At most 50 columns with the prefix: with 'showcmd' and 'ruler' a longer
" message can cause a hit-enter prompt in an 80-column Vim.
let s:width = 50

function! rxops#compat#notify#text(msg) abort
  let l:text = '[rxops] ' . substitute(a:msg, '[[:cntrl:]]', ' ', 'g')
  if strdisplaywidth(l:text) <= s:width
    return l:text
  endif
  let l:n = s:width - 3
  while strdisplaywidth(strcharpart(l:text, 0, l:n)) > s:width - 3
    let l:n -= 1
  endwhile
  return strcharpart(l:text, 0, l:n) . '...'
endfunction

function! s:emit(group, msg) abort
  if a:group !=# ''
    execute 'echohl' a:group
  endif
  try
    let l:full = '[rxops] ' . substitute(a:msg, '[[:cntrl:]]', ' ', 'g')
    let l:short = rxops#compat#notify#text(a:msg)
    " :messages keeps the full text; the screen shows the short one
    echomsg l:full
    if l:short !=# l:full
      redraw
      echo l:short
    endif
  finally
    echohl None
  endtry
endfunction

function! rxops#compat#notify#info(msg) abort
  call s:emit('', a:msg)
endfunction

function! rxops#compat#notify#warn(msg) abort
  call s:emit('WarningMsg', a:msg)
endfunction

function! rxops#compat#notify#error(msg) abort
  call s:emit('ErrorMsg', a:msg)
endfunction
