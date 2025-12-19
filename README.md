<p align="center">
  <img src="logo.png" alt="Clawmarks" width="128" height="128">
</p>

<h1 align="center">clawmarks.nvim</h1>

<p align="center">
  Neovim plugin for browsing <a href="https://github.com/mrilikecoding/clawmarks">Clawmarks</a> - storybook-style annotated bookmarks created by LLM agents.
</p>

## Features

- **Telescope Integration** - Browse trails, clawmarks, and tags
- **Knowledge Graph Navigation** - Follow references between clawmarks with `<C-r>`
- **Gutter Signs** - See clawmarks in the sign column
- **Auto-refresh** - Automatically updates when `.clawmarks.json` changes

## Requirements

- Neovim >= 0.8
- [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim)
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)
- [clawmarks](https://github.com/mrilikecoding/clawmarks) MCP server (for creating clawmarks)

## Installation

### lazy.nvim

```lua
{ 'mrilikecoding/clawmarks.nvim' }
```

The plugin includes a `lazy.lua` with sensible defaults (dependencies, config). Override as needed:

```lua
{
  'mrilikecoding/clawmarks.nvim',
  opts = {
    -- your custom options here
  },
}
```

### packer.nvim

```lua
use {
  'mrilikecoding/clawmarks.nvim',
  requires = {
    'nvim-telescope/telescope.nvim',
    'nvim-lua/plenary.nvim',
  },
  config = function()
    require('clawmarks').setup()
    require('telescope').load_extension('clawmarks')
  end,
}
```

## Usage

### Telescope Pickers

```vim
:Telescope clawmarks trails      " Browse exploration trails
:Telescope clawmarks clawmarks   " Browse all clawmarks
:Telescope clawmarks tags        " Browse by tag
```

Or with Lua:

```lua
require('telescope').extensions.clawmarks.trails()
require('telescope').extensions.clawmarks.clawmarks()
require('telescope').extensions.clawmarks.clawmarks({ trail_id = 't_abc123' })
require('telescope').extensions.clawmarks.tags()
```

### Keybindings in Pickers

| Key | Action |
|-----|--------|
| `<CR>` | Jump to clawmark / Open clawmarks for trail |
| `<C-r>` | Show references for selected clawmark |

### Commands

| Command | Description |
|---------|-------------|
| `:ClawmarksRefresh` | Reload from `.clawmarks.json` |
| `:ClawmarksToggleSigns` | Toggle gutter signs |
| `:ClawmarksHelp` | Show help |

### Suggested Keymaps

```lua
vim.keymap.set('n', '<leader>ct', '<cmd>Telescope clawmarks trails<cr>', { desc = 'Clawmarks trails' })
vim.keymap.set('n', '<leader>cm', '<cmd>Telescope clawmarks clawmarks<cr>', { desc = 'Clawmarks clawmarks' })
vim.keymap.set('n', '<leader>cg', '<cmd>Telescope clawmarks tags<cr>', { desc = 'Clawmarks tags' })
```

## Configuration

```lua
require('clawmarks').setup({
  -- Path to clawmarks file (relative to cwd)
  clawmarks_file = '.clawmarks.json',

  -- Gutter signs
  signs = {
    enabled = true,
    decision = { icon = '◆', hl = 'ClawmarkDecision' },
    question = { icon = '?', hl = 'ClawmarkQuestion' },
    change_needed = { icon = '!', hl = 'ClawmarkChange' },
    reference = { icon = '→', hl = 'ClawmarkReference' },
    alternative = { icon = '⇄', hl = 'ClawmarkAlternative' },
    dependency = { icon = '⊕', hl = 'ClawmarkDependency' },
  },

  -- Auto-refresh when file changes
  auto_refresh = true,

  -- Highlight groups
  highlights = {
    ClawmarkDecision = { fg = '#98c379', bold = true },
    ClawmarkQuestion = { fg = '#e5c07b', bold = true },
    ClawmarkChange = { fg = '#e06c75', bold = true },
    ClawmarkReference = { fg = '#61afef', bold = true },
    ClawmarkAlternative = { fg = '#c678dd', bold = true },
    ClawmarkDependency = { fg = '#56b6c2', bold = true },
  },
})
```

## How It Works

This plugin reads the `.clawmarks.json` file created by the [clawmarks](https://github.com/mrilikecoding/clawmarks) MCP server. The MCP server is used by LLM agents to create annotated bookmarks during code exploration sessions.

```
LLM Agent ──► clawmarks (MCP) ──► .clawmarks.json ◄── clawmarks.nvim
```

## License

MIT
