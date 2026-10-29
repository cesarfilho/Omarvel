#!/bin/bash
# Keyboard backlight helper for the kbd-backlight plugin and the theme hook.
# Brightness goes through brightnessctl (logind, no root); color is written
# straight to sysfs and needs the udev rule from README.md.
set -u
LED=rgb:kbd_backlight
DIR=/sys/class/leds/$LED
STATE=${XDG_STATE_HOME:-$HOME/.local/state}/omarchy-kbd-backlight
THEME_COLORS=$HOME/.local/state/omarchy/current/theme/colors.toml

[[ -d $DIR ]] || { echo "no $LED (is tuxedo_keyboard loaded?)" >&2; exit 2; }
max=$(<"$DIR/max_brightness")

hex_to_rgb() { # #rrggbb -> "R G B"
  local h=${1#\#}
  [[ $h =~ ^[0-9a-fA-F]{6}$ ]] || return 1
  printf '%d %d %d' "0x${h:0:2}" "0x${h:2:2}" "0x${h:4:2}"
}

set_color() { # "R G B"
  echo "$1" > "$DIR/multi_intensity" 2>/dev/null || { echo "cannot write color: install the udev rule (see README.md)" >&2; exit 3; }
}

case ${1:-status} in
  status)
    printf '{"brightness":%d,"max":%d,"color":"%s"}\n' "$(<"$DIR/brightness")" "$max" "$(<"$DIR/multi_intensity")" ;;
  toggle)
    mkdir -p "$STATE"
    cur=$(<"$DIR/brightness")
    if (( cur > 0 )); then
      echo "$cur" > "$STATE/last"; brightnessctl -q -d "$LED" set 0
    else
      last=$(cat "$STATE/last" 2>/dev/null || echo "$max"); (( last > 0 )) || last=$max
      brightnessctl -q -d "$LED" set "$last"
    fi ;;
  step) # step +N or -N (percent); brightnessctl wants "+N%" / "N%-"
    n=${2:-+10}
    if [[ $n == -* ]]; then arg="${n#-}%-"; else arg="${n#+}%+"; fi
    brightnessctl -q -d "$LED" set "$arg" ;;
  brightness)
    brightnessctl -q -d "$LED" set "${2:-100}%" ;;
  color) # color #rrggbb
    rgb=$(hex_to_rgb "${2:-}") || { echo "bad color: ${2:-}" >&2; exit 1; }
    set_color "$rgb" ;;
  theme) # use the theme accent
    [[ -f $THEME_COLORS ]] || exit 0
    hex=$(sed -n 's/^accent *= *"\(#[0-9a-fA-F]\{6\}\)".*/\1/p' "$THEME_COLORS" | head -1)
    [[ -n $hex ]] || exit 0
    set_color "$(hex_to_rgb "$hex")" ;;
  *) echo "usage: kbd.sh status|toggle|step N|brightness N|color #rrggbb|theme" >&2; exit 1 ;;
esac
