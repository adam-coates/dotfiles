---
tags: [monthly]
---

# {{date:MMMM YYYY}}

[[{{last_month}}|← last month]] · [[{{year}}]] · [[{{next_month}}|next month →]]

## Focus

## Notes from this month

```dataview
LIST
FROM -"Journal" AND -"Templates" AND -"Guide"
WHERE file.ctime >= date({{date:YYYY-MM}}-01) AND file.ctime < date({{date:YYYY-MM}}-01) + dur(1 month)
SORT file.ctime DESC
LIMIT 30
```
