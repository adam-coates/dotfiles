# Keys

Leader is `Space`, local leader is `,`. Wait a moment after `Space` for a menu.

Your previous config's keys are all here. Where both configs used a key, it does the notes thing in a vault note and your previous config's thing elsewhere (`ff`, `fs`, `fc`, `fr`, `ip`, `if`). Keys that had to move are marked **moved**.

## In a note

| Key              | What it does                                            |
| ---------------- | ------------------------------------------------------- |
| `Enter`          | follow link or tag, tick task, fold heading, list results of a query, edit a canvas |
| `Backspace`      | back                                                    |
| `K`              | peek at the link (again: go in)                         |
| `gd` `gr`        | follow the link, backlinks (in code: definition, references) |
| `]o` `[o`        | next / previous link                                    |
| `]t` `[t`        | next / previous open task                               |
| `]p` `[p`        | next / previous daily, weekly, monthly note             |
| `]]` `[[`        | next / previous heading                                 |
| `]s` `[s` `z=` `zg` | spelling: next, previous, suggestions, add           |
| `gl`             | what the grammar checker says here                      |
| `za` `zM` `zR`   | fold, fold all, unfold all                              |
| `Ctrl-a` `Ctrl-x`| scroll an embed (or change the number)                  |
| `Ctrl-s`         | save (notes also save themselves)                       |
| `Space s`        | replace the word under the cursor everywhere (after a pause) |

## While typing

| Type     | For                                   |
| -------- | ------------------------------------- |
| `[[`     | a note; `[[##` a heading, `[[^^` a block |
| `#`      | a tag                                 |
| `@`      | a date (`@friday`) or a citation      |
| `:`      | an emoji                              |
| `> [!`   | a callout                             |
| `[^`     | a footnote                            |
| `Tab`    | accept, next field, indent a list     |
| `Ctrl-l` | fix the last spelling mistake         |
| `Ctrl-s` | expand a snippet (with nothing to expand: save) |
| `Ctrl-u` | choose a snippet's option             |
| `Ctrl-f` | the line becomes an Inkscape figure   |
| `Ctrl-k` | function signature (code)             |

To wrap text in a snippet: select it, `Ctrl-s`, type the trigger (`b`, `quote`, `note`, `task`, `h2`, …), `Tab`.
| `Alt-hjkl` | move between table cells            |

## Space …

| Key        | What it does                    | Key        | What it does                   |
| ---------- | ------------------------------- | ---------- | ------------------------------ |
| `Space`    | find or create a note           | `/`        | search all text                |
| `,`        | open notes                      | `.`        | context panel                  |
| `?`        | this                            | `u`        | undo history                   |
| `ee` `ef`  | explorer, on this file          | `Z`        | zen mode                       |
| `ec` `er`  | collapse, refresh the explorer  | `s`        | replace word under the cursor  |

### n: note

| Key   | What it does            | Key   | What it does            |
| ----- | ----------------------- | ----- | ----------------------- |
| `nn`  | new                     | `nt`  | new from a template     |
| `nc`  | quick capture           | `nu`  | new, named by the time  |
| `nr`  | rename, updating links  | `nm`  | move to a folder (sets location) |
| `nM`  | merge into another      | `nd`  | delete                  |
| `np`  | set a property          | `nP`  | browse properties       |
| `nb`  | bookmark                | `ny`  | copy a link to it       |
| `nx`  | random note             | `na`  | new person              |
| `nf`  | file this note where its location says | `nF` | file the inbox notes the same way |

### d: daily and calendar

| Key   | What it does            | Key   | What it does            |
| ----- | ----------------------- | ----- | ----------------------- |
| `dd`  | today                   | `dc`  | calendar                |
| `dy`  | yesterday               | `dt`  | tomorrow                |
| `dw`  | this week               | `dm`  | this month              |
| `dY`  | this year               | `dj`  | a day, in words         |
| `dl`  | list daily notes        | `do`  | on this day             |

### l: links

| Key   | What it does              | Key   | What it does               |
| ----- | ------------------------- | ----- | -------------------------- |
| `ll`  | insert, or link selection | `ln`  | link to a new note         |
| `lb`  | backlinks                 | `lo`  | links in this note         |
| `lu`  | unlinked mentions here    | `lU`  | unlinked mentions of this  |
| `lg`  | LazyGit (**moved**: neighbourhood is `pt`) | `lx`  | broken links |
| `lr`  | remove link, keep text    | `lf`  | footnotes                  |
| `lv`  | follow beside             | `ls`  | follow below               |

### f: find

| Key   | What it does       | Key   | What it does       |
| ----- | ------------------ | ----- | ------------------ |
| `ff`  | notes (elsewhere: files) | `fs`  | text in notes (elsewhere: in the folder) |
| `fr`  | recent notes (or files) | `fc`  | word under cursor  |
| `fF`  | files in the folder |       |                    |
| `ft`  | tags               | `fh`  | headings           |
| `fo`  | outline            | `fp`  | properties         |
| `fm`  | bookmarks          | `fa`  | attachments        |
| `fO`  | orphans            | `fU`  | notes without tags |
| `fb`  | open buffers       | `f.`  | last search again  |
| `fk`  | keymaps            | `fH`  | Neovim help        |

### t: tasks

| Key   | What it does            | Key   | What it does            |
| ----- | ----------------------- | ----- | ----------------------- |
| `tt`  | agenda                  | `ta`  | add                     |
| `tx`  | done / make it a task   | `tc`  | next status             |
| `td`  | due date                | `ts`  | scheduled date          |
| `tS`  | start date              | `tp`  | priority                |
| `tr`  | repeat                  | `tl`  | list                    |
| `tk`  | boards                  | `tK`  | this note as a board    |
| `tT`  | add to Todoist          | `tm`  | send this task to Todoist |
| `to`  | open in Todoist         |       |                         |

### p: panels, i: insert

| Key   | What it does              | Key   | What it does              |
| ----- | ------------------------- | ----- | ------------------------- |
| `pp`  | context panel             | `pf`  | go to the panel           |
| `po`  | outline                   | `pb`  | backlinks                 |
| `pm`  | unlinked mentions         | `pe`  | files                     |
| `pg`  | graph (browser)           | `pl`  | local graph (browser)     |
| `pc`  | calendar                  | `ph`  | notes start screen        |
| `pt`  | neighbourhood (terminal)  | `pn`  | notifications             |
| `it`  | template                  | `ip`  | image from the clipboard (outside a vault into `images/`) |
| `iP`  | image from a URL or path  | `if`  | Inkscape figure from the line |
| `ia`  | attachment                | `ir`  | record audio              |
| `ie`  | embed                     | `il`  | link                      |
| `id`  | date                      | `iT`  | time                      |
| `iq`  | callout                   | `ib`  | table                     |
| `ic`  | code block                | `in`  | footnote                  |
| `ig`  | tag                       | `iz`  | citation                  |
| `iw`  | canvas                    | `im`  | mind map of a list        |

### k: flashcards (**moved** from `c`), v: view

| Key   | What it does           | Key   | What it does            |
| ----- | ---------------------- | ----- | ----------------------- |
| `kk`  | review                 | `kd`  | choose a deck           |
| `kn`  | review this note       | `ks`  | statistics              |
| `vz`  | zen mode               | `vt`  | typewriter scrolling    |
| `vd`  | dim other paragraphs   | `vn`  | line numbers            |
| `vr`  | rendering              | `vc`  | show markup             |
| `vq`  | query results          | `vi`  | image under the cursor  |
| `vs`  | spelling               | `vl`  | spelling language       |
| `vg`  | grammar                | `vw`  | wrap                    |

### g: git, x: export, r: refactor

| Key   | What it does            | Key   | What it does               |
| ----- | ----------------------- | ----- | -------------------------- |
| `gs`  | sync                    | `gg`  | lazygit                    |
| `gl`  | history of this note    | `gL`  | history of the vault       |
| `gd`  | changes to this note    | `gi`  | make it a repository       |
| `xe`  | export                  | `xf`  | export PDF                 |
| `xp`  | preview in the browser  | `xs`  | present as slides          |
| `rr`  | search and replace      | `rt`  | rename a tag               |
| `re`  | section to its own note | `rE`  | the same, embedded         |
| `rf`  | tidy formatting         | `rw`  | replace word               |

### w: vault, z: zotero

| Key   | What it does       | Key   | What it does            |
| ----- | ------------------ | ----- | ----------------------- |
| `ww`  | switch vault       | `wr`  | re-read the vault       |
| `ws`  | settings           | `wh`  | health                  |
| `zz`  | Zotero             | `zu`  | add new annotations     |
| `zi`  | about this citation| `zo`  | open its PDF            |
| `za`  | full reference     | `zv`  | view the document       |
| `zb`  | paste the abstract |       |                         |

### From your previous config

| Key   | What it does               | Key   | What it does                |
| ----- | -------------------------- | ----- | --------------------------- |
| `ca`  | code action                | `cr`  | rename symbol (in a note: the note) |
| `cd`  | line diagnostic            | `cv`  | definition in a split       |
| `cip` `cir` `cib` | start IPython, R, Bash REPL | `cl` `cm` | list REPL panes, pick one |
| `li`  | LSP info                   | `lh`  | inlay hints on / off        |
| `lr`  | LSP restart (code only; in a note it unlinks) | `mp` | format (notes: prettier, only here) |
| `mt`  | make a table from text     | `mT`  | the same, asking Claude     |
| `ow`  | review a Word document's changes | `qp` `qq` | Quarto preview, close it |
| `qa`  | Quarto activate            |       |                             |
| `Pb`  | print buffer (**moved** from `pb`) | `Pl` | print line (**moved**)  |
| `PL`  | live printing (**moved**)  | `Pp`  | print selection (**moved**) |

In Python files (where there's a debugger), `<Space>d` also debugs: `db` breakpoint, `dc` continue, `do` `di` `dO` step over, into, out, `dq` quit, `du` the debug UI. In Typst files, `tw` watches and `tp` opens the PDF.

Code everywhere: `K` hover, `gd` `gD` `gr` `gi` `gy` go to, `[d` `]d` diagnostics, `Ctrl-c Ctrl-c` sends the cell (or selection) to the REPL, `,rc` `,ra` `,rb` `,rA` `,rl` run cell, above, below, all, line, `,r` the selection, `,p` paste an image.

## Comma … (formatting)

| Key           | What it does                  | Key          | What it does             |
| ------------- | ----------------------------- | ------------ | ------------------------ |
| `,mb` `,mi`   | bold, italic                  | `,m=` `,mS`  | highlight, strike        |
| `` ,m` ``     | code                          | `,mF`        | clear formatting         |
| `,ml` `,me`   | link, edit link               | `,mp`        | paste URL with its title |
| `,mq` `,mQi`  | quote, callout                | `,mc`        | code block               |
| `,h1`…`,h6`   | heading level                 | `,h+` `,h-`  | promote, demote          |
| `,ht`         | table of contents             | `,hT`        | outline window           |
| `,ltu` `,ltn` `,ltt` | bullets, numbers, tasks | `,mr`       | renumber                 |
| `,tc` `,tf`   | new table, format             | `,te`        | edit the cell            |
| `,tir` `,tic` | add row, column               | `,tdr` `,tdc`| delete row, column       |
| `,tsa` `,tsd` | sort                          | `,tt`        | transpose                |
| `,tvi` `,tvx` | from CSV, to CSV              | `,mfi`       | footnote                 |

Surround: `saiwb` bold, `saiwl` link, `saiww` wiki link, `sd` removes, `sr` replaces.

## Windows

| Window        | Keys                                                                     |
| ------------- | ------------------------------------------------------------------------ |
| Context panel | `Enter` open, `o` peek, `Tab` fold, `l` link a mention, `[` `]` month, `?` |
| Agenda        | `x` done, `c` in progress, `>` `<` move a day, `d` `s` dates, `p` priority, `f` filter, `A` add to Todoist, `gx` open in Todoist |
| Board         | `hjkl` move, `HJKL` move card, `a` add, `e` edit, `x` tick, `@` date, `Enter` note, `o` text, `?` |
| Calendar      | `hjkl` day, `HL` month, `JK` year, `Enter` day, `w` `m` `y` notes, `a` task |
| Cards         | `Space` answer, `1`–`4` rate, `e` edit, `s` skip                         |
| Pickers       | `Ctrl-x` `Ctrl-v` split, `Ctrl-l` insert link, `Ctrl-n` new, `Ctrl-t` tick a task |
| Capture       | `Ctrl-s` today, `Ctrl-t` tasks, `Ctrl-n` new note                        |

## Commands

`:Today` `:Week` `:Calendar` `:Agenda [filter]` `:Task [text]` `:Todoist [text]` `:TodoistToken` `:Capture` `:Board [file]` `:Canvas [name]` `:MindMap` `:Graph [local]` `:Review` `:Sync` `:Export [format]` `:Keys` `:Obsidian …` `:PackUpdate` `:ThemeReload` `:checkhealth notes`

From your previous config: `:Table` (`!` asks Claude) `:DocxReview [file]` `:ZoteroAnnotations` `:PrintBuffer` `:PrintLine` `:PrintLive` `:QuartoPreview` `:Mason`
