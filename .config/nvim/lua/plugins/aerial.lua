return {
  "stevearc/aerial.nvim",
  dependencies = {
     "nvim-treesitter/nvim-treesitter",
     "nvim-tree/nvim-web-devicons"
  },
  opts = {
    close_automatic_events = {
      "unfocus",
      "switch_buffer",
    },
    guides = {
      nested_top = " │ ",
      mid_item = " ├─",
      last_item = " └─",
      whitespace = "   ",
    },
    layout = {
      placement = "window",
      close_on_select = false,
      max_width = 30,
      min_width = 30,
    },
    ignore = {
      buftypes = {},
    },
    show_guides = true,
    open_automatic = false, 
        -- function()
    --   local aerial = require("aerial")
    --   return vim.api.nvim_win_get_width(0) > 80 and not aerial.was_closed()
    -- end,
  },
  config = function(_, opts)
    require("aerial").setup(opts)

    vim.keymap.set("n", "<F18>", "<cmd>AerialToggle<cr>", { silent = true })
  end,
}

