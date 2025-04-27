vim.g.mapleader = " "
vim.g.maplocalleader = ","

vim.g['quarto_is_r_mode'] = nil
vim.g['reticulate_running'] = false
local keymap = vim.keymap -- for conciseness
local ms = vim.lsp.protocol.Methods

local nmap = function(key, effect)
  vim.keymap.set('n', key, effect, { silent = true, noremap = true })
end

local imap = function(key, effect)
  vim.keymap.set('i', key, effect, { silent = true, noremap = true })
end


local function send_cell()
  if vim.b['quarto_is_r_mode'] == nil then
    vim.fn['slime#send_cell']()
    return
  end
  if vim.b['quarto_is_r_mode'] == true then
    vim.g.slime_python_ipython = 0
    local is_python = require('otter.tools.functions').is_otter_language_context 'python'
    if is_python and not vim.b['reticulate_running'] then
      vim.fn['slime#send']('reticulate::repl_python()' .. '\r')
      vim.b['reticulate_running'] = true
    end
    if not is_python and vim.b['reticulate_running'] then
      vim.fn['slime#send']('exit' .. '\r')
      vim.b['reticulate_running'] = false
    end
    vim.fn['slime#send_cell']()
  end
end

--- Send code to terminal with vim-slime
--- If an R terminal has been opend, this is in r_mode
--- and will handle python code via reticulate when sent
--- from a python chunk.
local slime_send_region_cmd = ':<C-u>call slime#send_op(visualmode(), 1)<CR>'
slime_send_region_cmd = vim.api.nvim_replace_termcodes(slime_send_region_cmd, true, false, true)
local function send_region()
  -- if filetyps is not quarto, just send_region
  if vim.bo.filetype ~= 'quarto' or vim.b['quarto_is_r_mode'] == nil then
    vim.cmd('normal' .. slime_send_region_cmd)
    return
  end
  if vim.b['quarto_is_r_mode'] == true then
    vim.g.slime_python_ipython = 0
    local is_python = require('otter.tools.functions').is_otter_language_context 'python'
    if is_python and not vim.b['reticulate_running'] then
      vim.fn['slime#send']('reticulate::repl_python()' .. '\r')
      vim.b['reticulate_running'] = true
    end
    if not is_python and vim.b['reticulate_running'] then
      vim.fn['slime#send']('exit' .. '\r')
      vim.b['reticulate_running'] = false
    end
    vim.cmd('normal' .. slime_send_region_cmd)
  end
end

nmap('<c-cr>', send_cell)
nmap('<s-cr>', send_cell)
imap('<c-cr>', send_cell)
imap('<s-cr>', send_cell)


local is_code_chunk = function()
  local current, _ = require('otter.keeper').get_current_language_context()
  if current then
    return true
  else
    return false
  end
end



local insert_code_chunk = function(lang)
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<esc>', true, false, true), 'n', true)
  local keys
  if is_code_chunk() then
    keys = [[o```<cr><cr>```{]] .. lang .. [[}<esc>o]]
  else
    keys = [[o```{]] .. lang .. [[}<cr>```<esc>O]]
  end
  keys = vim.api.nvim_replace_termcodes(keys, true, false, true)
  vim.api.nvim_feedkeys(keys, 'n', false)
end

local insert_r_chunk = function()
  insert_code_chunk 'r'
end

local insert_py_chunk = function()
  insert_code_chunk 'python'
end

local function new_terminal(lang)
  vim.cmd('vsplit term://' .. lang)
end


local function new_terminal_python()
  new_terminal 'python'
end


local function new_terminal_r()
  new_terminal 'R --no-save'
end

local function new_terminal_ipython()
  new_terminal 'ipython --no-confirm-exit'
end

local function get_otter_symbols_lang()
  local otterkeeper = require'otter.keeper'
  local main_nr = vim.api.nvim_get_current_buf()
  local langs = {}
  for i,l in ipairs(otterkeeper.rafts[main_nr].languages) do
    langs[i] = i .. ': ' .. l
  end
  -- promt to choose one of langs
  local i = vim.fn.inputlist(langs)
  local lang = otterkeeper.rafts[main_nr].languages[i]
  local params = {
    textDocument = vim.lsp.util.make_text_document_params(),
    otter = {
      lang = lang
    }
  }
  -- don't pass a handler, as we want otter to use it's own handlers
  vim.lsp.buf_request(main_nr, ms.textDocument_documentSymbol, params, nil)
end

vim.keymap.set("n", "<m-s>", get_otter_symbols_lang, {desc = "otter [s]ymbols"})

keymap.set("n", "<m-I>", insert_py_chunk, {desc = "python code chunk"})

keymap.set("n", "<m-i>", insert_r_chunk, {desc = "r code chunk"})

keymap.set("i", "<m-I>", insert_py_chunk, {desc = "python code chunk"})

keymap.set("i", "<m-i>", insert_r_chunk, {desc = "r code chunk"})

keymap.set("v", "<cr>", send_region, {desc = "run code region"})

keymap.set("n", "<leader><cr>", send_cell, {desc = "run code cell"})

keymap.set("n", "<leader>ci", new_terminal_ipython, {desc = "new [i]python terminal"})

keymap.set("n", "<leader>cp", new_terminal_python, {desc = "new [p]ython terminal"})
keymap.set("n", "<leader>cr", new_terminal_r, {desc = "new [R] terminal"})



-- increment/decrement numbers
keymap.set("n", "<leader>+", "<C-a>", { desc = "Increment number" }) -- increment
keymap.set("n", "<leader>-", "<C-x>", { desc = "Decrement number" }) -- decrement

-- window management
keymap.set("n", "<leader>sv", "<C-w>v", { desc = "Split window vertically" }) -- split window vertically
keymap.set("n", "<leader>sh", "<C-w>s", { desc = "Split window horizontally" }) -- split window horizontally
keymap.set("n", "<leader>se", "<C-w>=", { desc = "Make splits equal size" }) -- make split windows equal width & height
keymap.set("n", "<leader>sx", "<cmd>close<CR>", { desc = "Close current split" }) -- close current split window

keymap.set("n", "<leader>to", "<cmd>tabnew<CR>", { desc = "Open new tab" }) -- open new tab
keymap.set("n", "<leader>tx", "<cmd>tabclose<CR>", { desc = "Close current tab" }) -- close current tab
keymap.set("n", "<leader>tn", "<cmd>tabn<CR>", { desc = "Go to next tab" }) --  go to next tab
keymap.set("n", "<leader>tp", "<cmd>tabp<CR>", { desc = "Go to previous tab" }) --  go to previous tab
keymap.set("n", "<leader>tf", "<cmd>tabnew %<CR>", { desc = "Open current buffer in new tab" }) --  move current buffer to new tab

-- replace current word on
keymap.set("n", "<leader>s", [[:%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>]], { desc = "Replace current word" })

-- scroll in middle
keymap.set("n", "<C-d>", "<C-d>zz")
keymap.set("n", "<C-u>", "<C-u>zz")

keymap.set("x", "p", "\"_dP")

-- move selected liens up or down 
keymap.set("v", "J", ":m '>+1<CR>gv=gv")
keymap.set("v", "K", ":m '<-2<CR>gv=gv")

keymap.set("n", "<leader>on", function()
  if vim.fn.bufname('%') == '' and vim.fn.line('$') == 1 and vim.fn.getline(1) == '' then
    local title = vim.fn.input("Enter note title: ")
    if title == "" then
      print("Title cannot be empty!")
      return
    end

    local dir = vim.fn.expand("~/notes/00 - Inbox/")
    local filename = dir .. title .. ".md"

    vim.fn.mkdir(dir, "p")

    vim.cmd("edit " .. filename)

    vim.cmd("write")
  end

  local original_cwd = vim.fn.getcwd()

  vim.cmd("cd ~/notes")

  vim.cmd(":ObsidianTemplate note")

  vim.cmd("cd " .. original_cwd)
end, { desc = "Create Obsidian note with template" })


-- Bold: position cursor between **
vim.keymap.set('v', '<leader>b', 'c****<Esc>hhp')

-- Italic: position cursor between *
vim.keymap.set('v', '<leader>i', 'c**<Esc>hp')

-- Both: position cursor between ***
vim.keymap.set('v', '<leader>bi', 'c******<Esc>hhhp')


-- Search for files in notes
vim.keymap.set("n", "<leader>os", ":Telescope find_files search_dirs={\"/home/adam/notes\"}<cr>", {desc = "find notes files"})
vim.keymap.set("n", "<leader>oz", ":Telescope live_grep search_dirs={\"/home/adam/notes\"}<cr>", {desc = "grep notes"})

vim.keymap.set("n", "j", "gj", { noremap = true, silent = true })
vim.keymap.set("n", "k", "gk", { noremap = true, silent = true })
vim.keymap.set("v", "j", "gj", { noremap = true, silent = true })
vim.keymap.set("v", "k", "gk", { noremap = true, silent = true })
