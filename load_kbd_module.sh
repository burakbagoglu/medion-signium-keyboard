#!/bin/bash
# Medion Signium Dahili Klavye Serio0 Baglama Betigi
set -euo pipefail

if [[ "${1:-}" == "--reload" && -d /sys/module/medion_kbd ]]; then
    modprobe -r medion_kbd
fi

modprobe medion_kbd

SERIO_DIR=/sys/bus/serio/devices/serio0
if [[ ! -d "$SERIO_DIR" ]]; then
    echo "HATA: Dahili klavye portu serio0 bulunamadi." >&2
    exit 1
fi

if [[ "$(basename "$(readlink "$SERIO_DIR/driver" || true)")" != medion_kbd ]]; then
    printf '%s' none > "$SERIO_DIR/drvctl"
    printf '%s' medion_kbd > "$SERIO_DIR/drvctl"
fi

if [[ "$(basename "$(readlink "$SERIO_DIR/driver" || true)")" != medion_kbd ]]; then
    echo "HATA: medion_kbd serio0 portuna baglanamadi." >&2
    exit 1
fi
