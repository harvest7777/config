return {
  'nvim-neo-tree/neo-tree.nvim',
  branch = 'v3.x',
  dependencies = {
    'nvim-lua/plenary.nvim',
    'MunifTanjim/nui.nvim',
    'nvim-tree/nvim-web-devicons',
  },
  lazy = false,
  opts = {
    filesystem = {
      bind_to_cwd = false,
      filtered_items = {
        visible = true,       -- show hidden items but dimmed
        hide_dotfiles = false,
        hide_gitignored = false,
      }
    },
    window = {
      width = "25%",
      mappings = {
        ['l'] = 'open',
        ['h'] = 'close_node',
        ['E'] = 'expand_all_nodes',
        ['e'] = 'expand_all_subnodes',
      }
    },
  }
}
