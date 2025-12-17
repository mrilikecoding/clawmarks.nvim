# clawmarks.nvim

Neovim plugin for browsing [Clawmarks](https://github.com/mrilikecoding/clawmarks) - storybook-style annotated bookmarks created by AI agents.

## Features

- **Telescope Integration** - Browse threads, marks, and tags
- **Knowledge Graph Navigation** - Follow references between marks with `<C-r>`
- **Gutter Signs** - See marks in the sign column
- **Auto-refresh** - Automatically updates when `.clawmarks.json` changes

## Requirements

- Neovim >= 0.8
- [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim)
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)
- [clawmarks](https://github.com/mrilikecoding/clawmarks) MCP server (for creating marks)

## Installation

### lazy.nvim

```lua
{
  'mrilikecoding/clawmarks.nvim',
  dependencies = {
    'nvim-telescope/telescope.nvim',
    'nvim-lua/plenary.nvim',
  },
  config = function()
    require('clawmarks').setup()
    require('telescope').load_extension('clawmarks')
  end,
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
:Telescope clawmarks threads    " Browse all threads
:Telescope clawmarks marks      " Browse all marks
:Telescope clawmarks tags       " Browse by tag
```

Or with Lua:

```lua
require('telescope').extensions.clawmarks.threads()
require('telescope').extensions.clawmarks.marks()
require('telescope').extensions.clawmarks.marks({ thread_id = 't_abc123' })
require('telescope').extensions.clawmarks.tags()
```

### Keybindings in Pickers

| Key | Action |
|-----|--------|
| `<CR>` | Jump to mark / Open marks for thread |
| `<C-r>` | Show references for selected mark |

### Commands

| Command | Description |
|---------|-------------|
| `:ClawmarksRefresh` | Reload from `.clawmarks.json` |
| `:ClawmarksToggleSigns` | Toggle gutter signs |

### Suggested Keymaps

```lua
vim.keymap.set('n', '<leader>ct', '<cmd>Telescope clawmarks threads<cr>', { desc = 'Clawmarks threads' })
vim.keymap.set('n', '<leader>cm', '<cmd>Telescope clawmarks marks<cr>', { desc = 'Clawmarks marks' })
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

This plugin reads the `.clawmarks.json` file created by the [clawmarks](https://github.com/mrilikecoding/clawmarks) MCP server. The MCP server is used by AI agents (like Claude Code) to create annotated bookmarks during conversations about your code.

```
Claude Code ──► clawmarks (MCP) ──► .clawmarks.json ◄── clawmarks.nvim
```

## License

MIT
