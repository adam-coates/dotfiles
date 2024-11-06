return {
  {
    "vhyrro/luarocks.nvim",
    priority = 1001, -- this plugin needs to run before anything else
    opts = {
      rocks = { "magick" },
    },
  },
  {
    "3rd/image.nvim",
    opts = {
      integrations = {
        markdown = {
          clear_in_insert_mode = true,
          only_render_image_at_cursor = true,
        },
      },
      html = {
        enabled = true,
      },
      css = {
        enabled = true,
      },
      max_width_window_percentage = 50,
      tmux_show_only_in_active_window = true,
    },
  },
}

