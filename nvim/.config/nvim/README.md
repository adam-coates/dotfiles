# Neovim: code and notes

Obsidian and its most useful plugins, in Neovim, together with everything from your previous config: language servers, formatting, debugging, Quarto and REPLs, Word review, tables, the receipt printer. It works on any folder of markdown files and on Obsidian vaults as they are.

It lives in `~/dotfiles/nvim` and is linked to `~/.config/nvim` with stow. The config it replaced is kept in `~/.config/nvim-backup` and under the tag `nvim-before-notes` in the dotfiles repository (see *Going back*).

The first start installs the plugins and parsers itself. That takes about a minute; mason then installs your previous config's language servers, linters, formatters and debugger, plus Harper and Tectonic, in the background (about 1.5 GB, a few minutes). The demo vault, `~/nvim-test-vault`, doubles as a guide: start with *Guide/Start here*, or press `<Space>?` for every key.

Your vault, `~/notes`, is the first in `vaults` in `lua/settings.lua` (`<Space>ws`), with its own folders (`00 - Inbox`, `03 - Logs/Daily`, `999-extra/Templates`, …), your templates, weekly notes named after their Monday, and `ask_location`: a new note (`<Space>nn`) asks for its title, location and tags, is made in that folder and gets `location` in its properties. `<Space>nm` moves a note and updates `location`, `<Space>nf` files a note where its location says, `<Space>nF` does that for the whole inbox, `<Space>na` adds a person to `05 - People`. Any vault can have its own settings like that; the demo keeps the defaults.

To try another folder without editing anything:

```sh
NOTES_VAULT=~/Nextcloud/Notes nvim
```

## What's in it

| | Feature | Done by |
|---|---|---|
| **Notes** | `[[links]]`, aliases, headings `[[##`, blocks `[[^^`, footnotes, tags, completion | obsidian.nvim (its own language server) |
| | Renaming a note, heading or tag and updating every link | obsidian.nvim, `refactor.lua` for tags |
| | Quick switcher that creates notes, search, headings everywhere | `pickers.lua` on snacks.picker |
| | Embeds `![[Note#Heading]]`, wrapped to the window | obsidian.nvim, wrapping in `plugins/obsidian.lua` |
| | Peek at a link (`K`), back with `Backspace` | `hover.lua` |
| | Unlinked mentions, link suggestions | obsidian.nvim, `index.lua` + the panel |
| | Templates with variables, unique notes, bookmarks, properties | obsidian.nvim, `template.lua` |
| **Looks** | Live preview: headings, callouts, tables, checkboxes, links | render-markdown.nvim |
| | Tags, comments, block ids, inline fields, missing links, task dates | `decor.lua` |
| | Inline images, LaTeX maths (and Mermaid with `mmdc`) | snacks.image, Tectonic |
| | Follows the Omarchy theme, switching live | `config/theme.lua` (from your previous config) |
| **Sidebar** | Calendar, outline, backlinks, unlinked mentions, outgoing links, tags, properties | `panel.lua`, `calendar.lua` |
| **Journal** | Daily, weekly, monthly, yearly notes; calendar; dates in plain words | `periodic.lua`, `date.lua` |
| | Quick capture from anywhere (`:Capture`) | `capture.lua` |
| **Tasks** | Obsidian Tasks format, dates, priorities, recurrence | `tasks.lua` |
| | Agenda, task queries (```` ```tasks ````) | `agenda.lua`, `query/tasksq.lua`, `blocks.lua` |
| | Todoist in the agenda, calendar, ```` ```todoist ```` blocks; Quick Add; sending a task from a note | `todoist.lua` (API v1) |
| | Kanban boards (Obsidian Kanban format) | `kanban.lua` |
| **Queries** | Dataview: LIST, TABLE, TASK, FROM, WHERE, SORT, GROUP BY, FLATTEN, inline `= expr` | `query/dql.lua`, `query/expr.lua` |
| **Canvas** | Excalidraw drawings, mind maps from lists, boards of note cards, shown inline as images | `canvas.lua`, `assets/canvas.html` + Excalidraw |
| **Graph** | Live graph in the browser that follows you and opens notes on click | `graph.lua`, `assets/graph.html` |
| | Neighbourhood tree in the terminal | `graph.lua` |
| **Learning** | Flashcards (Obsidian Spaced Repetition format) | `cards.lua` |
| | Zotero: citations, literature notes with annotations | zotcite, `zotero.lua` |
| **Writing** | Lists, tables, formatting, callouts, footnotes, smart URL paste | markdown-plus.nvim, mini.surround |
| | Grammar, spelling, formatting | Harper and LTeX+, Vim spell, prettier (`<Space>mp`, never on save) |
| | Zen mode, typewriter scrolling, dimming | snacks.nvim |
| | Pasting and dropping images, drawings in Inkscape, audio recordings | obsidian.nvim, img-clip.nvim, `figure.lua` |
| **Out** | Export to PDF, Word, HTML, slides, LaTeX, EPUB | `export.lua` + pandoc/typst |
| | Browser preview, slides in Neovim | your markdown-preview.nvim fork, obsidian.nvim |
| | Git sync (commit, pull, push, optional timer), history | `sync.lua`, gitsigns, lazygit |
| | Search and replace across the vault | grug-far.nvim |

### From your previous config

Copied from `~/.config/nvim` (read only) and merged:

| What | Where it is now |
|---|---|
| Options, keys, dashboard, statusline | `config/options.lua`, `config/keymaps.lua`, `config/dashboard.lua`, `utils/statusline.lua` (plus the vault path, backlinks, tasks due and sync in notes) |
| LSP servers, mason tools, lazydev, diagnostics | `plugins/lsp.lua` |
| conform with format on save (not for markdown) | `plugins/formatting.lua` |
| LuaSnip and your selection-wrapping snippets | `plugins/completion.lua`, `plugins/snippets.lua` |
| Quarto, otter, vim-slime, REPLs in herdr/tmux | `plugins/quarto.lua`, `utils/repl.lua`, `autoload/slime/targets/herdr.vim` |
| nvim-dap and dap-ui for Python | `plugins/debug.lua` |
| Word review, tables from text, receipt printer | `utils/docx.lua`, `plugins/tables.lua`, `plugins/printer.lua` |
| Quarto divs in the buffer, themed preview, figures | `utils/quarto_render.lua`, `utils/markdown_preview.lua`, `utils/figure.lua` |
| Zotero pickers in Snacks, annotations | `utils/zotcite_snacks.lua`, `utils/zotero_annotations.lua` |
| Typst watch and preview | `ftplugin/typst.lua` |

Where both configs had the same key, it does the notes thing in a vault note and your previous config's thing elsewhere. A few keys moved: flashcards to `<Space>k`, printing to `<Space>P`, the neighbourhood to `<Space>pt` (`<Space>lg` is LazyGit again), and the debug keys only exist in Python files, where `<Space>d` would otherwise be daily notes. `doc/keys.md` (`<Space>?`) has the full list. Two start screens: yours, and the notes one (`o` on yours, `<Space>ph`); `start_screen` in the settings picks the first.

### Why some of it is local code

I tried the existing plugins first and kept them wherever they held up:

- **obsidian-tasks.nvim**: it doesn't create the next occurrence of a recurring task yet. In notes with queries it takes over `u` and `:w`: in a test, `u` reverted a task toggle in another file instead of my last edit.
- **kanban.nvim and super-kanban.nvim**: both re-write the board from what they parsed. In tests they dropped frontmatter, merged multi-line cards and moved the `**Complete**` marker. The local board moves the card's own lines in the buffer, so nothing else changes and `u` works.
- **dynomark.nvim** (Dataview-like) needs an external program, has its own language and hasn't changed since 2025. **calendar.nvim** opens in a fixed corner and asks what to do on each `<CR>`. The flashcard plugins need telescope and image.nvim, or keep their schedule outside the notes.
- **excalidraw.nvim** opens drawings in Chrome's Excalidraw app and can't show them in the note. Canvases here are SVGs with the scene inside, so they show inline, in Obsidian and in exports.
- **Todoist plugins**: they use the Sync API v9, which Todoist has retired (it answers `410 Gone`); that includes adam-coates/todoist.nvim. damnit.nvim is for a different task store. `todoist.lua` uses the current API v1.
- There's no graph or backlinks sidebar plugin.

The local modules are plain Lua in `lua/notes/`, one file per feature, with tests.

## Layout

```
init.lua               load order
lua/settings.lua       everything you'd change: vaults, folders, behaviour
lua/config/            options, plugins (vim.pack), theme, keymaps, autocmds, dashboards
lua/plugins/           plugin setup
lua/notes/             the local modules
lua/utils/             modules from your previous config
ftplugin/ autoload/    from your previous config (Typst keys, herdr target for vim-slime)
assets/graph.html      the graph page
doc/keys.md            the keys (<Space>?)
snippets/              markdown snippets
```

## Commands

`:Today` `:Week` `:Calendar` `:Agenda` `:Task call Anna tomorrow` `:Todoist …` `:TodoistToken` `:Capture` `:Board` `:Canvas` `:MindMap` `:Graph` `:Review` `:Sync` `:Export pdf` `:Keys`, and all of `:Obsidian …`. From your previous config: `:Table` `:DocxReview` `:ZoteroAnnotations` `:PrintBuffer` `:QuartoPreview`. `:PackUpdate` updates the plugins and `:checkhealth notes` checks the tools.

## Notes

- Notes save themselves a moment after you stop typing (`autosave` in the settings). Markdown is never formatted on save for that reason; `<Space>mp` runs prettier when you want it.
- Undo history lives in `~/.vim/undodir`, as in your previous config, so it carried over.
- Nothing is added to a note behind your back. Unlike obsidian.nvim's default, frontmatter isn't rewritten on save.
- Zotero's database is only read (`immutable=1`).
- A vault that is a git repository (yours: `github.com/adam-coates/notes`) syncs when Neovim starts, every 5 minutes, and when it quits, and on `<Space>gs`; `sync` in the settings turns any of that off. Only notes are saved before a commit, never other files. A failed pull is undone, which leaves the vault as it was, and a push the remote refuses waits for the next sync.
- The graph and canvas pages are served from Neovim on 127.0.0.1 behind a random token that changes every session, and only answer requests addressed to localhost. The canvas page can only write `.svg` files inside the vault.
- The Todoist token is read from `$TODOIST_API_TOKEN` or a file in this config's data folder with mode 600, and handed to curl on stdin, never on its command line.
- Canvases and pasted images are embedded with their folder (`![[Canvas/Map.svg]]`), so the link stays unambiguous when two folders hold files of the same name.

## Going back

The previous config, as it was, runs next to this one:

```sh
NVIM_APPNAME=nvim-backup nvim      # the copy in ~/.config/nvim-backup
```

To make it the main config again, restore it into the stow package:

```sh
cd ~/dotfiles && git rm -rq nvim/.config/nvim && git checkout nvim-before-notes -- nvim
```
