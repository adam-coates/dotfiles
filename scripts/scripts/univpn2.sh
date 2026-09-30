#!/usr/bin/env bash
# Toggle the Uni Graz VPN (univpn.uni-graz.at, profile "Bedienstete").
#
# Auth is SAML via Azure AD, so openconnect-sso drives a Qt WebEngine window and
# fills username/password/TOTP from the keyring per ~/.config/openconnect-sso/config.toml.
# It hands back a cookie, and openconnect proper builds the tunnel as root.

set -uo pipefail

PIDFILE=/run/openconnect-vpn.pid
AUTHLOG=/tmp/openconnect-auth.log
TUNLOG=/tmp/openconnect-tunnel.log

# Last argument is the message body; earlier ones may be flags like -u critical.
notify() { command -v notify-send >/dev/null && notify-send "$@"; echo "${!#}"; }

is_connected() {
    [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null && return 0
    pgrep -x openconnect >/dev/null 2>&1
}

if is_connected; then
    sudo /usr/local/bin/vpn-disconnect-oc
    notify "VPN" "Uni Graz VPN disconnected"
    exit 0
fi

# Step 1: authenticate. --authenticate shell prints COOKIE/HOST/FINGERPRINT assignments.
AUTH=$("$(dirname "$(readlink -f "$0")")/openconnect-sso-compat" \
        --authenticate shell 2>"$AUTHLOG")
if [ $? -ne 0 ] || [ -z "$AUTH" ]; then
    notify -u critical "VPN" "Authentication failed - see $AUTHLOG"
    exit 1
fi

# Parse only the variables we expect, rather than eval'ing the whole blob.
COOKIE= HOST= FINGERPRINT=
while IFS='=' read -r key value; do
    key="${key//[[:space:]]/}"
    case "$key" in
        COOKIE|HOST|FINGERPRINT)
            value="${value#[\'\"]}"; value="${value%[\'\"]}"
            printf -v "$key" '%s' "$value"
            ;;
    esac
done <<< "$AUTH"

if [ -z "$COOKIE" ] || [ -z "$HOST" ]; then
    notify -u critical "VPN" "Auth returned no cookie - see $AUTHLOG"
    exit 1
fi

# Step 2: build the tunnel as root, daemonized.
if echo "$COOKIE" | sudo openconnect \
        --protocol=anyconnect \
        --cookie-on-stdin \
        --servercert="$FINGERPRINT" \
        --background \
        --pid-file="$PIDFILE" \
        --quiet \
        "$HOST" >>"$TUNLOG" 2>&1; then
    # --background returns as soon as it daemonizes, before the tun device is up.
    for _ in $(seq 40); do
        ip -brief link show 2>/dev/null | grep -q '^tun' && break
        sleep 0.5
    done
    if ip -brief link show 2>/dev/null | grep -q '^tun'; then
        notify "VPN" "Uni Graz VPN connected"
    else
        notify -u critical "VPN" "Tunnel started but no tun device appeared - see $TUNLOG"
        exit 1
    fi
else
    notify -u critical "VPN" "Tunnel failed to start"
    exit 1
fi
