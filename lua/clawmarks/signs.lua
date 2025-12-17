local M = {}

local config = require('clawmarks.config')

local ns_id = vim.api.nvim_create_namespace('clawmarks')
M._enabled = true

-- Define signs for each mark type
function M.setup()
  local cfg = config.get()

  for type_name, sign_opts in pairs(cfg.signs) do
    if type_name ~= 'enabled' and type(sign_opts) == 'table' then
      vim.fn.sign_define('Clawmark_' .. type_name, {
        text = sign_opts.icon,
        texthl = sign_opts.hl,
        numhl = sign_opts.hl,
      })
    end
  end
end

-- Clear all signs in a buffer
function M.clear_buffer(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  vim.fn.sign_unplace('clawmarks', { buffer = bufnr })
  vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
end

-- Place signs for marks in current buffer
function M.refresh_buffer(bufnr)
  if not M._enabled then
    return
  end

  bufnr = bufnr or vim.api.nvim_get_current_buf()

  -- Get the file path relative to cwd
  local filepath = vim.api.nvim_buf_get_name(bufnr)
  local cwd = vim.fn.getcwd()

  -- Make path relative
  if filepath:sub(1, #cwd) == cwd then
    filepath = filepath:sub(#cwd + 2) -- +2 to skip the /
  end

  if filepath == '' then
    return
  end

  -- Clear existing signs
  M.clear_buffer(bufnr)

  -- Get marks for this file
  local clawmarks = require('clawmarks')
  local marks = clawmarks.get_marks({ file = filepath })

  -- Place signs
  for _, mark in ipairs(marks) do
    local sign_name = 'Clawmark_' .. (mark.type or 'reference')

    -- Place sign
    vim.fn.sign_place(0, 'clawmarks', sign_name, bufnr, {
      lnum = mark.line,
      priority = 10,
    })

    -- Add virtual text with annotation (truncated)
    local annotation = mark.annotation or ''
    if #annotation > 60 then
      annotation = annotation:sub(1, 57) .. '...'
    end

    vim.api.nvim_buf_set_extmark(bufnr, ns_id, mark.line - 1, 0, {
      virt_text = { { ' ◀ ' .. annotation, 'Comment' } },
      virt_text_pos = 'eol',
    })
  end
end

-- Refresh signs in all buffers
function M.refresh()
  if not M._enabled then
    return
  end

  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr) then
      M.refresh_buffer(bufnr)
    end
  end
end

-- Toggle signs on/off
function M.toggle()
  M._enabled = not M._enabled

  if M._enabled then
    M.refresh()
    vim.notify('Clawmarks signs enabled', vim.log.levels.INFO)
  else
    -- Clear all signs
    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_loaded(bufnr) then
        M.clear_buffer(bufnr)
      end
    end
    vim.notify('Clawmarks signs disabled', vim.log.levels.INFO)
  end
end

-- Check if signs are enabled
function M.is_enabled()
  return M._enabled
end

return M
