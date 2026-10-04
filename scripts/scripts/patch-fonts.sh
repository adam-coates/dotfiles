#!/usr/bin/env bash
set -euo pipefail

FONTFORGE_VERSION="2025-10-09"
FONTFORGE_URL="https://github.com/fontforge/fontforge/releases/download/${FONTFORGE_VERSION}/FontForge-${FONTFORGE_VERSION}-Linux-x86_64.AppImage"
NERDFONTS_VERSION="3.5.1"
PATCHER_URL="https://github.com/ryanoasis/nerd-fonts/releases/download/v${NERDFONTS_VERSION}/FontPatcher.zip"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APPIMAGE="$SCRIPT_DIR/FontForge-${FONTFORGE_VERSION}-Linux-x86_64.AppImage"
PATCHER_DIR="$SCRIPT_DIR/FontPatcher"
PATCHER="$PATCHER_DIR/font-patcher"
FONT_INSTALL_DIR="$HOME/.local/share/fonts"

usage() {
    echo "Usage: $(basename "$0") <font-directory> [output-directory]"
    echo
    echo "Patches all .otf and .ttf fonts in <font-directory> with Nerd Fonts glyphs."
    echo "Output defaults to ./patched if not specified."
    echo
    echo "Downloads FontForge AppImage and Nerd Fonts FontPatcher automatically if not present."
    exit 1
}

if [[ $# -lt 1 ]]; then
    usage
fi

FONT_DIR="$(realpath "$1")"
OUT_DIR="${2:-$SCRIPT_DIR/patched}"

if [[ ! -d "$FONT_DIR" ]]; then
    echo "Error: '$1' is not a directory"
    exit 1
fi

fonts=("$FONT_DIR"/*.otf "$FONT_DIR"/*.ttf)
fonts=("${fonts[@]}" 2>/dev/null)
font_count=0
for f in "${fonts[@]}"; do
    [[ -f "$f" ]] && ((font_count++))
done

if [[ $font_count -eq 0 ]]; then
    echo "Error: no .otf or .ttf files found in '$FONT_DIR'"
    exit 1
fi

echo "Found $font_count font(s) to patch"

# Download FontForge AppImage if needed
if [[ ! -f "$APPIMAGE" ]]; then
    echo "Downloading FontForge AppImage..."
    curl -fL -o "$APPIMAGE" "$FONTFORGE_URL"
    chmod +x "$APPIMAGE"
    echo "Downloaded FontForge AppImage"
else
    echo "FontForge AppImage already present"
fi

# Download and extract FontPatcher if needed
if [[ ! -f "$PATCHER" ]]; then
    echo "Downloading Nerd Fonts FontPatcher..."
    curl -fL -o "$SCRIPT_DIR/FontPatcher.zip" "$PATCHER_URL"
    unzip -o "$SCRIPT_DIR/FontPatcher.zip" -d "$PATCHER_DIR"
    rm "$SCRIPT_DIR/FontPatcher.zip"
    echo "Extracted FontPatcher"
else
    echo "FontPatcher already present"
fi

mkdir -p "$OUT_DIR"

# Prevent FontForge AppImage from triggering desktop integration
export DESKTOPINTEGRATION=false

failed=0
patched=0

for f in "${fonts[@]}"; do
    [[ -f "$f" ]] || continue
    base="$(basename "$f")"
    echo "=== Patching: $base ==="
    if "$APPIMAGE" -script "$PATCHER" --complete --careful -out "$OUT_DIR" "$f" 2>&1 | tail -1; then
        ((patched++))
    else
        echo "FAILED: $base"
        ((failed++))
    fi
    echo
done

echo "Patched $patched font(s), $failed failure(s)"
echo "Output: $OUT_DIR"

read -rp "Install to $FONT_INSTALL_DIR and refresh font cache? [y/N] " answer
if [[ "$answer" =~ ^[Yy]$ ]]; then
    mkdir -p "$FONT_INSTALL_DIR"
    cp "$OUT_DIR"/*.otf "$OUT_DIR"/*.ttf "$FONT_INSTALL_DIR/" 2>/dev/null || true
    fc-cache -fv
    echo "Fonts installed and cache refreshed"
fi
