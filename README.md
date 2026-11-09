# vim-rxops

Operate on the last Vim search, by line or by match.

Search any way you like (`/`, `*`, ...), then delete, keep, yank, list,
align, fold, run a macro on, or substitute inside what it matched: the whole
lines (`...Lines`) or only the matched text (`...Matches`). The plugin reads
only `@/`, so `n` and the next command still use the same search.

```
id=foo-123 name=foo          /id=\S\+                  id=bar-123 name=foo
name=foo-456          ->     :RxopsSubstituteMatches   name=foo-456
id=foo-789 name=foo              /foo/bar/g            id=bar-789 name=foo
```

To do the same to another search, search again and press `@:` (repeat the
last command line).

## Installation

```vim
" vim-plug
Plug 'kis9a/vim-rxops'
```

Vim 8.2.1978+ / Neovim 0.9+; only `:RxopsAlignMatches` needs
[vim-easy-align](https://github.com/junegunn/vim-easy-align).

## Features

### Commands

| Command | Description |
|---|---|
| `:RxopsDeleteLines` | Delete the matching lines |
| `:RxopsKeepLines` | Delete the other lines |
| `:RxopsDeleteMatches` | Delete the matched text |
| `:RxopsKeepMatches` | Replace the range with its matches, one per line |
| `:RxopsYankLines` | Yank the matching lines |
| `:RxopsYankMatches` | Yank the matched text, one match per line |
| `:RxopsQuickfixLines[!]` | Quickfix list of the matching lines (`!`: the other lines) |
| `:RxopsLoclistLines[!]` | The same in a location list |
| `:RxopsQuickfixMatches` | Quickfix list with one item per match |
| `:RxopsLoclistMatches` | The same in a location list |
| `:RxopsAlignMatches [arg]` | Align at the matches (`:EasyAlign [arg]//`) |
| `:RxopsFoldLines` | Show only the matching lines; run again to restore the folds |
| `:RxopsMacroLines[!] {reg}` | Run a macro on each matching line, as `:g//normal! @{reg}` |
| `:RxopsMacroMatches {reg}` | Run a macro at each match, last match first |
| `:RxopsSubstituteLines /pat/rep/[flags]` | Substitute in the matching lines (`:g//s/pat/rep/[flags]`) |
| `:RxopsSubstituteMatches /pat/rep/[gIi]` | Substitute only inside each match |

Without a range every command works on the whole buffer (`:RxopsFoldLines`
takes none). `@/` is the same afterwards, one `u` undoes a whole command,
deleted text goes to `"1` and yanked text to `"0`, as for `d` and `y`.

### Functions

Each command calls `rxops#...()`; see `:help rxops-functions`.

### Options

None; `let g:loaded_rxops = 1` disables the plugin.

## Configuration

### Key Mappings (Example)

No keys are mapped. Every command has a `<Plug>` mapping, which works on the
selected lines in Visual mode (`:help rxops-mappings`):

```vim
nmap <Leader>/d  <Plug>(rxops-delete-lines)
xmap <Leader>/d  <Plug>(rxops-delete-lines)
nmap <Leader>/D  <Plug>(rxops-keep-lines)
xmap <Leader>/D  <Plug>(rxops-keep-lines)
nmap <Leader>/x  <Plug>(rxops-delete-matches)
xmap <Leader>/x  <Plug>(rxops-delete-matches)
nmap <Leader>/k  <Plug>(rxops-keep-matches)
xmap <Leader>/k  <Plug>(rxops-keep-matches)
nmap <Leader>/Y  <Plug>(rxops-yank-lines)
xmap <Leader>/Y  <Plug>(rxops-yank-lines)
nmap <Leader>/y  <Plug>(rxops-yank-matches)
xmap <Leader>/y  <Plug>(rxops-yank-matches)
nmap <Leader>/q  <Plug>(rxops-qf-lines)
xmap <Leader>/q  <Plug>(rxops-qf-lines)
nmap <Leader>/!q <Plug>(rxops-qf-unmatched-lines)
xmap <Leader>/!q <Plug>(rxops-qf-unmatched-lines)
nmap <Leader>/l  <Plug>(rxops-loclist-lines)
xmap <Leader>/l  <Plug>(rxops-loclist-lines)
nmap <Leader>/!l <Plug>(rxops-loclist-unmatched-lines)
xmap <Leader>/!l <Plug>(rxops-loclist-unmatched-lines)
nmap <Leader>/Q  <Plug>(rxops-qf-matches)
xmap <Leader>/Q  <Plug>(rxops-qf-matches)
nmap <Leader>/L  <Plug>(rxops-loclist-matches)
xmap <Leader>/L  <Plug>(rxops-loclist-matches)
nmap <Leader>/a  <Plug>(rxops-align-matches)
xmap <Leader>/a  <Plug>(rxops-align-matches)
nmap <Leader>/f  <Plug>(rxops-fold-lines)
nmap <Leader>/@  <Plug>(rxops-macro-lines)
xmap <Leader>/@  <Plug>(rxops-macro-lines)
nmap <Leader>/!@ <Plug>(rxops-macro-unmatched-lines)
xmap <Leader>/!@ <Plug>(rxops-macro-unmatched-lines)
nmap <Leader>/m  <Plug>(rxops-macro-matches)
xmap <Leader>/m  <Plug>(rxops-macro-matches)
nmap <Leader>/sl <Plug>(rxops-substitute-lines)
xmap <Leader>/sl <Plug>(rxops-substitute-lines)
nmap <Leader>/sm <Plug>(rxops-substitute-matches)
xmap <Leader>/sm <Plug>(rxops-substitute-matches)
```

The macro and substitute mappings stop on the command line for the
register or `/pat/rep/[flags]`.

### Short Command Names (Example)

The plugin defines only the `Rxops` names. Aliases like these pass the
range, `!` and the argument through (`:help rxops-aliases`):

```vim
command! -range=% -bar DL <line1>,<line2>RxopsDeleteLines
command! -range=% -bar KL <line1>,<line2>RxopsKeepLines
command! -range=% -bar DM <line1>,<line2>RxopsDeleteMatches
command! -range=% -bar KM <line1>,<line2>RxopsKeepMatches
command! -range=% -bar YL <line1>,<line2>RxopsYankLines
command! -range=% -bar YM <line1>,<line2>RxopsYankMatches
command! -range=% -bang -bar QL <line1>,<line2>RxopsQuickfixLines<bang>
command! -range=% -bang -bar LL <line1>,<line2>RxopsLoclistLines<bang>
command! -range=% -bar QM <line1>,<line2>RxopsQuickfixMatches
command! -range=% -bar LM <line1>,<line2>RxopsLoclistMatches
command! -range=% -nargs=? AM <line1>,<line2>RxopsAlignMatches <args>
command! -bar FL RxopsFoldLines
command! -range=% -bang -nargs=1 ML <line1>,<line2>RxopsMacroLines<bang> <args>
command! -range=% -nargs=1 MM <line1>,<line2>RxopsMacroMatches <args>
command! -range=% -nargs=1 SL <line1>,<line2>RxopsSubstituteLines <args>
command! -range=% -nargs=1 SM <line1>,<line2>RxopsSubstituteMatches <args>
```

Give `-bar` only to the commands without an argument: the others may
contain `|`.

### Limitations

`:RxopsFoldLines` tests each line on its own, so multi-line patterns may fold
differently from `:g` (it says so). See `:help rxops-limitations`.

## LICENSE

MIT. See [LICENSE](LICENSE).
