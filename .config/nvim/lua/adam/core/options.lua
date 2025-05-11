local opt = vim.opt

-- set spell
opt.spelllang = "en_gb"
opt.spell = true
opt.encoding = "utf-8"
opt.fileencoding = "utf-8"


-- line numbers
opt.relativenumber = true
opt.number = true

-- tabs & indentation
opt.tabstop = 4
opt.shiftwidth = 4
opt.expandtab = true
opt.autoindent = true

-- line wrapping
opt.wrap = false

-- search settings
opt.ignorecase = true
opt.smartcase = true

-- cursor line
opt.cursorline = true

-- appearance
opt.termguicolors = true
--opt.signcolumn = "yes"

-- backspace
opt.backspace = "indent,eol,start"

-- clipboard
opt.clipboard:append("unnamedplus")

-- split windows
opt.splitright = true
opt.splitbelow = true

opt.iskeyword:append("-")

-- leave 8 rows bottom and top while scrolling
opt.scrolloff = 8

opt.cmdheight = 1

-- undos saved
opt.swapfile = false
opt.backup = false
opt.undodir = os.getenv("HOME") .. "/.vim/undodir"
opt.undofile = true

vim.o.foldenable = true
vim.o.foldlevel = 99
vim.o.foldmethod = 'expr'
-- Default to treesitter folding
vim.o.foldexpr = 'v:lua.vim.treesitter.foldexpr()'
-- Prefer LSP folding if client supports it
vim.api.nvim_create_autocmd('LspAttach', {
    callback = function(args)
         local client = vim.lsp.get_client_by_id(args.data.client_id)
         if client:supports_method('textDocument/foldingRange') then
             local win = vim.api.nvim_get_current_win()
             vim.wo[win][0].foldexpr = 'v:lua.vim.lsp.foldexpr()'
        end
    end,
 })
vim.o.foldtext = ""
vim.opt.foldcolumn = "0"
vim.opt.fillchars:append({fold = " "})

-- Define the markdown_fold function as a global function
--
--
--
--local function markdown_level()
--    local line = vim.fn.getline(vim.v.lnum)
--    
--    if line:match('^# .*$') then
--        return '>1'
--    elseif line:match('^## .*$') then
--        return '>2'
--    elseif line:match('^### .*$') then
--        return '>3'
--    elseif line:match('^#### .*$') then
--        return '>4'
--    elseif line:match('^##### .*$') then
--        return '>5'
--    elseif line:match('^###### .*$') then
--        return '>6'
--    end
--    return '='
--end
--
---- Make the function available globally
--_G.markdown_level = markdown_level
--
---- Set up autocommands for both markdown and quarto files
--vim.api.nvim_create_autocmd('FileType', {
--    pattern = {'markdown', 'quarto'},
--    callback = function()
--        vim.wo.foldexpr = 'v:lua.markdown_level()'
--        vim.wo.foldmethod = 'expr'
--        vim.wo.foldenable = true
--        vim.cmd('normal zR')  -- Open all folds initially
--    end
--})

--vim.wo.foldmethod = 'expr'
--vim.wo.foldexpr = 'nvim_treesitter#foldexpr()'
--vim.wo.foldlevel = 99
--
---- If you want to use manual markdown folding instead of treesitter:
--vim.cmd([[
--  function! MarkdownLevel()
--      let h = matchstr(getline(v:lnum), '^#\+')
--      if empty(h)
--          return "="
--      endif
--      return ">" . len(h)
--  endfunction
--
--  augroup MarkdownFolding
--      autocmd!
--      autocmd FileType markdown,quarto setlocal foldmethod=expr
--      autocmd FileType markdown,quarto setlocal foldexpr=MarkdownLevel()
--      " Start with all folds open
--      autocmd FileType markdown,quarto setlocal foldlevel=99
--  augroup END
--]])
--_G.markdown_fold = function()
--    -- Get the current line number
--    local lnum = vim.v.lnum
--    -- Get the current line content
--    local line = vim.fn.getline(lnum)
--    
--    -- Add debug print (temporary)
--    print(string.format("Line %d: '%s'", lnum, line))
--    
--    -- Check for Markdown headings (e.g., #, ##, ###, etc.)
--    local heading_level = line:match("^(#+)")
--    if heading_level then
--        -- Return the fold level based on the number of '#' characters
--        local level = ">" .. #heading_level
--        print("Found heading level: " .. level)  -- Debug print
--        return level
--    end
--    
--    return "="
--end
--
---- Set the folding method for Markdown and Quarto files
--vim.api.nvim_create_autocmd('FileType', {
--    pattern = { 'markdown', 'quarto' },
--    callback = function()
--        -- Enable folding
--        vim.opt_local.foldmethod = 'expr'
--        vim.opt_local.foldexpr = 'v:lua.markdown_fold()'
--        vim.opt_local.foldenable = true
--        vim.opt_local.foldlevel = 99
--        
--        -- Print debug info
--        print("Markdown folding enabled")
--        print("foldmethod: " .. vim.opt_local.foldmethod:get())
--        print("foldexpr: " .. vim.opt_local.foldexpr:get())
--    end,
--})
-- vim.g.markdown_folding = 1

--vim.opt.list = true
--vim.opt.listchars = {
--    space = "⋅",
--    eol = "↴",
--    tab = "▎_",
--    tab = "|_>",
--      tab = "| ",
--    trail = "•",
--    extends = "❯",
--    precedes = "❮",
--    nbsp = "",
--}
--vim.opt.fillchars = {
--    fold = " ",
--    foldsep = " ",
--    foldopen = "",
--    foldclose = "",
--    diff = "╱",
--}
-- Set the char for the indent line
--vim.g.indentline_char = '│'
