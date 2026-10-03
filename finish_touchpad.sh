#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bash "$SCRIPT_DIR/set_touchpad_code.sh" 0x76
python3 "$SCRIPT_DIR/watch_hotkeys.py" --seconds 180 --output "$SCRIPT_DIR/touchpad-confirmation.jsonl"
