#!/usr/bin/env python3
"""Exercise the actual driver decoder using small userspace input stubs."""
from pathlib import Path
import subprocess
import tempfile

source = (Path(__file__).resolve().parents[1] / 'medion_kbd.c').read_text()
decoder = source[source.index('struct medion_kbd {'):source.index('static int medion_kbd_connect(')]
preamble = r'''
#include <assert.h>
#include <stdbool.h>
#include <stdio.h>
#include <linux/input-event-codes.h>
typedef int irqreturn_t;
#define IRQ_HANDLED 1
#define pr_info_ratelimited(...) ((void)0)
struct serio { void *data; };
struct input_dev { int unused; };
static unsigned short touchpad_scancode;
static bool debug_unknown;
static int event_count, last_key, last_down, scan_count, last_scan;
static void *serio_get_drvdata(struct serio *s) { return s->data; }
static void input_report_key(struct input_dev *d, int k, int v) {
    event_count++; last_key = k; last_down = v;
}
static void input_event(struct input_dev *d, int type, int code, int value) {
    assert(type == EV_MSC && code == MSC_SCAN);
    scan_count++; last_scan = value;
}
static void input_sync(struct input_dev *d) {}
'''
tests = r'''
static struct serio port;
static struct medion_kbd keyboard;
static struct input_dev device;
static void send_byte(unsigned char byte) {
    assert(medion_kbd_interrupt(&port, byte, 0) == IRQ_HANDLED);
}
static void send_key(int code, bool release) {
    if (code & 0xe000) send_byte(0xe0);
    send_byte((code & 0x7f) | (release ? 0x80 : 0));
}
static void pair(int code, int expected) {
    int before = event_count;
    send_key(code, false);
    assert(event_count == before + 1 && last_key == expected && last_down == 1);
    send_key(code, true);
    assert(event_count == before + 2 && last_key == expected && last_down == 0);
    assert(last_scan == code);
}
int main(void) {
    port.data = &keyboard; keyboard.dev = &device;
    const int fn_scans[] = {0x3b,0x3c,0x3d,0x3e,0x3f,0x40,0x41,0x42,0x43,0x44,0x57,0x58};
    const int fn_keys[] = {KEY_F1,KEY_F2,KEY_F3,KEY_F4,KEY_F5,KEY_F6,KEY_F7,KEY_F8,KEY_F9,KEY_F10,KEY_F11,KEY_F12};
    for (int i = 0; i < 12; i++) pair(fn_scans[i], fn_keys[i]);
    pair(0x1e, KEY_A); pair(0x30, KEY_B); pair(0x2e, KEY_C);
    pair(0x1c, KEY_ENTER); pair(0x39, KEY_SPACE);
    pair(0x2a, KEY_LEFTSHIFT); pair(0x36, KEY_RIGHTSHIFT);
    pair(0x1d, KEY_LEFTCTRL); pair(0xe01d, KEY_RIGHTCTRL);
    pair(0xe04b, KEY_LEFT); pair(0xe04d, KEY_RIGHT);
    pair(0xe048, KEY_UP); pair(0xe050, KEY_DOWN);
    pair(0xe053, KEY_DELETE); pair(0xe05b, KEY_LEFTMETA);
    pair(0xe020, KEY_MUTE); pair(0xe02e, KEY_VOLUMEDOWN);
    pair(0xe030, KEY_VOLUMEUP); pair(0xe010, KEY_PREVIOUSSONG);
    pair(0xe019, KEY_NEXTSONG); pair(0xe022, KEY_PLAYPAUSE);
    pair(0xe024, KEY_STOPCD); pair(0xe05f, KEY_SLEEP);
    // Existing firmware quirk: inverted non-escaped Right Alt.
    pair(0x38, KEY_LEFTALT);
    send_byte(0xb8); assert(last_key == KEY_RIGHTALT && last_down == 1);
    send_byte(0x38); assert(last_key == KEY_RIGHTALT && last_down == 0);
    pair(0xe038, KEY_RIGHTALT);
    // An unknown hotkey must remain visible and must not emit a guessed key.
    int before = event_count, scans_before = scan_count;
    send_key(0xe06d, false); send_key(0xe06d, true);
    assert(event_count == before && scan_count == scans_before + 2 && last_scan == 0xe06d);
    touchpad_scancode = 0x76;
    pair(0x76, KEY_TOUCHPAD_TOGGLE);
    touchpad_scancode = 0xe06d;
    pair(0xe06d, KEY_TOUCHPAD_TOGGLE);
    pair(0x3b, KEY_F1); // configuring a separate hotkey must preserve F1.
    port.data = NULL;
    assert(medion_kbd_interrupt(&port, 0x1e, 0) == IRQ_HANDLED);
    puts("PASS: F1-F12, typing/modifiers, arrows, media/sleep, unknown scans, touchpad override");
    return 0;
}
'''
with tempfile.TemporaryDirectory(prefix='medion-scancodes-') as folder:
    c_file = Path(folder) / 'decoder_test.c'
    binary = Path(folder) / 'decoder_test'
    c_file.write_text(preamble + decoder + tests)
    subprocess.run(['clang', '-std=gnu11', '-Wall', '-Wextra', '-Werror',
                    '-Wno-unused-parameter', str(c_file), '-o', str(binary)], check=True)
    subprocess.run([str(binary)], check=True)
