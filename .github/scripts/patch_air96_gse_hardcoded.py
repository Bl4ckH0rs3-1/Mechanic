from pathlib import Path
import re

qmk = Path('qmk')
keymap = qmk / 'keyboards/nuphy/air96_v2/ansi/keymaps/default/keymap.c'

text = keymap.read_text(encoding='utf-8')

marker = '#include QMK_KEYBOARD_H\n'
if marker not in text:
    raise SystemExit('QMK include marker not found')

code = r'''
/* Air96 V2 onboard GSE toggle engine
 * Physical PGUP: toggle repeated KC_7
 * Physical PGDN: toggle repeated KC_8
 * 20 ms key-down pulse, 170 ms full cycle.
 * Same trigger again stops. Switching trigger stops the old loop and starts the new one.
 */
enum user_keycodes {
    GSE_ST = SAFE_RANGE,
    GSE_AOE,
};

#define GSE_PERIOD_MS 170
#define GSE_HOLD_MS    20

static bool     gse_running        = false;
static bool     gse_key_down       = false;
static uint16_t gse_output_keycode = KC_NO;
static uint32_t gse_cycle_timer    = 0;

static void gse_release_output(void) {
    if (gse_key_down && gse_output_keycode != KC_NO) {
        unregister_code16(gse_output_keycode);
    }
    gse_key_down = false;
}

static void gse_stop(void) {
    gse_release_output();
    gse_running        = false;
    gse_output_keycode = KC_NO;
}

static void gse_start(uint16_t output_keycode) {
    gse_stop();
    gse_output_keycode = output_keycode;
    gse_running        = true;
    gse_cycle_timer    = timer_read32();
    register_code16(gse_output_keycode);
    gse_key_down = true;
}

static void gse_toggle(uint16_t output_keycode) {
    if (gse_running && gse_output_keycode == output_keycode) {
        gse_stop();
    } else {
        gse_start(output_keycode);
    }
}

bool process_record_user(uint16_t keycode, keyrecord_t *record) {
    switch (keycode) {
        case GSE_ST:
            if (record->event.pressed) {
                gse_toggle(KC_7);
            }
            return false;

        case GSE_AOE:
            if (record->event.pressed) {
                gse_toggle(KC_8);
            }
            return false;

        default:
            return true;
    }
}

void matrix_scan_user(void) {
    if (!gse_running) {
        return;
    }

    uint32_t elapsed = timer_elapsed32(gse_cycle_timer);

    if (gse_key_down && elapsed >= GSE_HOLD_MS) {
        gse_release_output();
    }

    if (elapsed >= GSE_PERIOD_MS) {
        gse_release_output();
        register_code16(gse_output_keycode);
        gse_key_down    = true;
        gse_cycle_timer = timer_read32();
    }
}
'''.strip() + '\n\n'

if 'GSE_PERIOD_MS' in text or 'process_record_user(' in text or 'matrix_scan_user(' in text:
    raise SystemExit('default keymap already contains user hooks or GSE engine')

text = text.replace(marker, marker + '\n' + code, 1)

# Replace the base-layer physical PGUP/PGDN pair in both Mac and Windows layers.
pattern = re.compile(r'KC_PGUP\s*,\s*KC_PGDN')
text, count = pattern.subn('GSE_ST,\tGSE_AOE', text)
if count != 2:
    raise SystemExit(f'Expected exactly 2 PGUP/PGDN base-layer pairs, found {count}')

keymap.write_text(text, encoding='utf-8')
print('Patched Air96 V2 default keymap: PGUP=GSE_ST(KC_7), PGDN=GSE_AOE(KC_8)')
