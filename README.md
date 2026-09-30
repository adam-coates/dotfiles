# Dotfiles

Managed with [GNU Stow](https://www.gnu.org/software/stow/).

## Usage

From `~/dotfiles`:

```bash
# Stow a package (creates symlinks in ~)
stow <package>

# Stow all packages
stow */

# Remove a package's symlinks
stow -D <package>
```

## Packages

| Package | Target |
|---------|--------|
| bash | `~/.bashrc` |
| ghostty | `~/.config/ghostty` |
| hypr | `~/.config/hypr` |
| kitty | `~/.config/kitty` |
| lazygit | `~/.config/lazygit` |
| nvim | `~/.config/nvim` |
| omarchy | `~/.config/omarchy` |
| solaar | `~/.config/solaar` |
| starship | `~/.config/starship.toml` |
| tmux | `~/.config/tmux` |
| vale | `~/.config/vale` |
| yazi | `~/.config/yazi` |
| zathura | `~/.config/zathura` |
| zsh | `~/.zshrc` |
| scripts | `~/scripts` |

## Adding a new package

```bash
mkdir -p <name>/.config/<name>
# copy/move config files into it
stow <name>
```

## Notes

- Scripts live in `~/scripts` (managed via stow, not under `.config`)
- Nvim writing setup uses native spell checking, Vale, and Ltex-ls for grammar
