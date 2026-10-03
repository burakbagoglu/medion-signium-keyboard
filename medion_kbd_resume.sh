#!/bin/bash
set -euo pipefail
case "$1" in
    post)
        sleep 1
        if [ -d "/sys/bus/serio/devices/serio0" ]; then
            printf '%s' none > /sys/bus/serio/devices/serio0/drvctl
            /usr/local/bin/load_kbd_module.sh
        fi
        ;;
esac
