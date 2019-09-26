# vim-searchindex

This plugin shows how many times a search pattern occurs in the current buffer.
After each search, it displays total number of matches, as well as the index of
a current match, in the command line:

<img src="https://raw.githubusercontent.com/google/vim-searchindex/master/vim-searchindex.gif" width="90%">

You can also press `g/` to display search index for the last search term at the
current cursor position.

That's it! The plugin is as simple and unobtrusive as possible. It works out of
the box with all built-in search commands, and stays fast even on huge files
thanks to caching. For full documentation (including extensibility and
configuration options), see `:help searchindex`.

## Installation

**Note:** This behavior is now supported natively in Vim 8.1.1270 and Neovim
0.4.0 (requires `set shortmess-=S` to enable on vim). Prefer updating your
editor if possible instead of using this plugin.

If you don't have a preferred installation method, I recommend
installing [pathogen.vim](https://github.com/tpope/vim-pathogen), and
then simply copy and paste:

    cd ~/.vim/bundle
    git clone https://github.com/google/vim-searchindex.git

Once help tags have been generated, you can view the manual with
`:help searchindex`.

*Disclaimer: This is not an official Google product. It is just an open source
code that happens to be owned by Google.*
