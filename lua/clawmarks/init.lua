local M = {}

local config = require('clawmarks.config')

-- State
M._data = nil
M._loaded = false

-- Load clawmarks data from JSON file
function M.load()
  local cfg = config.get()
  local cwd = vim.fn.getcwd()
  local filepath = cwd .. '/' .. cfg.clawmarks_file

  local file = io.open(filepath, 'r')
  if not file then
    M._data = { version = 1, trails = {}, clawmarks = {} }
    return M._data
  end

  local content = file:read('*a')
  file:close()

  local ok, data = pcall(vim.json.decode, content)
  if not ok then
    vim.notify('Clawmarks: Failed to parse ' .. cfg.clawmarks_file, vim.log.levels.ERROR)
    M._data = { version = 1, trails = {}, clawmarks = {} }
    return M._data
  end

  M._data = data
  M._loaded = true

  -- Update signs after loading
  if cfg.signs.enabled then
    require('clawmarks.signs').refresh()
  end

  return M._data
end

-- Get current data (load if needed)
function M.get_data()
  if not M._data then
    M.load()
  end
  return M._data
end

-- Refresh from file
function M.refresh()
  M._data = nil
  M._loaded = false
  M.load()
  vim.notify('Clawmarks: Refreshed', vim.log.levels.INFO)
end

-- Get all trails
function M.get_trails(status)
  local data = M.get_data()
  if not data.trails then
    return {}
  end
  if not status then
    return data.trails
  end
  local filtered = {}
  for _, trail in ipairs(data.trails) do
    if trail.status == status then
      table.insert(filtered, trail)
    end
  end
  return filtered
end

-- Get all clawmarks (optionally filtered)
function M.get_clawmarks(opts)
  opts = opts or {}
  local data = M.get_data()
  local clawmarks = data.clawmarks or {}

  if opts.trail_id then
    local filtered = {}
    for _, clawmark in ipairs(clawmarks) do
      if clawmark.trail_id == opts.trail_id then
        table.insert(filtered, clawmark)
      end
    end
    clawmarks = filtered
  end

  if opts.file then
    local filtered = {}
    for _, clawmark in ipairs(clawmarks) do
      if clawmark.file == opts.file then
        table.insert(filtered, clawmark)
      end
    end
    clawmarks = filtered
  end

  if opts.type then
    local filtered = {}
    for _, clawmark in ipairs(clawmarks) do
      if clawmark.type == opts.type then
        table.insert(filtered, clawmark)
      end
    end
    clawmarks = filtered
  end

  if opts.tag then
    local filtered = {}
    for _, clawmark in ipairs(clawmarks) do
      for _, t in ipairs(clawmark.tags or {}) do
        if t == opts.tag then
          table.insert(filtered, clawmark)
          break
        end
      end
    end
    clawmarks = filtered
  end

  return clawmarks
end

-- Get clawmark by ID
function M.get_clawmark(clawmark_id)
  local data = M.get_data()
  for _, clawmark in ipairs(data.clawmarks or {}) do
    if clawmark.id == clawmark_id then
      return clawmark
    end
  end
  return nil
end

-- Get trail by ID
function M.get_trail(trail_id)
  local data = M.get_data()
  for _, trail in ipairs(data.trails or {}) do
    if trail.id == trail_id then
      return trail
    end
  end
  return nil
end

-- Get all unique tags
function M.get_tags()
  local data = M.get_data()
  local tag_set = {}
  for _, clawmark in ipairs(data.clawmarks or {}) do
    for _, tag in ipairs(clawmark.tags or {}) do
      tag_set[tag] = true
    end
  end
  local tags = {}
  for tag, _ in pairs(tag_set) do
    table.insert(tags, tag)
  end
  table.sort(tags)
  return tags
end

-- Get references for a clawmark
function M.get_references(clawmark_id)
  local clawmark = M.get_clawmark(clawmark_id)
  if not clawmark then
    return { outgoing = {}, incoming = {} }
  end

  local data = M.get_data()
  local outgoing = {}
  local incoming = {}

  -- Outgoing references
  for _, ref_id in ipairs(clawmark.references or {}) do
    local ref_clawmark = M.get_clawmark(ref_id)
    if ref_clawmark then
      table.insert(outgoing, ref_clawmark)
    end
  end

  -- Incoming references
  for _, c in ipairs(data.clawmarks or {}) do
    for _, ref_id in ipairs(c.references or {}) do
      if ref_id == clawmark_id then
        table.insert(incoming, c)
        break
      end
    end
  end

  return { outgoing = outgoing, incoming = incoming }
end

-- Jump to a clawmark
function M.jump_to_clawmark(clawmark)
  local cwd = vim.fn.getcwd()
  local filepath = cwd .. '/' .. clawmark.file

  -- Open the file
  vim.cmd('edit ' .. vim.fn.fnameescape(filepath))

  -- Jump to line and column
  local line = clawmark.line or 1
  local col = (clawmark.column or 1) - 1 -- nvim columns are 0-indexed
  vim.api.nvim_win_set_cursor(0, { line, col })

  -- Center the view
  vim.cmd('normal! zz')
end

-- Setup function
function M.setup(opts)
  config.setup(opts)
  local cfg = config.get()

  -- Setup highlights
  for name, hl_opts in pairs(cfg.highlights) do
    vim.api.nvim_set_hl(0, name, hl_opts)
  end

  -- Setup signs
  if cfg.signs.enabled then
    require('clawmarks.signs').setup()
  end

  -- Setup file watcher for auto-refresh
  if cfg.auto_refresh then
    local group = vim.api.nvim_create_augroup('ClawmarksAutoRefresh', { clear = true })
    vim.api.nvim_create_autocmd({ 'BufWritePost' }, {
      group = group,
      pattern = cfg.clawmarks_file,
      callback = function()
        M.refresh()
      end,
    })
    -- Also refresh when entering a buffer
    vim.api.nvim_create_autocmd({ 'BufEnter' }, {
      group = group,
      callback = function()
        if cfg.signs.enabled then
          require('clawmarks.signs').refresh_buffer()
        end
      end,
    })
  end

  -- Setup commands
  vim.api.nvim_create_user_command('ClawmarksRefresh', function()
    M.refresh()
  end, { desc = 'Refresh clawmarks from file' })

  vim.api.nvim_create_user_command('ClawmarksToggleSigns', function()
    require('clawmarks.signs').toggle()
  end, { desc = 'Toggle clawmarks signs' })

  vim.api.nvim_create_user_command('ClawmarksHelp', function()
    local help = {
      '# Clawmarks.nvim',
      '',
      '## Telescope Pickers',
      '  :Telescope clawmarks trails      Browse exploration trails',
      '  :Telescope clawmarks clawmarks   Browse all clawmarks',
      '  :Telescope clawmarks tags        Browse by tag',
      '',
      '## Picker Keybindings',
      '  <CR>      Jump to clawmark / Open trail clawmarks',
      '  <C-r>     Show references for selected clawmark',
      '',
      '## Commands',
      '  :ClawmarksRefresh       Reload from .clawmarks.json',
      '  :ClawmarksToggleSigns   Toggle gutter signs',
      '  :ClawmarksHelp          Show this help',
      '',
      '## Clawmark Types',
      '  ◆  decision       A choice or decision made',
      '  ?  question       Needs resolution',
      '  !  change_needed  Code to modify',
      '  →  reference      Context or related code',
      '  ⇄  alternative    Another approach considered',
      '  ⊕  dependency     Something this depends on',
      '',
      '## Gutter Signs',
      '  Clawmarks appear in the sign column when viewing files.',
      '  Toggle with :ClawmarksToggleSigns',
    }
    vim.api.nvim_echo({{ table.concat(help, '\n'), 'Normal' }}, true, {})
  end, { desc = 'Show clawmarks help' })

  -- Load initial data
  M.load()

  -- Auto-load telescope extension
  local has_telescope, telescope = pcall(require, 'telescope')
  if has_telescope then
    telescope.load_extension('clawmarks')
  end
end

return M
