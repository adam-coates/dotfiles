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
| wordcraft | `~/.config/wordcraft/Templates` |
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

## System setup (not stowed)

`system/` holds setup that needs root, so `install.sh` skips it. Run these by hand.

- **Uni Graz VPN** (`~/scripts/univpn2.sh`, Linux only):
  ```bash
  system/univpn/setup.sh first.last@uni-graz.at
  ~/scripts/openconnect-sso-compat --authenticate shell   # once, saves password/TOTP to the keyring
  ```
  Installs openconnect and openconnect-sso, the root helpers `vpn-connect-oc` and
  `vpn-disconnect-oc` in `/usr/local/bin`, a sudoers rule allowing only those two
  without a password, and `~/.config/openconnect-sso/config.toml` from the template.

## Notes

- Scripts live in `~/scripts` (managed via stow, not under `.config`)
- Nvim writing setup uses native spell checking, Vale, and Ltex-ls for grammar
