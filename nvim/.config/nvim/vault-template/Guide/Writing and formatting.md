---
tags: [guide]
---

# Writing and formatting

## Formatting

In normal mode these work on the word, in visual mode on the selection.

| Key     | Result                |
| ------- | --------------------- |
| `,mb`   | **bold**              |
| `,mi`   | *italic*              |
| `,m=`   | ==highlight==         |
| `,mS`   | ~~strikethrough~~     |
| ``,m` ``| `code`                |
| `,mq`   | quote                 |
| `,mQi`  | callout               |
| `,ml`   | link                  |
| `,mp`   | paste a URL as a link, with the page's title |
| `,h+` `,h-` | heading level     |
| `,t`    | tables                |

Lists continue by themselves, Tab indents, and tables stay aligned: `,tir` adds a row, `,tic` a column, `Alt-hjkl` moves between cells.

## Callouts

> [!note] A note
> Type `> [!` and choose one.

> [!warning]- A warning
> Things to watch out for.

> [!question] A question
> What would change my mind?

## Other things

Highlights ==like this==, comments %%that don't show in exports%%, footnotes[^1], and blocks with a name. ^named-block

[^1]: `K` on the number shows the footnote.

- [?] A question
- [i] An idea
- [*] A favourite
- [p] For
- [c] Against

## While you write

- `<Space>vz` zen mode, `<Space>vt` typewriter scrolling, `<Space>vd` dim the rest
- `Ctrl-l` in insert mode fixes the last spelling mistake, `<Space>ss` lists suggestions, `zg` adds a word
- Grammar hints are underlined (Harper and LTeX+); `gl` shows them, `<Space>ca` fixes them
- `<Space>mp` tidies the formatting with prettier (notes are never reformatted on save)
- `<Space>rr` searches and replaces in the whole vault
