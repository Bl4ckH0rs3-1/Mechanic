from pathlib import Path

qmk = Path("qmk")
cm = Path("cm")
via_dir = qmk / "keyboards/nuphy/air96_v2/ansi/keymaps/via"

src_c = (cm / "concurrent_macros/concurrent_macros.c").read_text(encoding="utf-8")
src_h = (cm / "concurrent_macros/concurrent_macros.h").read_text(encoding="utf-8")

# NuPhy's QMK toolchain is C (not C++), so normalize the fixed-underlying-type enums.
src_c = src_c.replace(
    "typedef enum : uint8_t { CM_FREE, CM_IDLE, CM_DO_NEXT, CM_ERROR } concurrent_macros_state_t;",
    "typedef enum { CM_FREE, CM_IDLE, CM_DO_NEXT, CM_ERROR } concurrent_macros_state_t;",
)
src_h = src_h.replace(
    "typedef enum : uint8_t { MACRO_LED_STATE_IDLE, MACRO_LED_STATE_RUNNING, MACRO_LED_STATE_STOPPING, MACRO_LED_STATE_ERROR } concurrent_macros_led_state_t;",
    "typedef enum { MACRO_LED_STATE_IDLE, MACRO_LED_STATE_RUNNING, MACRO_LED_STATE_STOPPING, MACRO_LED_STATE_ERROR } concurrent_macros_led_state_t;",
)

(via_dir / "concurrent_macros.c").write_text(src_c, encoding="utf-8")
(via_dir / "concurrent_macros.h").write_text(src_h, encoding="utf-8")

rules_path = via_dir / "rules.mk"
rules = rules_path.read_text(encoding="utf-8")
if "DEFERRED_EXEC_ENABLE" not in rules:
    rules += "\nDEFERRED_EXEC_ENABLE = yes\n"
if "concurrent_macros.c" not in rules:
    rules += "SRC += concurrent_macros.c\n"
rules_path.write_text(rules, encoding="utf-8")

# Replace VIA's stock blocking macro launcher with the concurrent macro engine.
via_c = qmk / "quantum/via.c"
v = via_c.read_text(encoding="utf-8")
old = '''bool process_record_via(uint16_t keycode, keyrecord_t *record) {
    // Handle macros
    if (record->event.pressed) {
        if (keycode >= QK_MACRO && keycode <= QK_MACRO_MAX) {
            uint8_t id = keycode - QK_MACRO;
            dynamic_keymap_macro_send(id);
            return false;
        }
    }

    return true;
}'''
new = '''extern bool process_record_concurrent_macros(uint16_t keycode, keyrecord_t *record);

bool process_record_via(uint16_t keycode, keyrecord_t *record) {
    return process_record_concurrent_macros(keycode, record);
}'''
if old not in v:
    raise SystemExit("NuPhy via.c macro handler pattern not found")
via_c.write_text(v.replace(old, new, 1), encoding="utf-8")

# IMPORTANT: Air96 V2 overrides housekeeping_task_kb() and does not call
# housekeeping_task_user(). Therefore the previous build scheduled macros but
# never serviced the deferred executor. matrix_scan_user() is safe here because
# Air96 V2 does not override matrix_scan_kb(), so QMK's default matrix scan path
# calls the user hook continuously.
keymap_c = via_dir / "keymap.c"
k = keymap_c.read_text(encoding="utf-8")
marker = "#include QMK_KEYBOARD_H\n"
hook = '''#include "concurrent_macros.h"

void housekeeping_task_concurrent_macros(void);

void matrix_scan_user(void) {
    housekeeping_task_concurrent_macros();
}

'''
if marker not in k:
    raise SystemExit("Air96 V2 VIA keymap include marker not found")
if "matrix_scan_user(" in k:
    raise SystemExit("Air96 V2 VIA keymap already defines matrix_scan_user")
keymap_c.write_text(k.replace(marker, marker + hook, 1), encoding="utf-8")
