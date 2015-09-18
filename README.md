# vim-searchindex

This plugin shows how many times does a search pattern occur in the current
buffer. After each search, it displays total number of matches, as well as the
index of a current match, in the command line.

Consider the following example (`|` indicates cursor position):

```
99 bottles of beer on the wall, | 99 bottles of beer.
Take one down and pass it around, 98 bottles of beer on the wall.
```

After searching for "beer", the statusline will display:

```
[2/3]  /beer
```

You can also press `g/` to display search index for the last search term at the
current cursor position.

That's it! The plugin is as simple and unobtrusive as possible. It works out of
the box with all built-in search commands, and stays fast even on huge files
thanks to caching. For full documentation (including extensibility and
configuration options), see `:help searchindex`.

*Disclaimer: This is not an official Google product. It is just an open source
code that happens to be owned by Google.*
