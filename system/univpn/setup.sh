#!/usr/bin/env bash
# One-time setup for ~/scripts/univpn2.sh (Uni Graz VPN) on Arch/Omarchy.
# Not a stow package: it installs root-owned files, so install.sh skips it.
#
# Usage: system/univpn/setup.sh <uni-username, e.g. first.last@uni-graz.at>
#
# Afterwards, log in once from a terminal so openconnect-sso can save your
# password (and TOTP secret, if not already in the keyring):
#   ~/scripts/openconnect-sso-compat --authenticate shell
set -euo pipefail

cd "$(dirname "$0")"

if [[ "$(uname -s)" != Linux ]]; then
  echo "univpn setup is Linux-only" >&2
  exit 1
fi

username="${1:-}"
config="$HOME/.config/openconnect-sso/config.toml"
if [[ ! -f $config && -z $username ]]; then
  echo "Usage: $0 <uni-username>" >&2
  exit 1
fi

yay -S --needed --noconfirm openconnect openconnect-sso

# Root-owned helpers that fix every openconnect option, so the sudoers rule
# below can't be used to run arbitrary commands as root.
sudo install -m 755 -o root -g root vpn-connect-oc vpn-disconnect-oc /usr/local/bin/

sudoers="$(mktemp)"
trap 'rm -f "$sudoers"' EXIT
cat >"$sudoers" <<SUDOERS
# Let univpn2.sh start and stop the Uni Graz VPN without a password.
$USER ALL=(root) NOPASSWD: /usr/local/bin/vpn-connect-oc, /usr/local/bin/vpn-disconnect-oc
SUDOERS
sudo visudo -cf "$sudoers"
sudo install -m 440 -o root -g root "$sudoers" /etc/sudoers.d/univpn

if [[ -f $config ]]; then
  echo "Keeping existing $config"
else
  mkdir -p "$(dirname "$config")"
  sed "s/YOUR_USERNAME@uni-graz.at/$username/" config.toml.template >"$config"
  chmod 600 "$config"
  echo "Wrote $config"
fi

echo "Done. Now log in once: ~/scripts/openconnect-sso-compat --authenticate shell"
