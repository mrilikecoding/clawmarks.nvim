" clawmarks.vim - LLM agent exploration bookmarks for Neovim
" Maintainer: mrilikecoding
" Version: 0.2.0

if exists('g:loaded_clawmarks')
  finish
endif
let g:loaded_clawmarks = 1

" Telescope commands
command! ClawmarksTrails lua require('telescope').extensions.clawmarks.trails()
command! ClawmarksClawmarks lua require('telescope').extensions.clawmarks.clawmarks()
command! ClawmarksTags lua require('telescope').extensions.clawmarks.tags()
