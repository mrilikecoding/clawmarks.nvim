local M = {}

local has_telescope, telescope = pcall(require, 'telescope')
if not has_telescope then
  return M
end

local pickers = require('telescope.pickers')
local finders = require('telescope.finders')
local conf = require('telescope.config').values
local actions = require('telescope.actions')
local action_state = require('telescope.actions.state')
local previewers = require('telescope.previewers')
local entry_display = require('telescope.pickers.entry_display')

local clawmarks = require('clawmarks')

-- Mark type icons for display
local type_icons = {
  decision = '◆',
  question = '?',
  change_needed = '!',
  reference = '→',
  alternative = '⇄',
  dependency = '⊕',
}

-- ===================== Threads Picker =====================

function M.threads(opts)
  opts = opts or {}

  clawmarks.load() -- Refresh data

  local threads = clawmarks.get_threads()

  if #threads == 0 then
    vim.notify('No clawmarks threads found', vim.log.levels.INFO)
    return
  end

  local displayer = entry_display.create({
    separator = ' ',
    items = {
      { width = 10 }, -- status
      { remaining = true }, -- name
    },
  })

  local make_display = function(entry)
    local status_hl = entry.thread.status == 'active' and 'String' or 'Comment'
    return displayer({
      { '[' .. entry.thread.status .. ']', status_hl },
      { entry.thread.name },
    })
  end

  pickers
    .new(opts, {
      prompt_title = 'Clawmarks Threads',
      finder = finders.new_table({
        results = threads,
        entry_maker = function(thread)
          local marks = clawmarks.get_marks({ thread_id = thread.id })
          return {
            value = thread.id,
            display = make_display,
            ordinal = thread.name .. ' ' .. (thread.description or ''),
            thread = thread,
            mark_count = #marks,
          }
        end,
      }),
      sorter = conf.generic_sorter(opts),
      previewer = previewers.new_buffer_previewer({
        title = 'Thread Details',
        define_preview = function(self, entry)
          local thread = entry.thread
          local marks = clawmarks.get_marks({ thread_id = thread.id })

          local lines = {
            '# ' .. thread.name,
            '',
            'Status: ' .. thread.status,
            'Created: ' .. (thread.created_at or 'unknown'),
            'Marks: ' .. #marks,
            '',
          }

          if thread.description then
            table.insert(lines, 'Description:')
            table.insert(lines, thread.description)
            table.insert(lines, '')
          end

          if #marks > 0 then
            table.insert(lines, '## Marks')
            table.insert(lines, '')
            for _, mark in ipairs(marks) do
              local icon = type_icons[mark.type] or '•'
              table.insert(lines, icon .. ' ' .. mark.file .. ':' .. mark.line)
              table.insert(lines, '  ' .. mark.annotation)
              table.insert(lines, '')
            end
          end

          vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
          vim.api.nvim_buf_set_option(self.state.bufnr, 'filetype', 'markdown')
        end,
      }),
      attach_mappings = function(prompt_bufnr, map)
        actions.select_default:replace(function()
          actions.close(prompt_bufnr)
          local selection = action_state.get_selected_entry()
          -- Open marks picker for this thread
          M.marks({ thread_id = selection.value })
        end)
        return true
      end,
    })
    :find()
end

-- ===================== Marks Picker =====================

function M.marks(opts)
  opts = opts or {}

  clawmarks.load() -- Refresh data

  local marks = clawmarks.get_marks({
    thread_id = opts.thread_id,
    file = opts.file,
    type = opts.type,
    tag = opts.tag,
  })

  if #marks == 0 then
    vim.notify('No clawmarks found', vim.log.levels.INFO)
    return
  end

  local displayer = entry_display.create({
    separator = ' ',
    items = {
      { width = 2 }, -- icon
      { width = 40 }, -- file:line
      { remaining = true }, -- annotation
    },
  })

  local make_display = function(entry)
    local mark = entry.mark
    local icon = type_icons[mark.type] or '•'
    local location = mark.file .. ':' .. mark.line

    -- Truncate annotation for display
    local annotation = mark.annotation or ''
    if #annotation > 50 then
      annotation = annotation:sub(1, 47) .. '...'
    end

    return displayer({
      { icon, 'ClawmarkReference' },
      { location, 'TelescopeResultsIdentifier' },
      { annotation },
    })
  end

  pickers
    .new(opts, {
      prompt_title = 'Clawmarks',
      finder = finders.new_table({
        results = marks,
        entry_maker = function(mark)
          return {
            value = mark.id,
            display = make_display,
            ordinal = mark.file .. ' ' .. mark.annotation .. ' ' .. table.concat(mark.tags or {}, ' '),
            mark = mark,
            filename = vim.fn.getcwd() .. '/' .. mark.file,
            lnum = mark.line,
            col = mark.column or 1,
          }
        end,
      }),
      sorter = conf.generic_sorter(opts),
      previewer = conf.grep_previewer(opts),
      attach_mappings = function(prompt_bufnr, map)
        actions.select_default:replace(function()
          actions.close(prompt_bufnr)
          local selection = action_state.get_selected_entry()
          clawmarks.jump_to_mark(selection.mark)
        end)

        -- <C-r> to show references
        map('i', '<C-r>', function()
          local selection = action_state.get_selected_entry()
          actions.close(prompt_bufnr)
          M.references({ mark_id = selection.value })
        end)
        map('n', '<C-r>', function()
          local selection = action_state.get_selected_entry()
          actions.close(prompt_bufnr)
          M.references({ mark_id = selection.value })
        end)

        return true
      end,
    })
    :find()
end

-- ===================== Tags Picker =====================

function M.tags(opts)
  opts = opts or {}

  clawmarks.load()

  local tags = clawmarks.get_tags()

  if #tags == 0 then
    vim.notify('No tags found', vim.log.levels.INFO)
    return
  end

  pickers
    .new(opts, {
      prompt_title = 'Clawmarks Tags',
      finder = finders.new_table({
        results = tags,
        entry_maker = function(tag)
          local marks = clawmarks.get_marks({ tag = tag })
          return {
            value = tag,
            display = tag .. ' (' .. #marks .. ' marks)',
            ordinal = tag,
          }
        end,
      }),
      sorter = conf.generic_sorter(opts),
      attach_mappings = function(prompt_bufnr, map)
        actions.select_default:replace(function()
          actions.close(prompt_bufnr)
          local selection = action_state.get_selected_entry()
          M.marks({ tag = selection.value })
        end)
        return true
      end,
    })
    :find()
end

-- ===================== References Picker =====================

function M.references(opts)
  opts = opts or {}

  if not opts.mark_id then
    vim.notify('No mark_id provided', vim.log.levels.ERROR)
    return
  end

  clawmarks.load()

  local refs = clawmarks.get_references(opts.mark_id)
  local source_mark = clawmarks.get_mark(opts.mark_id)

  local all_refs = {}

  for _, mark in ipairs(refs.outgoing) do
    table.insert(all_refs, { mark = mark, direction = 'outgoing' })
  end
  for _, mark in ipairs(refs.incoming) do
    table.insert(all_refs, { mark = mark, direction = 'incoming' })
  end

  if #all_refs == 0 then
    vim.notify('No references found for this mark', vim.log.levels.INFO)
    return
  end

  local displayer = entry_display.create({
    separator = ' ',
    items = {
      { width = 3 }, -- direction arrow
      { width = 2 }, -- icon
      { width = 40 }, -- file:line
      { remaining = true }, -- annotation
    },
  })

  local make_display = function(entry)
    local mark = entry.ref.mark
    local icon = type_icons[mark.type] or '•'
    local location = mark.file .. ':' .. mark.line
    local direction_icon = entry.ref.direction == 'outgoing' and '→' or '←'

    local annotation = mark.annotation or ''
    if #annotation > 40 then
      annotation = annotation:sub(1, 37) .. '...'
    end

    return displayer({
      { direction_icon, 'Comment' },
      { icon, 'ClawmarkReference' },
      { location, 'TelescopeResultsIdentifier' },
      { annotation },
    })
  end

  local title = 'References'
  if source_mark then
    title = 'References for ' .. source_mark.file .. ':' .. source_mark.line
  end

  pickers
    .new(opts, {
      prompt_title = title,
      finder = finders.new_table({
        results = all_refs,
        entry_maker = function(ref)
          return {
            value = ref.mark.id,
            display = make_display,
            ordinal = ref.mark.file .. ' ' .. ref.mark.annotation,
            ref = ref,
            mark = ref.mark,
            filename = vim.fn.getcwd() .. '/' .. ref.mark.file,
            lnum = ref.mark.line,
            col = ref.mark.column or 1,
          }
        end,
      }),
      sorter = conf.generic_sorter(opts),
      previewer = conf.grep_previewer(opts),
      attach_mappings = function(prompt_bufnr, map)
        actions.select_default:replace(function()
          actions.close(prompt_bufnr)
          local selection = action_state.get_selected_entry()
          clawmarks.jump_to_mark(selection.mark)
        end)

        -- <C-r> to show references of selected mark
        map('i', '<C-r>', function()
          local selection = action_state.get_selected_entry()
          actions.close(prompt_bufnr)
          M.references({ mark_id = selection.value })
        end)
        map('n', '<C-r>', function()
          local selection = action_state.get_selected_entry()
          actions.close(prompt_bufnr)
          M.references({ mark_id = selection.value })
        end)

        return true
      end,
    })
    :find()
end

-- Register as telescope extension
return telescope.register_extension({
  exports = {
    threads = M.threads,
    marks = M.marks,
    tags = M.tags,
    references = M.references,
    clawmarks = M.marks, -- default picker
  },
})
