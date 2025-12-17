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
    M._data = { version = 1, threads = {}, marks = {} }
    return M._data
  end

  local content = file:read('*a')
  file:close()

  local ok, data = pcall(vim.json.decode, content)
  if not ok then
    vim.notify('Clawmarks: Failed to parse ' .. cfg.clawmarks_file, vim.log.levels.ERROR)
    M._data = { version = 1, threads = {}, marks = {} }
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

-- Get all threads
function M.get_threads(status)
  local data = M.get_data()
  if not status then
    return data.threads
  end
  local filtered = {}
  for _, thread in ipairs(data.threads) do
    if thread.status == status then
      table.insert(filtered, thread)
    end
  end
  return filtered
end

-- Get all marks (optionally filtered)
function M.get_marks(opts)
  opts = opts or {}
  local data = M.get_data()
  local marks = data.marks

  if opts.thread_id then
    local filtered = {}
    for _, mark in ipairs(marks) do
      if mark.thread_id == opts.thread_id then
        table.insert(filtered, mark)
      end
    end
    marks = filtered
  end

  if opts.file then
    local filtered = {}
    for _, mark in ipairs(marks) do
      if mark.file == opts.file then
        table.insert(filtered, mark)
      end
    end
    marks = filtered
  end

  if opts.type then
    local filtered = {}
    for _, mark in ipairs(marks) do
      if mark.type == opts.type then
        table.insert(filtered, mark)
      end
    end
    marks = filtered
  end

  if opts.tag then
    local filtered = {}
    for _, mark in ipairs(marks) do
      for _, t in ipairs(mark.tags or {}) do
        if t == opts.tag then
          table.insert(filtered, mark)
          break
        end
      end
    end
    marks = filtered
  end

  return marks
end

-- Get mark by ID
function M.get_mark(mark_id)
  local data = M.get_data()
  for _, mark in ipairs(data.marks) do
    if mark.id == mark_id then
      return mark
    end
  end
  return nil
end

-- Get thread by ID
function M.get_thread(thread_id)
  local data = M.get_data()
  for _, thread in ipairs(data.threads) do
    if thread.id == thread_id then
      return thread
    end
  end
  return nil
end

-- Get all unique tags
function M.get_tags()
  local data = M.get_data()
  local tag_set = {}
  for _, mark in ipairs(data.marks) do
    for _, tag in ipairs(mark.tags or {}) do
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

-- Get references for a mark
function M.get_references(mark_id)
  local mark = M.get_mark(mark_id)
  if not mark then
    return { outgoing = {}, incoming = {} }
  end

  local data = M.get_data()
  local outgoing = {}
  local incoming = {}

  -- Outgoing references
  for _, ref_id in ipairs(mark.references or {}) do
    local ref_mark = M.get_mark(ref_id)
    if ref_mark then
      table.insert(outgoing, ref_mark)
    end
  end

  -- Incoming references
  for _, m in ipairs(data.marks) do
    for _, ref_id in ipairs(m.references or {}) do
      if ref_id == mark_id then
        table.insert(incoming, m)
        break
      end
    end
  end

  return { outgoing = outgoing, incoming = incoming }
end

-- Jump to a mark
function M.jump_to_mark(mark)
  local cwd = vim.fn.getcwd()
  local filepath = cwd .. '/' .. mark.file

  -- Open the file
  vim.cmd('edit ' .. vim.fn.fnameescape(filepath))

  -- Jump to line and column
  local line = mark.line or 1
  local col = (mark.column or 1) - 1 -- nvim columns are 0-indexed
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

  -- Load initial data
  M.load()

  -- Auto-load telescope extension
  local has_telescope, telescope = pcall(require, 'telescope')
  if has_telescope then
    telescope.load_extension('clawmarks')
  end
end

return M
