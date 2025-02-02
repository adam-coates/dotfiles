; Folds a section of the document
; that starts with a heading.
((section
    (atx_heading)) @fold
    (#trim! @fold))

; (#trim!) is used to prevent empty
; lines at the end of the section
; from being folded.

; Fold callout blocks (e.g., > [!TIP], > [!NOTE])
((block_quote
    (paragraph
        (inline) @callout)) @fold
    (#match? @callout "^\[![A-Z]+\]")
    (#trim! @fold))

((list) @fold
 (#trim! @fold))
