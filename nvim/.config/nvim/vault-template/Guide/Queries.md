---
tags: [guide]
rating: 5
---

# Queries

Blocks of `tasks` and `dataview` show their results in place. Move the cursor into one to edit it; `Enter` lists the results. `<Space>vq` hides them.

## Tasks

```tasks
not done
(tags include #thesis) OR (path includes Guide)
group by filename
sort by due
```

## Tables

```dataview
TABLE WITHOUT ID file.link AS "Note", length(file.inlinks) AS "Links in", file.words AS "Words", file.mday AS "Edited"
FROM "Notes" OR "Guide"
SORT length(file.inlinks) DESC
LIMIT 6
```

## Lists

```dataview
LIST "by " + author
FROM #book
WHERE rating >= 4
```

## Tasks from a project

```dataview
TASK
FROM #project
WHERE !completed AND due
SORT due
```

## Grouping

```dataview
TABLE length(rows) AS "Notes", sum(rows.file.words) AS "Words"
FROM -"Templates"
GROUP BY file.folder AS "Folder"
SORT length(rows) DESC
LIMIT 5
```

## Inline

This note has `= this.file.words` words and a rating of `= this.rating`. Today is `= date(today)`; the year has `= (date(eoy) - date(today)).days` days left.
