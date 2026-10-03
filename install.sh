#!/bin/bash
set -euo pipefail

if [[ "$EUID" -ne 0 ]]; then
    echo "Bu betik root yetkisi gerektirir: sudo bash $0" >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE=medion-signium-keyboard
VERSION=1.1
CURRENT_KVER="$(uname -r)"
DKMS_DIR="/usr/src/${PACKAGE}-${VERSION}"
BACKUP_DIR="/var/lib/${PACKAGE}/backups/$(date +%Y%m%d-%H%M%S)-$$"
ACTIVATE=1
if [[ "${1:-}" == --no-activate ]]; then
    ACTIVATE=0
elif [[ -n "${1:-}" ]]; then
    echo "Kullanim: $0 [--no-activate]" >&2
    exit 1
fi

echo "=== Medion Signium Klavye Surucusu ${VERSION} ==="
for tool in dkms make clang; do
    if ! command -v "$tool" > /dev/null; then
        echo "HATA: $tool gerekli. Once gerekli derleme araclarini kurun." >&2
        exit 1
    fi
done
if [[ ! -f "/lib/modules/${CURRENT_KVER}/build/Makefile" ]]; then
    echo "HATA: ${CURRENT_KVER} cekirdek basliklari bulunamadi." >&2
    exit 1
fi
for file in medion_kbd.c Makefile dkms.conf load_kbd_module.sh medion_kbd_resume.sh medion_kbd.service medion_kbd.conf rollback.sh; do
    [[ -f "$SCRIPT_DIR/$file" ]] || { echo "HATA: $file bulunamadi." >&2; exit 1; }
done

# Calisan modulu, yukleyiciyi ve ayarlari degisiklikten once sakla.
mkdir -p "$BACKUP_DIR"
chmod 700 "$BACKUP_DIR"
OLD_MODULE="$(modinfo -n medion_kbd 2>/dev/null || true)"
if [[ -f "$OLD_MODULE" ]]; then
    cp -a "$OLD_MODULE" "$BACKUP_DIR/$(basename "$OLD_MODULE")"
    printf '%s\n' "$OLD_MODULE" > "$BACKUP_DIR/module-path"
    OLD_VERSION="$(modinfo -F version medion_kbd)"
    printf '%s\n' "${OLD_VERSION:-1.0}" > "$BACKUP_DIR/module-version"
fi
for file in /usr/local/bin/load_kbd_module.sh /usr/lib/systemd/system-sleep/medion_kbd_resume.sh /etc/systemd/system/medion_kbd.service /etc/modprobe.d/medion_kbd.conf; do
    if [[ -f "$file" ]]; then
        cp -a --parents "$file" "$BACKUP_DIR/"
    fi
done
if [[ -d /usr/src/medion-signium-keyboard-1.0 ]]; then
    cp -a /usr/src/medion-signium-keyboard-1.0 "$BACKUP_DIR/"
fi
if [[ -d "$DKMS_DIR" ]]; then
    cp -a "$DKMS_DIR" "$BACKUP_DIR/"
fi
install -m 755 "$SCRIPT_DIR/rollback.sh" "$BACKUP_DIR/rollback.sh"
printf '%s\n' "$BACKUP_DIR" > "/var/lib/${PACKAGE}/latest-backup"
echo "--> Geri donus yedegi: $BACKUP_DIR"

# 1.0 kaydini kaldirma: calisan surum geri donus icin korunur.
mkdir -p "$DKMS_DIR"
install -m 644 "$SCRIPT_DIR/medion_kbd.c" "$SCRIPT_DIR/Makefile" "$SCRIPT_DIR/dkms.conf" "$DKMS_DIR/"
if [[ ! -e "/var/lib/dkms/${PACKAGE}/${VERSION}/source" ]]; then
    dkms add -m "$PACKAGE" -v "$VERSION"
fi
dkms build -m "$PACKAGE" -v "$VERSION" -k "$CURRENT_KVER" --force
if ! dkms install -m "$PACKAGE" -v "$VERSION" -k "$CURRENT_KVER" --force; then
    bash "$BACKUP_DIR/rollback.sh" "$BACKUP_DIR" || true
    echo "HATA: DKMS kurulumu basarisiz." >&2
    exit 1
fi

# Yalnizca DKMS'in yeni derledigi modulu kullan. Klasordeki eski .ko kopyalanmaz.
depmod -a "$CURRENT_KVER"
if [[ "$(modinfo -F version medion_kbd)" != "$VERSION" ]]; then
    bash "$BACKUP_DIR/rollback.sh" "$BACKUP_DIR" || true
    echo "HATA: modprobe yeni ${VERSION} surumunu secmiyor." >&2
    exit 1
fi

mkdir -p /etc/modprobe.d
if [[ ! -e /etc/modprobe.d/medion_kbd.conf ]]; then
    install -m 644 "$SCRIPT_DIR/medion_kbd.conf" /etc/modprobe.d/medion_kbd.conf
fi
install -m 755 "$SCRIPT_DIR/load_kbd_module.sh" /usr/local/bin/load_kbd_module.sh
install -m 755 "$SCRIPT_DIR/medion_kbd_resume.sh" /usr/lib/systemd/system-sleep/medion_kbd_resume.sh
install -m 644 "$SCRIPT_DIR/medion_kbd.service" /etc/systemd/system/medion_kbd.service
systemctl daemon-reload
systemctl enable medion_kbd.service

if [[ "$ACTIVATE" -eq 1 ]]; then
    echo "--> Yeni modul yukleniyor (klavye kisa sure yeniden baglanacak)..."
    if ! /usr/local/bin/load_kbd_module.sh --reload; then
        bash "$BACKUP_DIR/rollback.sh" "$BACKUP_DIR" || true
        echo "HATA: Yeni modul etkinlestirilemedi; geri donus denendi." >&2
        exit 1
    fi
    if [[ "$(cat /sys/module/medion_kbd/version)" != "$VERSION" ]]; then
        bash "$BACKUP_DIR/rollback.sh" "$BACKUP_DIR" || true
        echo "HATA: Calisan modul beklenen surum degil." >&2
        exit 1
    fi
    echo "=== ${VERSION} kuruldu ve etkinlestirildi ==="
else
    echo "=== ${VERSION} kuruldu; yeniden baslatma sonrasi etkinlesecek ==="
fi
echo "Geri donus: sudo bash '$BACKUP_DIR/rollback.sh' '$BACKUP_DIR'"
