local map = vim.keymap.set

map("n", "<leader>ff", function()
  Snacks.picker.files()
end, { desc = "Find files" })

map("n", "<leader>fr", function()
  Snacks.picker.recent()
end, { desc = "Find recent files" })

map("n", "<leader>fs", function()
  Snacks.picker.grep()
end, { desc = "Find string in cwd" })

map("n", "<leader>fc", function()
  Snacks.picker.grep_word()
end, { desc = "Find word under cursor in cwd" })

map("n", "<leader>fb", function()
  Snacks.picker.buffers()
end, { desc = "Find open buffers" })

-- <leader>Z: zotcite uses <leader>z* in markdown, which made <leader>z wait.
map("n", "<leader>Z", function()
  Snacks.zen()
end, { desc = "Toggle zen mode" })

-- Explorer --------------------------------------------------------------------
local function explorer()
  return Snacks.picker.get({ source = "explorer" })[1]
end

map("n", "<leader>ee", function()
  local picker = explorer()
  if picker then
    picker:close()
  else
    Snacks.explorer()
  end
end, { desc = "Toggle file explorer" })

map("n", "<leader>ef", function()
  local picker = explorer()
  if picker then
    picker:close()
  else
    Snacks.explorer.reveal()
  end
end, { desc = "Toggle file explorer on current file" })

map("n", "<leader>ec", function()
  local picker = explorer()
  if picker then
    picker:action("explorer_close_all")
  end
end, { desc = "Collapse file explorer" })

map("n", "<leader>er", function()
  local picker = explorer()
  if picker then
    picker:action("explorer_update")
  end
end, { desc = "Refresh file explorer" })

-- Git -------------------------------------------------------------------------
map("n", "<leader>lg", function()
  Snacks.lazygit()
end, { desc = "Open LazyGit" })

-- Figures and images --------------------------------------------------------
-- Both go in images/ next to the current file.
map("n", "<leader>if", function()
  require("utils.figure").create()
end, { desc = "Inkscape figure from current line" })
map("i", "<C-f>", function()
  require("utils.figure").create()
end, { desc = "Inkscape figure from current line" })
map("n", "<leader>ip", "<cmd>PasteImage<cr>", { desc = "Paste image from clipboard" })
map("n", "<localleader>p", "<cmd>PasteImage<cr>", { desc = "Paste image from clipboard" })

-- Undo history ----------------------------------------------------------------
map("n", "<leader>u", function()
  Snacks.picker.undo()
end, { desc = "Undo history" })

-- General ---------------------------------------------------------------------
local keymap = vim.keymap

keymap.set("n", "<leader>s", [[:%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>]], { desc = "Replace current word" })

-- window management
keymap.set("n", "<leader>sv", "<C-w>v", { desc = "Split window vertically" })
keymap.set("n", "<leader>sh", "<C-w>s", { desc = "Split window horizontally" })
keymap.set("n", "<leader>se", "<C-w>=", { desc = "Make splits equal size" })
keymap.set("n", "<leader>sx", "<cmd>close<CR>", { desc = "Close current split" })

-- scroll in middle
keymap.set("n", "<C-d>", "<C-d>zz")
keymap.set("n", "<C-u>", "<C-u>zz")

keymap.set("x", "p", '"_dP')

-- move selected lines up or down
keymap.set("v", "J", ":m '>+1<CR>gv=gv")
keymap.set("v", "K", ":m '<-2<CR>gv=gv")

-- Better movement
-- Move by screen line on wrapped text, but by real line with a count, so
-- relative line numbers (5j) still match.
vim.keymap.set({ "n", "x" }, "j", "v:count == 0 ? 'gj' : 'j'", { expr = true, silent = true })
vim.keymap.set({ "n", "x" }, "k", "v:count == 0 ? 'gk' : 'k'", { expr = true, silent = true })
