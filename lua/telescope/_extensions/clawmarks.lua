-- Telescope extension entry point for clawmarks
-- This file must be here for telescope.load_extension('clawmarks') to work

local has_telescope, telescope = pcall(require, 'telescope')
if not has_telescope then
  error("clawmarks.nvim requires telescope.nvim")
end

local pickers = require('telescope.pickers')
local finders = require('telescope.finders')
local conf = require('telescope.config').values
local actions = require('telescope.actions')
local action_state = require('telescope.actions.state')
local previewers = require('telescope.previewers')
local entry_display = require('telescope.pickers.entry_display')

local clawmarks = require('clawmarks')

-- Clawmark type icons for display
local type_icons = {
  decision = '◆',
  question = '?',
  change_needed = '!',
  reference = '→',
  alternative = '⇄',
  dependency = '⊕',
}

local M = {}

-- ===================== Trails Picker =====================

function M.trails(opts)
  opts = opts or {}

  clawmarks.load() -- Refresh data

  local trails = clawmarks.get_trails()

  if #trails == 0 then
    vim.notify('No clawmarks trails found', vim.log.levels.INFO)
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
    local status_hl = entry.trail.status == 'active' and 'String' or 'Comment'
    return displayer({
      { '[' .. entry.trail.status .. ']', status_hl },
      { entry.trail.name },
    })
  end

  pickers
    .new(opts, {
      prompt_title = 'Clawmarks Trails',
      finder = finders.new_table({
        results = trails,
        entry_maker = function(trail)
          local trail_clawmarks = clawmarks.get_clawmarks({ trail_id = trail.id })
          return {
            value = trail.id,
            display = make_display,
            ordinal = trail.name .. ' ' .. (trail.description or ''),
            trail = trail,
            clawmark_count = #trail_clawmarks,
          }
        end,
      }),
      sorter = conf.generic_sorter(opts),
      previewer = previewers.new_buffer_previewer({
        title = 'Trail Details',
        define_preview = function(self, entry)
          local trail = entry.trail
          local trail_clawmarks = clawmarks.get_clawmarks({ trail_id = trail.id })

          local lines = {
            '# ' .. trail.name,
            '',
            'Status: ' .. trail.status,
            'Created: ' .. (trail.created_at or 'unknown'),
            'Clawmarks: ' .. #trail_clawmarks,
            '',
          }

          if trail.description then
            table.insert(lines, 'Description:')
            table.insert(lines, trail.description)
            table.insert(lines, '')
          end

          if #trail_clawmarks > 0 then
            table.insert(lines, '## Clawmarks')
            table.insert(lines, '')
            for _, cm in ipairs(trail_clawmarks) do
              local icon = type_icons[cm.type] or '•'
              table.insert(lines, icon .. ' ' .. cm.file .. ':' .. cm.line)
              table.insert(lines, '  ' .. cm.annotation)
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
          -- Open clawmarks picker for this trail
          M.clawmarks({ trail_id = selection.value })
        end)
        return true
      end,
    })
    :find()
end

-- ===================== Clawmarks Picker =====================

-- Custom previewer that shows annotation + file content
local function clawmark_previewer(opts)
  return previewers.new_buffer_previewer({
    title = 'Clawmark Preview',
    define_preview = function(self, entry)
      local cm = entry.clawmark
      local bufnr = self.state.bufnr

      -- Build annotation header
      local lines = {
        '┌─ Annotation ─────────────────────────────────────────────────────────────────',
        '',
      }

      -- Word-wrap the annotation
      local annotation = cm.annotation or '(no annotation)'
      local wrap_width = 78
      for i = 1, #annotation, wrap_width do
        table.insert(lines, '  ' .. annotation:sub(i, i + wrap_width - 1))
      end

      table.insert(lines, '')

      -- Add metadata
      local icon = type_icons[cm.type] or '•'
      table.insert(lines, '  Type: ' .. icon .. ' ' .. (cm.type or 'unknown'))
      if cm.tags and #cm.tags > 0 then
        table.insert(lines, '  Tags: ' .. table.concat(cm.tags, ', '))
      end

      table.insert(lines, '')
      table.insert(lines, '└──────────────────────────────────────────────────────────────────────────────')
      table.insert(lines, '')

      local header_end = #lines

      -- Read file content around the mark
      local filepath = vim.fn.getcwd() .. '/' .. cm.file
      local file_lines = {}
      local f = io.open(filepath, 'r')
      if f then
        for line in f:lines() do
          table.insert(file_lines, line)
        end
        f:close()
      end

      -- Show context around the marked line
      local context = 10
      local start_line = math.max(1, cm.line - context)
      local end_line = math.min(#file_lines, cm.line + context)

      table.insert(lines, cm.file .. ':' .. cm.line)
      table.insert(lines, string.rep('─', 80))

      for i = start_line, end_line do
        local prefix = i == cm.line and '→ ' or '  '
        local line_num = string.format('%4d', i)
        table.insert(lines, prefix .. line_num .. ' │ ' .. (file_lines[i] or ''))
      end

      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

      -- Apply highlighting
      local ns = vim.api.nvim_create_namespace('clawmarks_preview')

      -- Highlight annotation box
      for i = 0, header_end - 1 do
        vim.api.nvim_buf_add_highlight(bufnr, ns, 'Comment', i, 0, -1)
      end

      -- Highlight the marked line
      local marked_line_idx = header_end + 2 + (cm.line - start_line)
      if marked_line_idx < #lines then
        vim.api.nvim_buf_add_highlight(bufnr, ns, 'CursorLine', marked_line_idx, 0, -1)
        vim.api.nvim_buf_add_highlight(bufnr, ns, 'WarningMsg', marked_line_idx, 0, 2)
      end

      -- Try to set filetype for syntax highlighting of code portion
      local ext = cm.file:match('%.([^%.]+)$')
      if ext then
        local ft_map = {
          lua = 'lua', py = 'python', js = 'javascript', ts = 'typescript',
          tsx = 'typescriptreact', jsx = 'javascriptreact', rb = 'ruby',
          rs = 'rust', go = 'go', c = 'c', cpp = 'cpp', h = 'c',
        }
        -- We keep it as plaintext to preserve our custom highlighting
      end
    end,
  })
end

function M.clawmarks(opts)
  opts = opts or {}

  clawmarks.load() -- Refresh data

  local cms = clawmarks.get_clawmarks({
    trail_id = opts.trail_id,
    file = opts.file,
    type = opts.type,
    tag = opts.tag,
  })

  if #cms == 0 then
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
    local cm = entry.clawmark
    local icon = type_icons[cm.type] or '•'
    local location = cm.file .. ':' .. cm.line

    -- Truncate annotation for display
    local annotation = cm.annotation or ''
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
        results = cms,
        entry_maker = function(cm)
          return {
            value = cm.id,
            display = make_display,
            ordinal = cm.file .. ' ' .. cm.annotation .. ' ' .. table.concat(cm.tags or {}, ' '),
            clawmark = cm,
            filename = vim.fn.getcwd() .. '/' .. cm.file,
            lnum = cm.line,
            col = cm.column or 1,
          }
        end,
      }),
      sorter = conf.generic_sorter(opts),
      previewer = clawmark_previewer(opts),
      attach_mappings = function(prompt_bufnr, map)
        actions.select_default:replace(function()
          actions.close(prompt_bufnr)
          local selection = action_state.get_selected_entry()
          clawmarks.jump_to_clawmark(selection.clawmark)
        end)

        -- <C-r> to show references
        map('i', '<C-r>', function()
          local selection = action_state.get_selected_entry()
          actions.close(prompt_bufnr)
          M.references({ clawmark_id = selection.value })
        end)
        map('n', '<C-r>', function()
          local selection = action_state.get_selected_entry()
          actions.close(prompt_bufnr)
          M.references({ clawmark_id = selection.value })
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
          local cms = clawmarks.get_clawmarks({ tag = tag })
          return {
            value = tag,
            display = tag .. ' (' .. #cms .. ' clawmarks)',
            ordinal = tag,
          }
        end,
      }),
      sorter = conf.generic_sorter(opts),
      attach_mappings = function(prompt_bufnr, map)
        actions.select_default:replace(function()
          actions.close(prompt_bufnr)
          local selection = action_state.get_selected_entry()
          M.clawmarks({ tag = selection.value })
        end)
        return true
      end,
    })
    :find()
end

-- ===================== References Picker =====================

function M.references(opts)
  opts = opts or {}

  if not opts.clawmark_id then
    vim.notify('No clawmark_id provided', vim.log.levels.ERROR)
    return
  end

  clawmarks.load()

  local refs = clawmarks.get_references(opts.clawmark_id)
  local source_clawmark = clawmarks.get_clawmark(opts.clawmark_id)

  local all_refs = {}

  for _, cm in ipairs(refs.outgoing) do
    table.insert(all_refs, { clawmark = cm, direction = 'outgoing' })
  end
  for _, cm in ipairs(refs.incoming) do
    table.insert(all_refs, { clawmark = cm, direction = 'incoming' })
  end

  if #all_refs == 0 then
    vim.notify('No references found for this clawmark', vim.log.levels.INFO)
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
    local cm = entry.ref.clawmark
    local icon = type_icons[cm.type] or '•'
    local location = cm.file .. ':' .. cm.line
    local direction_icon = entry.ref.direction == 'outgoing' and '→' or '←'

    local annotation = cm.annotation or ''
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
  if source_clawmark then
    title = 'References for ' .. source_clawmark.file .. ':' .. source_clawmark.line
  end

  pickers
    .new(opts, {
      prompt_title = title,
      finder = finders.new_table({
        results = all_refs,
        entry_maker = function(ref)
          return {
            value = ref.clawmark.id,
            display = make_display,
            ordinal = ref.clawmark.file .. ' ' .. ref.clawmark.annotation,
            ref = ref,
            clawmark = ref.clawmark,
            filename = vim.fn.getcwd() .. '/' .. ref.clawmark.file,
            lnum = ref.clawmark.line,
            col = ref.clawmark.column or 1,
          }
        end,
      }),
      sorter = conf.generic_sorter(opts),
      previewer = conf.grep_previewer(opts),
      attach_mappings = function(prompt_bufnr, map)
        actions.select_default:replace(function()
          actions.close(prompt_bufnr)
          local selection = action_state.get_selected_entry()
          clawmarks.jump_to_clawmark(selection.clawmark)
        end)

        -- <C-r> to show references of selected clawmark
        map('i', '<C-r>', function()
          local selection = action_state.get_selected_entry()
          actions.close(prompt_bufnr)
          M.references({ clawmark_id = selection.value })
        end)
        map('n', '<C-r>', function()
          local selection = action_state.get_selected_entry()
          actions.close(prompt_bufnr)
          M.references({ clawmark_id = selection.value })
        end)

        return true
      end,
    })
    :find()
end

return telescope.register_extension({
  exports = {
    trails = M.trails,
    clawmarks = M.clawmarks,
    tags = M.tags,
    references = M.references,
  },
})
