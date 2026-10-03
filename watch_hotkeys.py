#!/usr/bin/env python3
"""Bounded, non-grabbing hotkey diagnosis; ordinary typing is not recorded."""
import argparse
import json
import os
from pathlib import Path
import re
import select
import struct
import sys
import time

KEYS = {
    59: 'F1', 60: 'F2', 61: 'F3', 62: 'F4', 63: 'F5', 64: 'F6',
    65: 'F7', 66: 'F8', 67: 'F9', 68: 'F10', 87: 'F11', 88: 'F12',
    113: 'MUTE', 114: 'VOLUMEDOWN', 115: 'VOLUMEUP', 142: 'SLEEP',
    163: 'NEXTSONG', 164: 'PLAYPAUSE', 165: 'PREVIOUSSONG', 166: 'STOPCD',
    168: 'REWIND', 208: 'FASTFORWARD', 530: 'TOUCHPAD_TOGGLE',
    531: 'TOUCHPAD_ON', 532: 'TOUCHPAD_OFF',
}
NAMES = {'Medion Signium Custom Keyboard', 'Intel HID events', 'Sleep Button'}
EVENT = struct.Struct('@llHHi')


def known_scans():
    source = Path(__file__).with_name('medion_kbd.c').read_text()
    normal = source.split('static unsigned short medion_kbd_translate_normal', 1)[1].split('static unsigned short medion_kbd_translate_escaped', 1)[0]
    escaped = source.split('static unsigned short medion_kbd_translate_escaped', 1)[1].split('static irqreturn_t', 1)[0]
    scans = {int(c, 16) for c in re.findall(r'case (0x[0-9a-f]+):', normal)}
    scans |= {0xe000 | int(c, 16) for c in re.findall(r'case (0x[0-9a-f]+):', escaped)}
    scans |= {0x38, 0xe04b, 0xe04d, 0xe048, 0xe050, 0xe053, 0xe05b}
    return scans


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--seconds', type=int, default=90)
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    if not 1 <= args.seconds <= 600:
        parser.error('--seconds must be between 1 and 600')
    devices = {}
    for block in Path('/proc/bus/input/devices').read_text().split('\n\n'):
        name = re.search(r'^N: Name="(.*?)"$', block, re.M)
        event = re.search(r'\bevent\d+\b', block)
        if name and name.group(1) in NAMES and event:
            try:
                fd = os.open('/dev/input/' + event.group(), os.O_RDONLY | os.O_NONBLOCK)
            except PermissionError:
                sys.exit('Yonetici yetkisi gerekli: sudo python3 watch_hotkeys.py')
            devices[fd] = {'name': name.group(1), 'scan': None, 'keys': [], 'buffer': b''}
    if not any(d['name'] == 'Medion Signium Custom Keyboard' for d in devices.values()):
        sys.exit('Medion klavye aygiti bulunamadi.')
    known = known_scans()
    out = args.output.open('w') if args.output else None
    counts = {}

    def emit(record):
        record['elapsed'] = round(time.monotonic() - started, 3)
        line = json.dumps(record, ensure_ascii=False)
        print(line, flush=True)
        if out:
            out.write(line + '\n')
            out.flush()

    started = time.monotonic()
    print(f'HAZIR: {args.seconds} saniye. Yalnizca F/hotkey ve eslenmemis kodlar kaydedilir; aygit kilitlenmez.', flush=True)
    try:
        while time.monotonic() - started < args.seconds:
            ready, _, _ = select.select(list(devices), [], [], min(1, args.seconds - (time.monotonic() - started)))
            for fd in ready:
                device = devices[fd]
                data = os.read(fd, EVENT.size * 64)
                if not data:
                    continue
                device['buffer'] += data
                while len(device['buffer']) >= EVENT.size:
                    _, _, typ, code, value = EVENT.unpack(device['buffer'][:EVENT.size])
                    device['buffer'] = device['buffer'][EVENT.size:]
                    if typ == 4 and code == 4:  # EV_MSC / MSC_SCAN
                        device['scan'] = value
                    elif typ == 1:  # EV_KEY
                        device['keys'].append((code, value))
                    elif typ == 0 and code == 0:  # SYN_REPORT
                        scan, keys = device['scan'], device['keys']
                        for key, state in keys:
                            if key in KEYS:
                                label = KEYS[key]
                                counts[label] = counts.get(label, 0) + (state == 1)
                                emit({'device': device['name'], 'key': label, 'state': state,
                                      'scan': f'0x{scan:04x}' if scan is not None else None})
                        if scan is not None and not keys and device['name'] == 'Medion Signium Custom Keyboard' and scan not in known:
                            emit({'device': device['name'], 'key': 'UNMAPPED', 'scan': f'0x{scan:04x}'})
                        device['scan'], device['keys'] = None, []
    finally:
        for fd in devices:
            os.close(fd)
        if out:
            out.close()
        print('SONUC: ' + json.dumps(counts, ensure_ascii=False), flush=True)


if __name__ == '__main__':
    main()
