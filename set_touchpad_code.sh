#!/bin/bash
set -euo pipefail
if [[ "$EUID" -ne 0 ]]; then
    echo "Root yetkisi gerekli: sudo bash $0 0xKOD" >&2
    exit 1
fi
CODE="${1:-}"
if [[ ! "$CODE" =~ ^0x([0-7][0-9a-fA-F]|[eE]0[0-7][0-9a-fA-F])$ || "$CODE" == 0x00 ]]; then
    echo "HATA: Dogrulanmis basma kodunu 0x76 veya 0xe06d biciminde belirtin." >&2
    exit 1
fi
PARAM=/sys/module/medion_kbd/parameters/touchpad_scancode
[[ -w "$PARAM" ]] || { echo "HATA: Yeni surucu yuklu degil." >&2; exit 1; }
CONF=/etc/modprobe.d/medion_kbd.conf
mkdir -p /etc/modprobe.d
if [[ -f "$CONF" ]]; then
    cp -a "$CONF" "${CONF}.bak.$(date +%Y%m%d-%H%M%S)"
fi
python3 - "$CONF" "$CODE" <<'PY'
from pathlib import Path
import re
import sys
path, code = Path(sys.argv[1]), sys.argv[2]
text = path.read_text() if path.exists() else ''
lines = []
for line in text.splitlines():
    if re.match(r'^\s*options\s+medion_kbd(?:\s|$)', line):
        line = re.sub(r'\s+touchpad_scancode=\S+', '', line)
    lines.append(line)
lines.append('options medion_kbd touchpad_scancode=' + code)
path.write_text('\n'.join(lines) + '\n')
path.chmod(0o644)
PY
printf '%s' "$CODE" > "$PARAM"
echo "Touchpad kodu ${CODE} etkin ve kalici olarak kaydedildi."
