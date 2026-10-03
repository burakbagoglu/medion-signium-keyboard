#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bash "$SCRIPT_DIR/install.sh"
python3 "$SCRIPT_DIR/watch_hotkeys.py" --seconds 180 --output "$SCRIPT_DIR/hotkey-diagnostics.jsonl"
