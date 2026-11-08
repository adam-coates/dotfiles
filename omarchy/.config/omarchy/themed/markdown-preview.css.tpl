/*
 * Omarchy theme for markdown-preview.nvim (adam-coates fork).
 * Omarchy renders this into ~/.local/state/omarchy/current/theme/markdown-preview.css
 * on every theme switch; nvim points g:mkdp_theme_css at the result.
 * Heading colours follow Omarchy's Obsidian theme. Variables: see the plugin README.
 */
html:root, main[data-theme] {
  /* page around the document */
  --background-color: {{ background }};
  --secondary-background-color: {{ dark_background }};
  --foreground-color: {{ foreground }};
  --border-color: {{ selection_background }};

  /* document body */
  --color-text-primary: {{ foreground }};
  --color-text-tertiary: {{ dark_foreground }};
  --color-text-link: {{ blue }};
  --color-bg-primary: {{ background }};
  --color-bg-secondary: {{ lighter_background }};
  --color-bg-tertiary: {{ lighter_background }};
  --color-border-primary: {{ selection_background }};
  --color-border-secondary: {{ lighter_background }};
  --color-border-tertiary: {{ muted }};
  --color-kbd-foreground: {{ foreground }};
  --color-markdown-table-border: {{ selection_background }};
  --color-markdown-table-tr-border: {{ muted }};
  --color-markdown-blockquote-border: {{ accent }};
  --color-blockquote-text: {{ light_foreground }};

  /* one colour per heading level */
  --color-heading-1: {{ red }};
  --color-heading-2: {{ green }};
  --color-heading-3: {{ yellow }};
  --color-heading-4: {{ blue }};
  --color-heading-5: {{ magenta }};
  --color-heading-6: {{ cyan }};

  /* fonts */
  --font-body: "TX02 Nerd Font", monospace;
  --font-mono: "TX02 Nerd Font", monospace;

  /* code */
  --color-citation: {{ cyan }};
  --color-code-inline: {{ accent }};
  --color-markdown-code-bg: {{ lighter_background }};
  --color-code-block-bg: {{ dark_background }};
  --color-code-block-border: {{ selection_background }};
  --radius-code-block: 6px;

  /* syntax highlighting */
  --hl-text: {{ foreground }};
  --hl-comment: {{ dark_foreground }};
  --hl-keyword: {{ red }};
  --hl-string: {{ green }};
  --hl-number: {{ magenta }};
  --hl-title: {{ blue }};
  --hl-type: {{ yellow }};
  --hl-tag: {{ cyan }};
  --hl-regexp: {{ cyan }};
  --hl-symbol: {{ magenta }};
  --hl-builtin: {{ orange }};
  --hl-meta: {{ dark_foreground }};
  --hl-addition: {{ mix background green 25% }};
  --hl-deletion: {{ mix background red 25% }};

  /* admonitions */
  --alert-note: {{ blue }};
  --alert-tip: {{ green }};
  --alert-important: {{ magenta }};
  --alert-warning: {{ yellow }};
  --alert-caution: {{ red }};

  /* Graphviz, flowchart.js and sequence diagrams */
  --diagram-line: {{ foreground }};
  --diagram-text: {{ foreground }};
  --diagram-fill: {{ lighter_background }};
  --diagram-background: transparent;
}
