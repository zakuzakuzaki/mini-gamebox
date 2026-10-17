#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-godot}"
log="$(mktemp)"
trap 'rm -f "$log"' EXIT
"$GODOT_BIN" --headless --path "$ROOT_DIR/game" --script res://tests/test_gomoku.gd 2>&1 | tee "$log"
if grep -Eq '(SCRIPT ERROR|ERROR):' "$log"; then exit 1; fi
grep -q 'Gomoku checks passed' "$log"
"$GODOT_BIN" --headless --path "$ROOT_DIR/game" --script res://tests/test_tic_tac_toe.gd 2>&1 | tee "$log"
if grep -Eq '(SCRIPT ERROR|ERROR):' "$log"; then exit 1; fi
grep -q 'Tic tac toe checks passed' "$log"
"$GODOT_BIN" --headless --path "$ROOT_DIR/game" --script res://tests/test_minesweeper.gd 2>&1 | tee "$log"
if grep -Eq '(SCRIPT ERROR|ERROR):' "$log"; then exit 1; fi
grep -q 'Minesweeper checks passed' "$log"
"$GODOT_BIN" --headless --path "$ROOT_DIR/game" --script res://tests/test_kotoba_touch.gd 2>&1 | tee "$log"
if grep -Eq '(SCRIPT ERROR|ERROR):' "$log"; then exit 1; fi
grep -q 'Kotoba touch checks passed' "$log"
