" searchindex.vim - display current & total number of search matches
" Author: Radoslaw Burny (rburny@google.com)
"
" Copyright 2015 Google Inc. All rights reserved.
"
" Licensed under the Apache License, Version 2.0 (the "License");
" you may not use this file except in compliance with the License.
" You may obtain a copy of the License at
"
"     http://www.apache.org/licenses/LICENSE-2.0
"
" Unless required by applicable law or agreed to in writing, software
" distributed under the License is distributed on an "AS IS" BASIS,
" WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
" See the License for the specific language governing permissions and
" limitations under the License.

if &cp || v:version < 700
  echoerr "Ancient Vim version, or compatible set"
  finish
endif

if exists('g:loaded_searchindex')
  finish
endif
let g:loaded_searchindex = 1

" Setup options.
if !exists('g:searchindex_line_limit')
  let g:searchindex_line_limit=1000000
endif

if !exists('g:searchindex_improved_star')
  let g:searchindex_improved_star=1
endif

if !exists('g:searchindex_star_case')
  let g:searchindex_star_case=1
endif

" Suppress the "search hit BOTTOM, continuing at TOP" type messages.
set shortmess+=s

" New command and mappings: show search index of last search pattern at
" the current cursor position.
command! -bar SearchIndex call <SID>PrintMatches()

" If user has mapped 'g/', don't override it.
silent! nmap <unique> g/ <Plug>SearchIndex

noremap  <Plug>SearchIndex <Nop>
noremap! <Plug>SearchIndex <Nop>
nnoremap <silent> <Plug>SearchIndex :call <SID>PrintMatches()<CR>

" Remap search commands (only if they're not mapped by the user).
silent! nmap <silent><unique> n n<Plug>SearchIndex
silent! nmap <silent><unique> N N<Plug>SearchIndex

silent! map <unique> *  <Plug>ImprovedStar_*<Plug>SearchIndex
silent! map <unique> #  <Plug>ImprovedStar_#<Plug>SearchIndex
silent! map <unique> g* <Plug>ImprovedStar_g*<Plug>SearchIndex
silent! map <unique> g# <Plug>ImprovedStar_g#<Plug>SearchIndex

noremap <silent><expr> <Plug>ImprovedStar_*  <SID>StarSearch('*')
noremap <silent><expr> <Plug>ImprovedStar_#  <SID>StarSearch('#')
noremap <silent><expr> <Plug>ImprovedStar_g* <SID>StarSearch('g*')
noremap <silent><expr> <Plug>ImprovedStar_g# <SID>StarSearch('g#')

" Remap searches from '/' and 'q/' by plugging into <CR> in cmdline & cmdwin.

" NOTE: This cannot use <silent> - it would break cmdline refresh in some
" cases (e.g. multiline commands, <C-R>= usage).
" NOTE: The mapping must be inlined - using a helper method breaks debug mode
" (issue #14). Consider reimplementing it based on CmdlineEnter and
" CmdlineLeave events to make it less intrusive.
silent! cmap <unique><expr> <CR>
    \ "\<CR>" . (getcmdtype() =~ '[/?]' ? "<Plug>SearchIndex" : "")

if exists('*getcmdwintype')
  " getcmdwintype() requires Vim 7.4.392. If it's not available, disable
  " support for command window searches (q/, q?).
  augroup searchindex_cmdwin
    autocmd!
    autocmd CmdWinEnter *
      \ if getcmdwintype() =~ '[/?]' |
      \   silent! nmap <buffer><unique> <CR> <CR><Plug>SearchIndex|
      \ endif
  augroup END
endif

" Implementation details.

function! s:StarSearch(cmd)
  if !g:searchindex_improved_star | return a:cmd | endif

  " With no word under cursor, search will fail. Fall back to '*' so that
  " error seems to come from native Vim command, not from this function.
  if expand("<cword>") == "" | return "*" | endif

  " reimplement star commands using '/' and '?'
  let search_dir = (a:cmd == '*' || a:cmd == 'g*') ? '/' : '?'
  let case_char = (g:searchindex_star_case ? '\C' : '\c')
  let [open_delim, close_delim] = (a:cmd =~ 'g.' ? ['', ''] : ['\<', '\>'])
  let search_term = open_delim . "\<C-R>\<C-W>" . close_delim
  return search_dir . search_term . case_char . "\<CR>"
endfunction

function! s:MatchesInRange(range)
  " Use :s///n to search efficiently in large files. Although calling search()
  " in the loop would be cleaner (see issue #18), it is also much slower.
  let gflag = &gdefault ? '' : 'g'
  let saved_marks = [ getpos("'["), getpos("']") ]
  let output = ''
  redir => output
    silent! execute 'keepjumps ' . a:range . 's//~/en' . gflag
  redir END
  call setpos("'[", saved_marks[0])
  call setpos("']", saved_marks[1])
  return str2nr(matchstr(output, '\d\+'))
endfunction

" Calculate which match in the current line the 'col' is at.
function! s:MatchInLine()
  let line = line('.')
  let col = col('.')
  let star_search = 0

  normal! 0
  let matches = 0
  let s_opt = 'c'
  " The count might be off in edge cases (e.g. regexes that allow empty match,
  " like 'a*'). Unfortunately, Vim's searching functions are so inconsistent
  " that I can't fix this.
  while search(@/, s_opt, line) && col('.') <= col
    let matches += 1
    let s_opt = ''
  endwhile

  return matches
endfunction

" Efficiently recalculate number of matches above cursor using values cached
" from the previous run.
function s:MatchesAbove(cached_values)
  " avoid wrapping range at the beginning of file
  if line('.') == 1 | return 0 | endif

  let [old_line, old_result, total] = a:cached_values
  " Find the nearest point from which we can restart match counting (top,
  " bottom, or previously cached line).
  let line = line('.')
  let to_top = line
  let to_old = abs(line - old_line)
  let to_bottom = line('$') - line
  let min_dist = min([to_top, to_old, to_bottom])

  if min_dist == to_top
    return s:MatchesInRange('1,.-1')
  elseif min_dist == to_bottom
    return total - s:MatchesInRange(',$')
  " otherwise, min_dist == to_old, we just need to check relative line order
  elseif old_line < line
    return old_result + s:MatchesInRange(old_line . ',-1')
  elseif old_line > line
    return old_result - s:MatchesInRange(',' . (old_line - 1))
  else " old_line == line
    return old_result
  endif
endfunction

" Return the given string, shortened to the maximum length. The middle of the
" string would be replaced by '...' in case the original string is too long.
function! s:ShortString(string, max_length)
    if len(a:string) < a:max_length
        return a:string
    endif

    " Calculate the needed length of each part of the string.
    " The 3 is because the middle part would be replace with 3 points.
    let l:string_part_length = (a:max_length - 3) / 2

    let l:start = a:string[:l:string_part_length - 1]
    let l:end = a:string[len(a:string) - l:string_part_length:]

    let l:output_string = l:start . "..." . l:end

    return l:output_string
endfunction

function! s:PrintMatches()
  let l:dir_char = v:searchforward ? '/' : '?'
  if line('$') > g:searchindex_line_limit
    let l:msg = '[MAX]  ' . l:dir_char . @/
  else
    " If there are no matches, search fails before we get here. The only way
    " we could see zero results is on 'g/' (but that's a reasonable result).
    let [l:current, l:total] = searchindex#MatchCounts()
    let l:msg = '[' . l:current . '/' . l:total . ']  ' . l:dir_char . @/
  endif

  " foldopen+=search causes search commands to open folds in the matched line
  " - but it doesn't work in mappings. Hence, we just open the folds here.
  if &foldopen =~# "search"
    normal! zv
  endif

  " Shorten the message string, to make it one screen wide. Do it only if the
  " T flag is inside the shortmess variable.
  " It seems that the press enter message won't be printed only if the length
  " of the message is shorter by at least 11 chars than the real length of the
  " screen.
  if &shortmess =~# "T"
    let l:msg = s:ShortString(l:msg, &columns - 11)
  endif

  " Flush any delayed screen updates before printing "l:msg".
  " See ":h :echo-redraw".
  redraw | echo l:msg
endfunction

" Return 2-element array, containing current index and total number of matches
" of @/ (last search pattern) in the current buffer.
function! searchindex#MatchCounts()
  " both :s and search() modify cursor position
  let win_view = winsaveview()
  " folds affect range of ex commands (issue #4)
  let save_foldenable = &foldenable
  set nofoldenable

  let in_line = s:MatchInLine()

  let cache_key = [b:changedtick, @/]
  if exists('b:searchindex_cache_key') && b:searchindex_cache_key ==# cache_key
    let before = s:MatchesAbove(b:searchindex_cache_val)
    let total = b:searchindex_cache_val[-1]
  else
    let before = (line('.') == 1 ? 0 : s:MatchesInRange('1,-1'))
    let total = before + s:MatchesInRange(',$')
  endif

  let b:searchindex_cache_val = [line('.'), before, total]
  let b:searchindex_cache_key = cache_key

  let &foldenable = save_foldenable
  call winrestview(win_view)

  return [before + in_line, total]
endfunction

""" IMPLEMENTATION NOTES

""" SEARCH TRIGGER
" It's tricky to detect when search is done precisely. We achieve this with
" two-level mappings:
" * conditional mapping of <CR> in cmdline / cmdwin. It checks command type to
"   only add <Plug>SearchIndex after search, not ex command or anything else.
" * mode-specific remappings of said <Plug> command that only display search
"   index in normal mode
" This way, if user performs search in non-normal mode, we don't clobber it
" (we could consider showing index in visual when noshowmode is set).
"
""" STAR COMMANDS OVERRIDE
" One Vim's quirk is that '*' and '#' commands silently ignore smartcase
" option. This is not detectable, which makes it impossible to count number of
" matches after 'star' commands correctly.
" Instead of hacking around this problem, we provide our own implementations
" of star commands. Additional advantage is that their case-sensitiveness can
" be controlled with a new option.
"
""" CACHING
" To improve efficiency, we cache results of last counting. This makes 'n'
" super fast. We only cache linewise counts, and in-line part is always
" recalculated. This prevents counting error from building up after multiple
" searches if in-line count was imprecise (which happens with regex searches).
