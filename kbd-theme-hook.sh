#!/bin/bash
# Paint the keyboard backlight with the theme accent. Never fail a theme change.
bash "$HOME/.config/omarchy/plugins/io.github.cesarfilho.kbd-backlight/kbd.sh" theme >/dev/null 2>&1 || true
