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
                    p =  {
                        name = "PDF",

                    p = { "<cmd>TermExec cmd='pandoc %:p -o %:p:r.pdf'<CR>"  , "pdf default engine"},
                    x = { "<cmd>TermExec cmd='pandoc --pdf-engine=xelatex %:p -o %:p:r.pdf'<CR>"  , "pdf xelatex engine"},
                    h = { "<cmd>TermExec cmd='pandoc --pdf-engine=wkhtmltopdf %:p -o %:p:r.pdf'<CR>"  , "pdf wkhtmltopdf engine"},
                    z = { "<cmd>TermExec cmd='pandoc %:p -o %:p:r.pdf -F ~/.local/share/nvim/lazy/zotcite/python3/zotref.py --citeproc --csl ~/googledrive/notes/apa.csl'<CR>" , "Convert to pdf (zotref.py/apa.csl)" }
                    },
                },
                k = {
                    name = "Gkeep2MD",
                    k = { "<cmd>TermExec cmd='python3 /home/linuxbrew/.linuxbrew/lib/python3.11/site-packages/keep-it-markdown-0.5.3/kim.py'<CR>", "kim"},
                },
                m ={
                    name = "MdTOC",
                    t = { "<cmd>TermExec cmd='markdown-toc -i %:p'<CR>" , "Create TOC"}
                },
                e = {name = "File Explorer"},
                f = {name = "Find Files"},
                t = {name = "Tab"},
                w = {name = "Vimwiki"},
                c = {name = "Code actions"},
                r = {name = "Smart Rename/ RestartLSP"},
                -- z = {name = "Folding"},
                z = {name = "Folding"},
            },
        })
    end
}
