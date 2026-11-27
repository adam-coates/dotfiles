---
tags: [guide]
---

# Sync and export

## Git

`<Space>gi` makes the vault a git repository. `<Space>gs` commits, and pulls and pushes when there is a remote. Set `sync.auto_minutes` to have that happen on a timer. `<Space>gl` is the history of a note, `<Space>gg` is lazygit.

A folder synced by Nextcloud or Syncthing works just as well.

## Export

`<Space>xe` exports with pandoc: PDF (through typst), Word, HTML, slides, LaTeX. Links, embeds, callouts, highlights and query results come along. Files go to the Export folder.

`<Space>xp` previews in the browser while you type, `<Space>xs` presents the note as slides (separate them with `---`).
