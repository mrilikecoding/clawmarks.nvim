local M = {}

M.defaults = {
  clawmarks_file = '.clawmarks.json',
  signs = {
    enabled = true,
    decision = { icon = '◆', hl = 'ClawmarkDecision' },
    question = { icon = '?', hl = 'ClawmarkQuestion' },
    change_needed = { icon = '!', hl = 'ClawmarkChange' },
    reference = { icon = '→', hl = 'ClawmarkReference' },
    alternative = { icon = '⇄', hl = 'ClawmarkAlternative' },
    dependency = { icon = '⊕', hl = 'ClawmarkDependency' },
  },
  auto_refresh = true,
  highlights = {
    ClawmarkDecision = { fg = '#98c379', bold = true },
    ClawmarkQuestion = { fg = '#e5c07b', bold = true },
    ClawmarkChange = { fg = '#e06c75', bold = true },
    ClawmarkReference = { fg = '#61afef', bold = true },
    ClawmarkAlternative = { fg = '#c678dd', bold = true },
    ClawmarkDependency = { fg = '#56b6c2', bold = true },
  },
}

M.options = {}

function M.setup(opts)
  M.options = vim.tbl_deep_extend('force', {}, M.defaults, opts or {})
end

function M.get()
  return M.options
end

return M
