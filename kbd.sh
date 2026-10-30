#!/bin/bash
# Keyboard backlight helper for the kbd-backlight plugin and the theme hook.
# Brightness goes through brightnessctl (logind, no root); color is written
# straight to sysfs and needs the udev rule from README.md.
set -u
LED=rgb:kbd_backlight
DIR=/sys/class/leds/$LED
STATE=${XDG_STATE_HOME:-$HOME/.local/state}/omarchy-kbd-backlight
FAVORITES=$STATE/favorites
THEME_COLORS=$HOME/.local/state/omarchy/current/theme/colors.toml
FAVORITE_LIMIT=8

hex_to_rgb() { # #rrggbb -> "R G B"
  local h=${1#\#}
  [[ $h =~ ^[0-9a-fA-F]{6}$ ]] || return 1
  printf '%d %d %d' "0x${h:0:2}" "0x${h:2:2}" "0x${h:4:2}"
}

set_color() { # "R G B"
  echo "$1" > "$DIR/multi_intensity" 2>/dev/null || { echo "cannot write color: install the udev rule (see README.md)" >&2; exit 3; }
}

normalize_hex() {
  local hex=${1#\#}
  [[ $hex =~ ^[0-9a-fA-F]{6}$ ]] || return 1
  printf '#%s' "${hex,,}"
}

list_favorites() {
  [[ -f $FAVORITES ]] || return 0
  while IFS= read -r hex; do
    [[ $hex =~ ^#[0-9a-fA-F]{6}$ ]] || continue
    printf '%s\n' "${hex,,}"
  done < "$FAVORITES"
}

add_favorite() {
  local hex count
  hex=$(normalize_hex "${1:-}") || { echo "bad color: ${1:-}" >&2; return 1; }
  mkdir -p "$STATE" || return 1
  if [[ -f $FAVORITES ]] && grep -Fxiq -- "$hex" "$FAVORITES"; then return 0; fi
  count=$(grep -Ec '^#[0-9a-fA-F]{6}$' "$FAVORITES" 2>/dev/null || true)
  if (( count >= FAVORITE_LIMIT )); then
    echo "favorite limit reached ($FAVORITE_LIMIT)" >&2
    return 5
  fi
  printf '%s\n' "$hex" >> "$FAVORITES"
}

remove_favorite() {
  local hex tmp
  hex=$(normalize_hex "${1:-}") || { echo "bad color: ${1:-}" >&2; return 1; }
  [[ -f $FAVORITES ]] || return 0
  tmp="$FAVORITES.tmp.$$"
  if ! awk -v target="$hex" 'tolower($0) != tolower(target)' "$FAVORITES" > "$tmp"; then
    rm -f "$tmp"
    return 1
  fi
  mv "$tmp" "$FAVORITES"
}

if [[ ${1:-status} == favorite ]]; then
  case ${2:-list} in
    list) list_favorites ;;
    add) add_favorite "${3:-}" ;;
    remove) remove_favorite "${3:-}" ;;
    *) echo "usage: kbd.sh favorite list|add #rrggbb|remove #rrggbb" >&2; exit 1 ;;
  esac
  exit $?
fi

[[ -d $DIR ]] || { echo "no $LED (is tuxedo_keyboard loaded?)" >&2; exit 2; }
max=$(<"$DIR/max_brightness")

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
    [[ -f $THEME_COLORS ]] || { echo "theme accent not found" >&2; exit 4; }
    hex=$(sed -n 's/^accent *= *"\(#[0-9a-fA-F]\{6\}\)".*/\1/p' "$THEME_COLORS" | head -1)
    [[ -n $hex ]] || { echo "theme accent not found" >&2; exit 4; }
    set_color "$(hex_to_rgb "$hex")" ;;
  *) echo "usage: kbd.sh status|toggle|step N|brightness N|color #rrggbb|theme|favorite list|add|remove #rrggbb" >&2; exit 1 ;;
esac
