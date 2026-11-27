---
tags: [guide]
---

# Daily notes and calendar

- `<Space>dd` today, `<Space>dy` yesterday, `<Space>dt` tomorrow
- `<Space>dw` this week, `<Space>dm` this month, `<Space>dY` this year
- `<Space>dc` the calendar: `hjkl` to move, `H` `L` for months, `Enter` opens the day, `w` the week
- `<Space>dj` jump to a day in words: *next friday*, *3 weeks ago*, *1 dec*
- `[p` and `]p` the previous and next daily (or weekly, monthly) note

The small calendar in the panel works too: `Enter` on a day or on a week number. A dot means there is a note, a bullet means a task is due.

`<Space>nc` captures a thought into today's log from wherever you are. `:Capture` can be bound to a key on the desktop:

```sh
ghostty -e nvim +Capture
```

Templates for all of these are in the Templates folder.
