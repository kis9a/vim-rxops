scriptencoding utf-8
let s:suite = themis#suite('plugin')
let s:assert = themis#helper('assert')

let s:commands = ['RxopsDeleteLines', 'RxopsKeepLines', 'RxopsDeleteMatches',
      \ 'RxopsKeepMatches', 'RxopsYankLines', 'RxopsYankMatches', 'RxopsQuickfixLines',
      \ 'RxopsLoclistLines', 'RxopsQuickfixMatches', 'RxopsLoclistMatches',
      \ 'RxopsAlignMatches', 'RxopsFoldLines', 'RxopsMacroLines', 'RxopsMacroMatches',
      \ 'RxopsSubstituteLines', 'RxopsSubstituteMatches']
let s:short = ['DL', 'KL', 'DM', 'KM', 'YL', 'YM', 'QL', 'LL', 'QM', 'LM', 'AM', 'FL',
      \ 'ML', 'MM', 'SL', 'SM']

let s:plugs = ['delete-lines', 'keep-lines', 'delete-matches', 'keep-matches',
      \ 'yank-lines', 'yank-matches', 'qf-lines', 'qf-unmatched-lines', 'loclist-lines',
      \ 'loclist-unmatched-lines', 'qf-matches', 'loclist-matches', 'align-matches',
      \ 'macro-lines', 'macro-unmatched-lines', 'macro-matches', 'substitute-lines',
      \ 'substitute-matches']

function! s:suite.before_each() abort
  let s:regs = RxopsTestSaveRegs()
  call RxopsTestBuffer(['a x1', 'b', 'a x2', 'c'])
  let @/ = 'x\d'
endfunction

function! s:suite.after_each() abort
  call RxopsTestRestoreRegs(s:regs)
  for l:c in ['DL', 'QL', 'SL', 'FL']
    if exists(':' . l:c) == 2
      execute 'delcommand' l:c
    endif
  endfor
  unlet! w:rxops_fold
  setlocal foldmethod< foldexpr< foldlevel< foldminlines< foldenable<
  call setqflist([], 'r')
endfunction

function! s:suite.loaded() abort
  call s:assert.equals(g:loaded_rxops, 1)
endfunction

function! s:suite.long_commands_only() abort
  for l:c in s:commands
    call s:assert.equals(exists(':' . l:c), 2, l:c)
  endfor
  for l:c in s:short
    call s:assert.equals(exists(':' . l:c), 0, l:c)
  endfor
endfunction

function! s:suite.plug_mappings() abort
  for l:p in s:plugs
    call s:assert.not_empty(maparg('<Plug>(rxops-' . l:p . ')', 'n'), 'n ' . l:p)
    call s:assert.not_empty(maparg('<Plug>(rxops-' . l:p . ')', 'x'), 'x ' . l:p)
  endfor
  call s:assert.not_empty(maparg('<Plug>(rxops-fold-lines)', 'n'))
  call s:assert.empty(maparg('<Plug>(rxops-fold-lines)', 'x'))
  call s:assert.equals(maparg('<Plug>(rxops-substitute-lines)', 'n'), ':RxopsSubstituteLines /')
  call s:assert.equals(maparg('<Plug>(rxops-substitute-matches)', 'x'), ':RxopsSubstituteMatches /')
  call s:assert.equals(maparg('<Plug>(rxops-macro-unmatched-lines)', 'n'), ':RxopsMacroLines! ')
endfunction

function! s:suite.no_default_keys() abort
  let l:maps = split(execute('map') . execute('map!'), "\n")
  call s:assert.equals(filter(l:maps, 'v:val !~# "<Plug>" && v:val =~? "rxops"'), [])
endfunction

function! s:suite.plug_normal_whole_buffer_and_undo() abort
  silent execute "normal \<Plug>(rxops-delete-lines)"
  call s:assert.equals(RxopsTestLines(), ['b', 'c'])
  call s:assert.equals(@/, 'x\d')
  silent normal! u
  call s:assert.equals(RxopsTestLines(), ['a x1', 'b', 'a x2', 'c'])
endfunction

function! s:suite.plug_visual_selected_lines_and_undo() abort
  silent execute "normal 2GVG\<Plug>(rxops-delete-lines)"
  call s:assert.equals(RxopsTestLines(), ['a x1', 'b', 'c'])
  silent normal! u
  call s:assert.equals(RxopsTestLines(), ['a x1', 'b', 'a x2', 'c'])
endfunction

function! s:suite.plug_visual_list() abort
  silent execute "normal 3GVG\<Plug>(rxops-qf-unmatched-lines)"
  call s:assert.equals(map(getqflist(), 'v:val.lnum'), [4])
endfunction

function! s:suite.empty_search_is_an_error() abort
  let @/ = ''
  let l:calls = ['RxopsDeleteLines', 'RxopsKeepLines', 'RxopsDeleteMatches', 'RxopsKeepMatches',
        \ 'RxopsYankLines', 'RxopsYankMatches', 'RxopsQuickfixLines', 'RxopsLoclistLines!',
        \ 'RxopsQuickfixMatches', 'RxopsLoclistMatches', 'RxopsAlignMatches', 'RxopsFoldLines',
        \ 'RxopsMacroLines a', 'RxopsMacroMatches a', 'RxopsSubstituteLines /a/b/',
        \ 'RxopsSubstituteMatches /a/b/']
  for l:c in l:calls
    let l:msg = execute(l:c)
    call s:assert.match(l:msg, '\[rxops\] E35: No previous regular expression', l:c)
    call s:assert.equals(RxopsTestLines(), ['a x1', 'b', 'a x2', 'c'], l:c)
  endfor
  silent let l:r = rxops#yank_lines(1, 2)
  call s:assert.equals([l:r.ok, l:r.code], [v:false, 'no_pattern'])
endfunction

function! s:suite.result_shape() abort
  silent let l:r = rxops#yank_matches(1, line('$'))
  for l:k in ['ok', 'code', 'error', 'count', 'changed']
    call s:assert.has_key(l:r, l:k)
  endfor
  call s:assert.equals([l:r.ok, l:r.count, l:r.changed], [v:true, 2, v:false])
  silent let l:r = rxops#delete_lines(1, line('$'))
  call s:assert.equals([l:r.ok, l:r.count, l:r.changed], [v:true, 2, v:true])
endfunction

function! s:define_aliases() abort
  command! -range=% DL <line1>,<line2>RxopsDeleteLines
  command! -range=% -bang QL <line1>,<line2>RxopsQuickfixLines<bang>
  command! -range=% -nargs=1 SL <line1>,<line2>RxopsSubstituteLines <args>
  command! FL RxopsFoldLines
endfunction

function! s:suite.short_aliases_pass_range_and_bang() abort
  call s:define_aliases()
  silent 2,4DL
  call s:assert.equals(RxopsTestLines(), ['a x1', 'b', 'c'])
  call s:assert.equals(getreg('"', 1, 1), ['a x2'])
  silent QL!
  call s:assert.equals(map(getqflist(), 'v:val.lnum'), [2, 3])
  call s:assert.equals(getqflist({'title': 1}).title, 'RxopsQuickfixLines! /x\d')
  call s:assert.match(execute('2,3QL'), '\[rxops\] no lines')
  silent QL
  call s:assert.equals(map(getqflist(), 'v:val.lnum'), [1])
  silent SL /a/A|B/
  call s:assert.equals(RxopsTestLines(), ['A|B x1', 'b', 'c'])
  silent FL
  call s:assert.true(exists('w:rxops_fold'))
  silent FL
  call s:assert.false(exists('w:rxops_fold'))
endfunction

function! s:suite.short_aliases_at_top_level() abort
  let l:out = RxopsTestTopLevel([
        \ 'command! -range=% -nargs=1 SL <line1>,<line2>RxopsSubstituteLines <args>',
        \ 'call setline(1, ["id=foo-1 name=foo", "name=foo"])',
        \ 'let @/ = ''id=\S\+''',
        \ 'SL /foo/bar/g',
        \ 'call add(s:out, @/)',
        \ 'call add(s:out, string(getline(1, "$")))'])
  call s:assert.equals(l:out, ['id=\S\+', string(['id=bar-1 name=bar', 'name=foo'])])
endfunction

function! s:suite.helptags() abort
  let l:doc = fnamemodify(globpath(&runtimepath, 'doc/rxops.txt', 0, 1)[0], ':h')
  let l:dir = tempname()
  call mkdir(l:dir, 'p')
  call writefile(readfile(l:doc . '/rxops.txt'), l:dir . '/rxops.txt')
  let v:errmsg = ''
  execute 'helptags' fnameescape(l:dir)
  call s:assert.equals(v:errmsg, '')
  call s:assert.true(filereadable(l:dir . '/tags'))
  call delete(l:dir, 'rf')
endfunction

" Messages fit in 50 columns: no hit-enter prompt in 80 columns with showcmd and ruler.
function! s:suite.messages_are_short() abort
  let l:msgs = []
  for l:cmd in ['RxopsDeleteLines', 'RxopsKeepLines', 'RxopsYankMatches', 'RxopsLoclistLines!',
        \ 'RxopsQuickfixMatches', 'RxopsLoclistMatches', 'RxopsAlignMatches x',
        \ 'RxopsAlignMatches', 'RxopsMacroLines! ab', 'RxopsMacroMatches ab',
        \ 'RxopsSubstituteMatches x', 'RxopsSubstituteLines x', 'RxopsSubstituteMatches /a/b/x',
        \ 'RxopsFoldLines', 'RxopsFoldLines']
    call RxopsTestBuffer(map(range(1, 10000), '"a x" . v:val'))
    let @/ = 'x\d'
    call extend(l:msgs, split(execute(l:cmd), "\n"))
  endfor
  let @/ = 'x\n'
  call extend(l:msgs, split(execute('RxopsFoldLines'), "\n"))
  call extend(l:msgs, split(execute('RxopsFoldLines'), "\n"))
  split
  call extend(l:msgs, split(execute('RxopsFoldLines'), "\n"))
  close
  let @/ = ''
  call extend(l:msgs, split(execute('RxopsYankLines'), "\n"))
  " a passed-through Vim error is cut to fit
  let @/ = 'x'
  setlocal nomodifiable
  let l:err = split(execute('RxopsSubstituteMatches /x/y/'), "\n")
  setlocal modifiable
  call s:assert.match(join(l:err), "E21: Cannot make changes.*\\.\\.\\.$")
  " not silent, so that it reaches :messages
  setlocal nomodifiable
  call execute('RxopsSubstituteMatches /x/y/', '')
  setlocal modifiable
  call s:assert.match(execute('messages'), "\\[rxops\\] E21: Cannot make changes, 'modifiable' is off\\(\\n\\|$\\)")
  call extend(l:msgs, l:err)
  call filter(l:msgs, 'v:val =~# "^\\[rxops\\]"')
  call s:assert.true(len(l:msgs) >= 15, string(l:msgs))
  " a longer message goes to :messages in full and is followed on the screen
  " by its shortened form
  let l:i = 0
  while l:i < len(l:msgs)
    let l:m = l:msgs[l:i]
    if strdisplaywidth(l:m) > 50
      call s:assert.equals(get(l:msgs, l:i + 1, ''), rxops#compat#notify#text(l:m[8 :]), l:m)
      let l:i += 1
    endif
    let l:i += 1
  endwhile
endfunction

function! s:suite.message_text_is_cut_to_50_columns() abort
  call s:assert.equals(rxops#compat#notify#text('short'), '[rxops] short')
  let l:t = rxops#compat#notify#text(repeat('x', 60))
  call s:assert.equals([strdisplaywidth(l:t), l:t[-3 :]], [50, '...'])
  let l:t = rxops#compat#notify#text(repeat('あ', 40))
  call s:assert.true(strdisplaywidth(l:t) <= 50, l:t)
  call s:assert.equals(rxops#compat#notify#text("a\nb"), '[rxops] a b')
endfunction

function! s:suite.singular_counts() abort
  call RxopsTestBuffer(['a x1', 'b'])
  let @/ = 'x\d'
  call s:assert.match(execute('RxopsYankLines'), '\[rxops\] 1 line yanked')
  call s:assert.match(execute('RxopsYankMatches'), '\[rxops\] 1 match yanked')
  call s:assert.match(execute('RxopsLoclistMatches'), '\[rxops\] 1 match -> location list')
  call s:assert.match(execute('RxopsSubstituteMatches /zz/y/'), '\[rxops\] 0 matches changed')
  call s:assert.match(execute('RxopsSubstituteMatches /x/y/'), '\[rxops\] 1 match changed')
  call RxopsTestBuffer(['a x1', 'b'])
  call s:assert.match(execute('RxopsDeleteLines'), '\[rxops\] 1 line deleted')
endfunction
