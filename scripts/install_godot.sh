#!/usr/bin/env bash
set -euo pipefail

GODOT_VERSION="${GODOT_VERSION:-4.7.2-stable}"
GODOT_TEMPLATE_VERSION="${GODOT_TEMPLATE_VERSION:-4.7.2.stable}"
CACHE_DIR="${GODOT_CACHE_DIR:-$HOME/.cache/godot}"
INSTALL_DIR="${GODOT_INSTALL_DIR:-$HOME/.local/opt/godot}"
TEMPLATE_DIR="${HOME}/.local/share/godot/export_templates/${GODOT_TEMPLATE_VERSION}"
BASE_URL="https://github.com/godotengine/godot-builds/releases/download/${GODOT_VERSION}"

EDITOR_ZIP="Godot_v${GODOT_VERSION}_linux.x86_64.zip"
EDITOR_BIN_NAME="Godot_v${GODOT_VERSION}_linux.x86_64"
TEMPLATES_TPZ="Godot_v${GODOT_VERSION}_export_templates.tpz"

mkdir -p "$CACHE_DIR" "$INSTALL_DIR" "$HOME/.local/bin"

download() {
  local url="$1"
  local dest="$2"
  if [[ -f "$dest" ]]; then
    echo "Using cached $(basename "$dest")"
    return
  fi
  echo "Downloading $(basename "$dest")"
  curl -L --retry 5 --retry-all-errors --retry-delay 4 -C - -o "$dest.partial" "$url"
  mv "$dest.partial" "$dest"
}

if [[ ! -x "$INSTALL_DIR/$EDITOR_BIN_NAME" ]]; then
  download "$BASE_URL/$EDITOR_ZIP" "$CACHE_DIR/$EDITOR_ZIP"
  unzip -o "$CACHE_DIR/$EDITOR_ZIP" -d "$INSTALL_DIR"
  chmod +x "$INSTALL_DIR/$EDITOR_BIN_NAME"
fi

ln -sfn "$INSTALL_DIR/$EDITOR_BIN_NAME" "$HOME/.local/bin/godot"

if [[ ! -f "$TEMPLATE_DIR/web_nothreads_release.zip" ]]; then
  download "$BASE_URL/$TEMPLATES_TPZ" "$CACHE_DIR/$TEMPLATES_TPZ"
  EXTRACT_DIR="$(mktemp -d)"
  unzip -o "$CACHE_DIR/$TEMPLATES_TPZ" \
    "templates/version.txt" \
    "templates/web_debug.zip" \
    "templates/web_release.zip" \
    "templates/web_nothreads_debug.zip" \
    "templates/web_nothreads_release.zip" \
    -d "$EXTRACT_DIR"
  mkdir -p "$TEMPLATE_DIR"
  mv "$EXTRACT_DIR/templates/"* "$TEMPLATE_DIR/"
  rm -rf "$EXTRACT_DIR"
fi

echo "Godot editor: $INSTALL_DIR/$EDITOR_BIN_NAME"
"$HOME/.local/bin/godot" --version
echo "Web templates: $TEMPLATE_DIR"
ls -lh "$TEMPLATE_DIR"/web*.zip
