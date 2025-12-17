" clawmarks.vim - Claude Code conversation bookmarks for Neovim
" Maintainer: Your Name
" Version: 0.1.0

if exists('g:loaded_clawmarks')
  finish
endif
let g:loaded_clawmarks = 1

" Telescope commands
command! ClawmarksThreads lua require('telescope').extensions.clawmarks.threads()
command! ClawmarksMarks lua require('telescope').extensions.clawmarks.marks()
command! ClawmarksTags lua require('telescope').extensions.clawmarks.tags()
