return {
  "hrsh7th/nvim-cmp",
--  event = "VeryLazy",
  dependencies = {
    "hrsh7th/cmp-buffer", -- source for text in buffer
    "hrsh7th/cmp-path", -- source for file system paths
    "L3MON4D3/LuaSnip", -- snippet engine
    "saadparwaiz1/cmp_luasnip", -- for autocompletion
    "rafamadriz/friendly-snippets", -- useful snippets
    "onsails/lspkind.nvim", -- vs-code like pictograms
    "jalvesaq/cmp-zotcite",
  },
  config = function()
    local cmp = require("cmp")

    local luasnip = require("luasnip")

    local lspkind = require("lspkind")

    require("luasnip.loaders.from_vscode").lazy_load({})
    require("luasnip.loaders.from_vscode").lazy_load({ paths = './my_snippets' })
    luasnip.filetype_extend("vimwiki", {"markdown"})
 local check_back_space = function()
  local col = vim.fn.col('.') - 1
  if col == 0 or vim.fn.getline('.'):sub(col, col):match('%s') then
    return true
  else
    return false
  end
end
--local function checkFMRI()
--    local buf_text = vim.api.nvim_buf_get_lines(0, 0, -1, false)
--    for _, line in ipairs(buf_text) do
--        if line:find("functional magnetic resonance imaging %(fMRI%)") then
--            return "fMRI"
--        end
--    end
--    return "functional magnetic resonance imaging (fMRI)"
--end
--
--luasnip.snippets = {
--    all = {
--        luasnip.parser.parse_snippet({
--            trig = "fmri",
--            name = "Prints 'functional magnetic resonance imaging (fMRI)' once; if already included, prints 'fMRI'",
--            dscr = "Prints 'functional magnetic resonance imaging (fMRI)' once in a file; if already included, prints 'fMRI'.",
--            wordTrig = false,
--            expanded = checkFMRI(),
--        }),
--    }
--}
cmp.setup({
      completion = {
        completeopt = "menu,menuone,preview,noselect",
      },
      snippet = { -- configure how nvim-cmp interacts with snippet engine
        expand = function(args)
          luasnip.lsp_expand(args.body)
        end,
      },
            mapping = cmp.mapping.preset.insert({
        ["<C-k>"] = cmp.mapping.select_prev_item(), -- previous suggestion
        ["<C-j>"] = cmp.mapping.select_next_item(), -- next suggestion
        ["<C-b>"] = cmp.mapping.scroll_docs(-4),
        ["<C-f>"] = cmp.mapping.scroll_docs(4),
        ["<C-Space>"] = cmp.mapping.complete(), -- show completion suggestions
        ["<C-e>"] = cmp.mapping.abort(), -- close completion window
        ["<CR>"] = cmp.mapping.confirm({ select = false }),
        ['<Tab>'] = cmp.mapping(function(fallback)
                if cmp.visible() then
                    cmp.confirm({select = true})
                elseif luasnip.jumpable(1) then
                    luasnip.jump(1)
                elseif check_back_space() then
                    fallback()
                else
                    cmp.complete()
                end
            end, {'i', 's'}),
            ['<S-Tab>'] = cmp.mapping(function() luasnip.jump(-1) end, {'i', 's'}),
            }),
      -- sources for autocompletion
      sources = cmp.config.sources({
        { name = "luasnip"}, -- snippets
        { name = "nvim_lsp" },
        { name = "buffer" }, -- text within current buffer
        { name = "path" }, -- file system paths
        { name = "cmp_zotcite" },
      }),
      -- configure lspkind for vs-code like pictograms in completion menu
      formatting = {
        format = lspkind.cmp_format({
          maxwidth = 50,
          ellipsis_char = "...",
        }),
      },
    })
  end,
}
