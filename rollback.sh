#!/bin/bash
set -euo pipefail

if [[ "$EUID" -ne 0 ]]; then
    echo "Root yetkisi gerekli: sudo bash $0 [yedek-dizini]" >&2
    exit 1
fi
BACKUP_DIR="${1:-}"
if [[ -z "$BACKUP_DIR" ]]; then
    BACKUP_DIR="$(cat /var/lib/medion-signium-keyboard/latest-backup)"
fi
CURRENT_KVER="$(uname -r)"
if [[ ! -f "$BACKUP_DIR/module-path" ]]; then
    echo "HATA: Geri yuklenecek modul yedegi yok." >&2
    exit 1
fi
MODULE_PATH="$(cat "$BACKUP_DIR/module-path")"
if [[ "$MODULE_PATH" != /lib/modules/"$CURRENT_KVER"/* && "$MODULE_PATH" != /usr/lib/modules/"$CURRENT_KVER"/* ]]; then
    echo "HATA: Yedek mevcut cekirdek icin degil." >&2
    exit 1
fi
SAVED_MODULE="$BACKUP_DIR/$(basename "$MODULE_PATH")"
[[ -f "$SAVED_MODULE" ]] || { echo "HATA: Yedek modul eksik." >&2; exit 1; }

SAVED_VERSION="$(cat "$BACKUP_DIR/module-version")"
if [[ "$SAVED_VERSION" != 1.0 && "$SAVED_VERSION" != 1.1 ]]; then
    echo "HATA: Beklenmeyen yedek surumu." >&2
    exit 1
fi
if [[ "$SAVED_VERSION" == 1.0 ]]; then
    dkms remove -m medion-signium-keyboard -v 1.1 --all 2>/dev/null || true
else
    for file in medion_kbd.c Makefile dkms.conf; do
        cp -a "$BACKUP_DIR/medion-signium-keyboard-1.1/$file" /usr/src/medion-signium-keyboard-1.1/
    done
    dkms build -m medion-signium-keyboard -v 1.1 -k "$CURRENT_KVER" --force || true
fi
dkms install -m medion-signium-keyboard -v "$SAVED_VERSION" -k "$CURRENT_KVER" --force || true
mkdir -p "$(dirname "$MODULE_PATH")"
install -m 644 "$SAVED_MODULE" "$MODULE_PATH"
for file in /usr/local/bin/load_kbd_module.sh /usr/lib/systemd/system-sleep/medion_kbd_resume.sh /etc/systemd/system/medion_kbd.service; do
    if [[ -f "$BACKUP_DIR$file" ]]; then
        cp -a "$BACKUP_DIR$file" "$file"
    fi
done
if [[ -f "$BACKUP_DIR/etc/modprobe.d/medion_kbd.conf" ]]; then
    cp -a "$BACKUP_DIR/etc/modprobe.d/medion_kbd.conf" /etc/modprobe.d/medion_kbd.conf
else
    rm -f /etc/modprobe.d/medion_kbd.conf
fi
depmod -a "$CURRENT_KVER"
modprobe -r medion_kbd
modprobe medion_kbd
printf '%s' none > /sys/bus/serio/devices/serio0/drvctl
printf '%s' medion_kbd > /sys/bus/serio/devices/serio0/drvctl
systemctl daemon-reload
echo "Calisan eski klavye surucusu geri yuklendi."
