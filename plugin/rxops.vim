" vim-rxops -- Operate on the last Vim search, by line or by match.

if exists('g:loaded_rxops')
  finish
endif
let g:loaded_rxops = 1

let s:save_cpo = &cpoptions
set cpoptions&vim

" -bar only where there is no argument: the substitute, macro and align
" arguments may contain |.
command! -range=% -bar RxopsDeleteLines call rxops#delete_lines(<line1>, <line2>)
command! -range=% -bar RxopsKeepLines call rxops#keep_lines(<line1>, <line2>)
command! -range=% -bar RxopsDeleteMatches call rxops#delete_matches(<line1>, <line2>)
command! -range=% -bar RxopsKeepMatches call rxops#keep_matches(<line1>, <line2>)
command! -range=% -bar RxopsYankLines call rxops#yank_lines(<line1>, <line2>)
command! -range=% -bar RxopsYankMatches call rxops#yank_matches(<line1>, <line2>)
command! -range=% -bang -bar RxopsQuickfixLines call rxops#list_lines(<line1>, <line2>, <bang>0, 0)
command! -range=% -bang -bar RxopsLoclistLines call rxops#list_lines(<line1>, <line2>, <bang>0, 1)
command! -range=% -bar RxopsQuickfixMatches call rxops#list_matches(<line1>, <line2>, 0)
command! -range=% -bar RxopsLoclistMatches call rxops#list_matches(<line1>, <line2>, 1)
command! -range=% -nargs=? RxopsAlignMatches call rxops#align_matches(<line1>, <line2>, <q-args>)
command! -bar RxopsFoldLines call rxops#fold_lines()
command! -range=% -bang -nargs=1 RxopsMacroLines call rxops#macro_lines(<line1>, <line2>, <bang>0, <q-args>)
command! -range=% -nargs=1 RxopsMacroMatches call rxops#macro_matches(<line1>, <line2>, <q-args>)
command! -range=% -nargs=1 RxopsSubstituteLines call rxops#substitute_lines(<line1>, <line2>, <q-args>)
command! -range=% -nargs=1 RxopsSubstituteMatches call rxops#substitute_matches(<line1>, <line2>, <q-args>)

" Normal mode works on the whole buffer, Visual mode on the selected lines.
function! s:plug(name, call) abort
  execute printf('nnoremap <silent> <Plug>(rxops-%s) <Cmd>call rxops#%s<CR>',
        \ a:name, printf(a:call, "1, line('$')"))
  execute printf('xnoremap <silent> <Plug>(rxops-%s) :<C-u>call rxops#%s<CR>',
        \ a:name, printf(a:call, "line(\"'<\"), line(\"'>\")"))
endfunction

call s:plug('delete-lines', 'delete_lines(%s)')
call s:plug('keep-lines', 'keep_lines(%s)')
call s:plug('delete-matches', 'delete_matches(%s)')
call s:plug('keep-matches', 'keep_matches(%s)')
call s:plug('yank-lines', 'yank_lines(%s)')
call s:plug('yank-matches', 'yank_matches(%s)')
call s:plug('qf-lines', 'list_lines(%s, 0, 0)')
call s:plug('qf-unmatched-lines', 'list_lines(%s, 1, 0)')
call s:plug('loclist-lines', 'list_lines(%s, 0, 1)')
call s:plug('loclist-unmatched-lines', 'list_lines(%s, 1, 1)')
call s:plug('qf-matches', 'list_matches(%s, 0)')
call s:plug('loclist-matches', 'list_matches(%s, 1)')
call s:plug('align-matches', "align_matches(%s, '')")
delfunction s:plug

" Folding is per window and takes no range.
nnoremap <silent> <Plug>(rxops-fold-lines) <Cmd>call rxops#fold_lines()<CR>

" These stop on the command line for the argument (Visual: :'<,'>...).
nnoremap <Plug>(rxops-macro-lines) :RxopsMacroLines<Space>
xnoremap <Plug>(rxops-macro-lines) :RxopsMacroLines<Space>
nnoremap <Plug>(rxops-macro-unmatched-lines) :RxopsMacroLines!<Space>
xnoremap <Plug>(rxops-macro-unmatched-lines) :RxopsMacroLines!<Space>
nnoremap <Plug>(rxops-macro-matches) :RxopsMacroMatches<Space>
xnoremap <Plug>(rxops-macro-matches) :RxopsMacroMatches<Space>
nnoremap <Plug>(rxops-substitute-lines) :RxopsSubstituteLines /
xnoremap <Plug>(rxops-substitute-lines) :RxopsSubstituteLines /
nnoremap <Plug>(rxops-substitute-matches) :RxopsSubstituteMatches /
xnoremap <Plug>(rxops-substitute-matches) :RxopsSubstituteMatches /

let &cpoptions = s:save_cpo
unlet s:save_cpo
