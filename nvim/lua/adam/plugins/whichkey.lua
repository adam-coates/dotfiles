return {
  "folke/which-key.nvim",
  event = "VeryLazy",
  init = function()
    vim.o.timeout = true
    vim.o.timeoutlen = 300
    end,
    config = function()
        local wk = require('which-key')
        wk.register({
            ["<leader>"] = {
                p = {
                    name = "PANDOC",
                    w = { "<cmd>TermExec cmd='pandoc %:p -o %:p:r.docx'<CR>" , "word"},
                    m = { "<cmd>TermExec cmd='pandoc %:p -o %:p:r.md'<CR>"   , "markdown"},
                    h = { "<cmd>TermExec cmd='pandoc %:p -o %:p:r.html'<CR>" , "html"},
                    l = { "<cmd>TermExec cmd='pandoc %:p -o %:p:r.tex'<CR>"  , "latex"},
                    p = { "<cmd>TermExec cmd='pandoc %:p -o %:p:r.pdf'<CR>"  , "pdf"},
                 --   p = { "<cmd>2TermExec dir='G:\\My Drive\\notes' cmd='pandoc  -o test.pdf'<CR>"  , "pdf"},
                },
            },
        })
    end
}
