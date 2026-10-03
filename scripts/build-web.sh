#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-godot}"
if ! command -v "$GODOT_BIN" >/dev/null 2>&1; then
  echo "Godot executable '$GODOT_BIN' was not found. Set GODOT_BIN to Godot 4.6.1." >&2
  exit 1
fi
rm -rf "$ROOT_DIR/dist/web"
mkdir -p "$ROOT_DIR/dist/web"
export_log="$(mktemp)"
trap 'rm -f "$export_log"' EXIT
"$GODOT_BIN" --headless --editor --path "$ROOT_DIR/game" --import 2>&1 | tee "$export_log"
if grep -Eq '(^|[[:space:]])(SCRIPT ERROR|ERROR):' "$export_log"; then exit 1; fi
"$GODOT_BIN" --headless --path "$ROOT_DIR/game" --export-release Web "$ROOT_DIR/dist/web/index.html" 2>&1 | tee "$export_log"
# Godot can return success even when missing preloads break game scripts.
if grep -Eq '(^|[[:space:]])(SCRIPT ERROR|ERROR):' "$export_log"; then
  echo "Web export reported errors; refusing to publish a broken build." >&2
  exit 1
fi
test -f "$ROOT_DIR/dist/web/index.html" || { echo "Web export did not create dist/web/index.html" >&2; exit 1; }
node "$ROOT_DIR/scripts/prepare-pages-web.mjs" "$ROOT_DIR/dist/web"
echo "Web build ready at $ROOT_DIR/dist/web/index.html"
