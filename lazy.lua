-- Default lazy.nvim spec for clawmarks.nvim
return {
  event = 'VeryLazy',
  dependencies = {
    'nvim-telescope/telescope.nvim',
    'nvim-lua/plenary.nvim',
  },
  config = function()
    require('clawmarks').setup()
    require('telescope').load_extension('clawmarks')
  end,
}
