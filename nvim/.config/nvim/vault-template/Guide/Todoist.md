---
tags: [guide]
---

# Todoist

Connect once with `:TodoistToken` and paste your API token (Todoist › Settings › Integrations › Developer). It is kept in a file only you can read, never in the config.

Then Todoist's tasks are in the agenda (`<Space>tt`), the calendar and on the start screen, next to the tasks in the notes. In the agenda, on a Todoist task:

| Key | What it does |
| --- | --- |
| `x` | done (a repeating task moves to its next date) |
| `>` `<` | a day later, earlier |
| `d` | due date in Todoist's words: *next fri 3pm*, *every monday* |
| `p` | priority |
| `Enter` | the note it came from, or Todoist |
| `gx` | open in Todoist |
| `A` | add a task to Todoist |

In a note:

- `<Space>tT` adds a task to Todoist with Quick Add (*Call Anna tomorrow 3pm p1 #Thesis @phone*), noting where it came from.
- `<Space>tm` on a task sends it to Todoist. The line becomes a link that shows the task's date, or ✓ when it's done.
- A `todoist` block lists a filter, like a `tasks` block. It's written the way Obsidian's Todoist plugin writes it, so it shows there too:

```todoist
name: "Today and overdue"
filter: "today | overdue"
sorting:
  - priority
```

To have `<Space>ta` add to Todoist as well, set `task_capture = "todoist"` in the settings.
