---
aliases: [Start, Index]
tags: [moc]
---

# Home

Welcome. This vault exists to try things out. Begin with [[Start here]], or press `<Space>?` for the keys.

> [!tip] Three things to try first
> - `<Space>dd` opens today's note.
> - `<Space><Space>` finds a note. Type a name that doesn't exist and press Enter to create it.
> - Put the cursor on [[Sleep study]] and press `K` to peek, `Enter` to go, `Backspace` to come back.

## Today

```tasks
not done
due on or before today
short mode
```

## Projects

```dataview
TABLE status AS "Status", due AS "Due", length(filter(file.tasks, (t) => !t.completed)) AS "Open tasks"
FROM #project
WHERE type = "project"
SORT due ASC
```

## Reading

```dataview
TABLE author AS "Author", rating AS "Rating", status AS "Status"
FROM #book
SORT rating DESC
```

## Maps

- [[Start here]]: how this works
- [[Memory]]: notes about memory and sleep
- [[Thesis board]]: a kanban board (`<Space>tK`)
- [[German]]: flashcards (`<Space>kk`)
- [[Canvas and mind maps]]: drawings and mind maps (`<Space>iw`, `<Space>im`)
