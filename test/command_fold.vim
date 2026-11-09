let s:suite = themis#suite('command_fold')
let s:assert = themis#helper('assert')

let s:text = ['a hit', 'b', 'c', 'd hit', 'e']

function! s:closed() abort
  return map(range(1, line('$')), 'foldclosed(v:val) != -1')
endfunction

function! s:suite.before_each() abort
  only!
  unlet! w:rxops_fold
  call RxopsTestBuffer(s:text)
  setlocal foldmethod< foldexpr< foldlevel< foldminlines< foldenable<
  let @/ = 'hit'
endfunction

function! s:suite.after_each() abort
  set noignorecase nosmartcase
  unlet! w:rxops_fold
  only!
endfunction

function! s:suite.toggle() abort
  let l:msg = execute('RxopsFoldLines')
  call s:assert.match(l:msg, '\[rxops\] narrowed (RxopsFoldLines again restores)')
  call s:assert.equals(s:closed(), [0, 1, 1, 0, 1])
  call s:assert.equals(&l:foldmethod, 'expr')
  let l:msg = execute('RxopsFoldLines')
  call s:assert.match(l:msg, '\[rxops\] restored fold options (manual folds lost)')
  call s:assert.equals(s:closed(), [0, 0, 0, 0, 0])
  call s:assert.equals([&l:foldmethod, &l:foldexpr, &l:foldminlines], ['manual', '0', 1])
  call s:assert.false(exists('w:rxops_fold'))
endfunction

function! s:suite.keeps_cursor() abort
  call cursor(4, 3)
  silent RxopsFoldLines
  call s:assert.equals(getpos('.')[1:2], [4, 3])
endfunction

function! s:suite.narrow_again() abort
  silent RxopsFoldLines
  let @/ = '^[bc]'
  silent RxopsFoldLines
  call s:assert.equals(s:closed(), [1, 0, 0, 1, 1])
  call s:assert.equals(w:rxops_fold[bufnr('')].pattern, '^[bc]')
  silent RxopsFoldLines
  call s:assert.equals(&l:foldmethod, 'manual')
endfunction

function! s:suite.restore_with_empty_search() abort
  silent RxopsFoldLines
  let @/ = ''
  call s:assert.match(execute('RxopsFoldLines'), 'restored')
  call s:assert.equals(&l:foldmethod, 'manual')
  call s:assert.match(execute('RxopsFoldLines'), '\[rxops\] E35: No previous regular expression')
endfunction

function! s:suite.no_matches() abort
  let @/ = 'zzz'
  call s:assert.match(execute('RxopsFoldLines'), '\[rxops\] no matches')
  call s:assert.false(exists('w:rxops_fold'))
  call s:assert.equals(&l:foldmethod, 'manual')
endfunction

function! s:suite.split_copy_resets() abort
  silent RxopsFoldLines
  split
  call s:assert.false(exists('w:rxops_fold'))
  call s:assert.match(&l:foldexpr, '^rxops#ui#fold#level(')
  call s:assert.match(execute('RxopsFoldLines'), 'reset folds to global settings')
  call s:assert.equals([&l:foldmethod, &l:foldexpr], [&g:foldmethod, &g:foldexpr])
  call s:assert.equals(s:closed(), [0, 0, 0, 0, 0])
  close
  call s:assert.equals(s:closed(), [0, 1, 1, 0, 1])
endfunction

function! s:suite.smartcase() abort
  " regression: =~ ignored 'smartcase' and showed 'todo' too
  call RxopsTestBuffer(['todo', 'TODO', 'x'])
  set ignorecase smartcase
  let @/ = 'TODO'
  let l:msg = execute('RxopsFoldLines')
  call s:assert.equals(s:closed(), [1, 0, 1])
  call s:assert.not_match(l:msg, 'may differ')
endfunction

function! s:suite.star_pattern() abort
  " * ignores 'smartcase': :g selects both lines, and so must the folds
  call RxopsTestBuffer(['Foo', 'foo', 'x'])
  set ignorecase smartcase
  silent normal! gg*
  call s:assert.equals(@/, '\<Foo\>')
  let l:msg = execute('RxopsFoldLines')
  call s:assert.equals(s:closed(), [0, 0, 1])
  call s:assert.not_match(l:msg, 'may differ')
endfunction

function! s:suite.multiline_pattern_warns() abort
  let @/ = 'c\nd'
  let l:msg = execute('RxopsFoldLines')
  call s:assert.match(l:msg, '\[rxops\] folds may differ from :g for this pattern')
  call s:assert.true(exists('w:rxops_fold'))
endfunction

function! s:suite.engine_prefix() abort
  let @/ = '\%#=1hit'
  silent RxopsFoldLines
  call s:assert.equals(s:closed(), [0, 1, 1, 0, 1])
  call s:assert.match(&l:foldexpr, '\\%#=1\\C')
endfunction

function! s:suite.unnamed_and_nofile_buffers_survive() abort
  for l:bt in ['', 'nofile']
    enew!
    let &l:buftype = l:bt
    call setline(1, s:text)
    setlocal foldmethod=manual
    2,3fold
    let l:buf = bufnr('')
    silent RxopsFoldLines
    silent RxopsFoldLines
    call s:assert.equals([bufnr(''), RxopsTestLines()], [l:buf, s:text], l:bt)
    call s:assert.equals(s:closed(), [0, 0, 0, 0, 0], l:bt)
    setlocal buftype=nofile
  endfor
endfunction

function! s:suite.named_file_restores_manual_folds() abort
  let l:name = tempname() . '.txt'
  call writefile(s:text, l:name)
  execute 'edit' fnameescape(l:name)
  try
    setlocal foldmethod=manual
    2,3fold
    call s:assert.equals(s:closed(), [0, 1, 1, 0, 0])
    let l:buf = bufnr('')
    silent RxopsFoldLines
    call s:assert.not_equals(w:rxops_fold[bufnr('')].view, '')
    let l:view = w:rxops_fold[bufnr('')].view
    call s:assert.equals(s:closed(), [0, 1, 1, 0, 1])
    let l:msg = execute('RxopsFoldLines')
    call s:assert.match(l:msg, '\[rxops\] restored folds')
    call s:assert.equals(bufnr(''), l:buf)
    call s:assert.equals(&l:foldmethod, 'manual')
    call s:assert.equals(s:closed(), [0, 1, 1, 0, 0])
    call s:assert.false(filereadable(l:view))
  finally
    execute 'bwipeout!' l:buf
    call delete(l:name)
  endtry
endfunction

function! s:suite.other_buffer_discards_state() abort
  silent RxopsFoldLines
  let l:old = bufnr('')
  call RxopsTestBuffer(['x hit', 'y'])
  call s:assert.not_equals(bufnr(''), l:old)
  silent RxopsFoldLines
  call s:assert.equals(w:rxops_fold[bufnr('')].bufnr, bufnr(''))
  call s:assert.equals(s:closed(), [0, 1])
  " the saved options are the global ones, not the old narrowing
  silent RxopsFoldLines
  call s:assert.equals(&l:foldmethod, 'manual')
  call s:assert.equals(s:closed(), [0, 0])
endfunction

function! s:suite.top_level_search_unchanged() abort
  let l:out = RxopsTestTopLevel([
        \ 'call setline(1, ' . string(s:text) . ')',
        \ 'let @/ = ''hit''',
        \ 'RxopsFoldLines',
        \ 'call add(s:out, @/ . " " . &l:foldmethod)',
        \ 'RxopsFoldLines',
        \ 'call add(s:out, @/ . " " . &l:foldmethod)'])
  call s:assert.equals(l:out, ['hit expr', 'hit manual'])
endfunction

function! s:suite.unnamed_and_nofile_messages() abort
  for l:bt in ['', 'nofile']
    enew!
    let &l:buftype = l:bt
    call setline(1, s:text)
    call s:assert.match(execute('RxopsFoldLines'), '\[rxops\] narrowed', l:bt)
    call s:assert.match(execute('RxopsFoldLines'),
          \ '\[rxops\] restored fold options (manual folds lost)', l:bt)
    setlocal buftype=nofile
  endfor
endfunction

function! s:suite.named_file_restore_after_deleting_lines() abort
  " regression: E16 from ':N,Mfold' past the end, and the open/closed state
  let l:name = tempname() . '.txt'
  call writefile(map(range(1, 20), '"line " . v:val . (v:val % 5 ? "" : " hit")'), l:name)
  execute 'edit' fnameescape(l:name)
  try
    setlocal foldmethod=manual foldlevel=0
    3,6fold
    15,18fold
    normal! 3Gzo
    call s:assert.equals([foldclosed(3), foldclosed(15)], [-1, 15])
    silent RxopsFoldLines
    silent 12,$delete _
    let v:errmsg = ''
    let l:msg = execute('RxopsFoldLines')
    call s:assert.not_match(l:msg, 'E\d\+')
    call s:assert.equals(v:errmsg, '')
    call s:assert.match(l:msg, '\[rxops\] restored folds')
    call s:assert.equals(&l:foldmethod, 'manual')
    call s:assert.equals([foldlevel(3), foldclosed(3), foldlevel(10)], [1, -1, 0])
  finally
    execute 'bwipeout!' bufnr('')
    call delete(l:name)
  endtry
endfunction

function! s:suite.named_file_keeps_open_and_closed_folds() abort
  let l:name = tempname() . '.txt'
  call writefile(map(range(1, 20), '"line " . v:val . (v:val % 5 ? "" : " hit")'), l:name)
  execute 'edit' fnameescape(l:name)
  try
    setlocal foldmethod=manual foldlevel=0
    3,6fold
    15,18fold
    normal! 3Gzo
    silent RxopsFoldLines
    silent RxopsFoldLines
    call s:assert.equals([foldclosed(3), foldclosed(15), &l:foldlevel], [-1, 15, 0])
  finally
    execute 'bwipeout!' bufnr('')
    call delete(l:name)
  endtry
endfunction

function! s:suite.restored_options_message_without_manual() abort
  setlocal foldmethod=indent
  silent RxopsFoldLines
  let l:msg = execute('RxopsFoldLines')
  call s:assert.match(l:msg, '\[rxops\] restored fold options$')
  call s:assert.equals(&l:foldmethod, 'indent')
endfunction

function! s:named_with_folds() abort
  let l:name = tempname() . '.txt'
  call writefile(map(range(1, 12), '(v:val % 4 ? "line " : "hit ") . v:val'), l:name)
  execute 'edit' fnameescape(l:name)
  setlocal foldmethod=manual
  2,3fold
  return l:name
endfunction

function! s:suite.renamed_while_narrowed() abort
  " regression: the view's :buffer / :edit switched buffers or gave E37
  for l:how in ['file', 'saveas']
    let l:name = s:named_with_folds()
    let l:new = tempname() . '.txt'
    let l:buf = bufnr('')
    try
      silent RxopsFoldLines
      call setline(1, 'changed')
      execute 'silent' l:how fnameescape(l:new)
      let v:errmsg = ''
      let l:msg = execute('RxopsFoldLines')
      call s:assert.not_match(l:msg, 'E\d\+', l:how)
      call s:assert.match(l:msg, 'restored fold options (manual folds lost)', l:how)
      call s:assert.equals([bufnr(''), fnamemodify(bufname(''), ':p'), getline(1), &l:foldmethod],
            \ [l:buf, fnamemodify(l:new, ':p'), 'changed', 'manual'], l:how)
      call s:assert.false(exists('w:rxops_fold'), l:how)
    finally
      for l:b in filter(range(1, bufnr('$')), 'bufexists(v:val) && v:val >= l:buf')
        execute 'bwipeout!' l:b
      endfor
      call delete(l:name)
      call delete(l:new)
    endtry
  endfor
endfunction

function! s:suite.view_restore_has_no_side_effects() abort
  " only the fold commands of the view file run: no argglobal, no :edit,
  " no 'hlsearch' (Neovim), no SessionLoadPost
  let l:name = s:named_with_folds()
  set nohidden nohlsearch
  arglocal
  silent argadd a b
  augroup rxops_test
    autocmd SessionLoadPost * let g:rxops_test_session = 1
  augroup END
  unlet! g:rxops_test_session
  try
    silent RxopsFoldLines
    call setline(1, 'changed')
    let l:msg = execute('RxopsFoldLines')
    call s:assert.match(l:msg, '\[rxops\] restored folds')
    call s:assert.equals([foldclosed(2), foldclosed(3)], [2, 2])
    call s:assert.equals([getline(1), &hlsearch, arglistid() != 0], ['changed', 0, 1])
    call s:assert.false(exists('g:rxops_test_session'))
  finally
    augroup rxops_test
      autocmd!
    augroup END
    argglobal
    execute 'bwipeout!' bufnr('')
    call delete(l:name)
  endtry
endfunction

function! s:suite.view_filter_accepts_every_fold_line_form() abort
  " Vim 9.1 writes '2,3fold', Vim 9.2 'sil! :2,3fold', Neovim 'sil! 2,3fold'
  call RxopsTestBuffer(map(range(1, 10), 'string(v:val)'))
  call rxops#ui#fold#level('x')
  let l:fold = themis#helper('scope').funcs('autoload/rxops/ui/fold.vim')
  let l:in = ['vim9script', 'let s:so_save = &g:so', 'argglobal',
        \ 'if bufexists("x") | buffer x | else | edit x | endif',
        \ 'setlocal fdm=manual', 'setlocal foldmethod=manual', 'setlocal nofoldenable',
        \ 'silent! normal! zE', 'normal! zE',
        \ '2,3fold', 'sil! :4,5fold', 'sil! 6,7fold', 'silent! :8,9fold', ':2,3fold',
        \ '9,12fold', 'sil! :9,11fold',
        \ 'let &fdl = &fdl', '&fdl = &fdl',
        \ '2', 'normal! zo', ':4', 'sil! normal! zc',
        \ '12', 'sil! normal! zo', ':13', 'normal! zc',
        \ 'set hlsearch', 'doautoall SessionLoadPost', '" vim: set ft=vim :']
  call s:assert.equals(l:fold.clip_view(l:in), ['vim9script',
        \ 'setlocal fdm=manual', 'setlocal foldmethod=manual', 'setlocal nofoldenable',
        \ 'silent! normal! zE', 'normal! zE',
        \ '2,3fold', 'sil! :4,5fold', 'sil! 6,7fold', 'silent! :8,9fold', ':2,3fold',
        \ 'let &fdl = &fdl', '&fdl = &fdl',
        \ '2', 'normal! zo', ':4', 'sil! normal! zc'])
endfunction
