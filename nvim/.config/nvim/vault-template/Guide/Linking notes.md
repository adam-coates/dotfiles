---
tags: [guide]
---

# Linking notes

## Making links

Type `[[` and part of a name. Completion offers notes and aliases, and an option to create the note.

| Type          | To link to                              |
| ------------- | --------------------------------------- |
| `[[`          | a note                                  |
| `[[##`        | a heading anywhere in the vault         |
| `[[Note#`     | a heading in that note                  |
| `[[^^`        | a block (paragraph) anywhere            |
| `#`           | a tag                                   |
| `[^`          | a footnote                              |
| `@friday`     | the daily note of a day                 |

Select text and press `<Space>ll` to link it to a note, or `<Space>ln` to make a new note from it. A link to a note that isn't there yet looks like [[this one]]; `Enter` creates it.

## Following

`Enter` follows, `Backspace` goes back, `]o` and `[o` jump between links, `K` peeks at the note without leaving. Try it on [[Memory#Consolidation]].

## The other direction

The panel on the right (`<Space>.`) lists what links here, and what mentions this note without linking. On an unlinked mention, `l` turns it into a link. `<Space>lb` does the same in a picker.

## Embeds

With an exclamation mark in front, a link shows the note (or a section, or a block) in place:

![[Memory#Consolidation]]

`<Space>ie` inserts one.

## Renaming

`<Space>nr` renames the note and updates every link to it. `<Space>rt` renames a tag everywhere. `<Space>re` moves a section to a note of its own.
