return {
  {
    "bjarneo/aether.nvim",
    branch = "v3",
    name = "aether",
    priority = 1000,
    opts = {
      colors = {
        bg = "#111c18",
        dark_bg = "#0c1512",
        darker_bg = "#090f0d",
        lighter_bg = "#23372B",

        fg = "#C1C497",
        dark_fg = "#81B8A8",
        light_fg = "#D6D5BC",
        bright_fg = "#F7E8B2",
        muted = "#53685B",

        red = "#FF5345",
        yellow = "#459451",
        orange = "#a2734b",
        green = "#549e6a",
        cyan = "#2DD5B7",
        blue = "#509475",
        magenta = "#D2689C",
        brown = "#513925",

        bright_red = "#db9f9c",
        bright_yellow = "#E5C736",
        bright_green = "#63b07a",
        bright_cyan = "#8CD3CB",
        bright_blue = "#ACD4CF",
        bright_magenta = "#75bbb3",

        accent = "#509475",
        cursor = "#F7E8B2",
        foreground = "#C1C497",
        background = "#111c18",
        selection = "#32473B",
        selection_foreground = "#F7E8B2",
        selection_background = "#32473B",
      },
    },
  },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "aether",
    },
  },
}
