# Keyboard Backlight

Omarchy bar widget for the keyboard backlight of Clevo/Tongfen laptops
(for example Avell). It controls the `rgb:kbd_backlight` LED.

- Left click: toggle the backlight on and off.
- Scroll: change the brightness.
- Right click: cycle through six colors.
- Optional hook: paint the keyboard with the theme accent color on every theme change.

## Requirements

- An Omarchy shell with plugin support.
- A laptop whose keyboard backlight is driven by
  [tuxedo-drivers](https://github.com/tuxedocomputers/tuxedo-drivers)
  (AUR: `tuxedo-drivers-dkms`). Check that `/sys/class/leds/rgb:kbd_backlight` exists.
- `brightnessctl` (ships with Omarchy).

## Install

1. Install the plugin and enable it:

       omarchy plugin add https://github.com/cesarfilho/Omarvel --enable

2. Install the kernel driver and load it:

       omarchy pkg aur add tuxedo-drivers-dkms
       sudo modprobe -a tuxedo_keyboard clevo_wmi clevo_acpi tuxedo_io

3. Optional, only for color. Brightness works without this. The color file is
   root-only by default, so this rule gives the `input` group write access and
   loads the driver at boot. Review both files first; they are the only system
   files this plugin touches, and nothing is written without you running these lines:

       sudo install -m644 90-kbd-backlight.rules /etc/udev/rules.d/
       sudo install -m644 modules-load.conf /etc/modules-load.d/tuxedo.conf
       sudo udevadm control --reload && sudo udevadm trigger -s leds

   Your user must be in the `input` group.

4. Optional, follow the theme accent:

       omarchy hook install theme-set kbd-theme-hook.sh

## Remove

    omarchy plugin remove io.github.cesarfilho.kbd-backlight
    rm ~/.config/omarchy/hooks/theme-set.d/kbd-theme-hook.sh
    sudo rm -f /etc/udev/rules.d/90-kbd-backlight.rules /etc/modules-load.d/tuxedo.conf
    sudo udevadm control --reload

The driver stays installed. Remove it with `sudo pacman -Rns tuxedo-drivers-nocompatcheck-dkms`
if nothing else needs it.

## Helper

`kbd.sh` does the work and can be used on its own:

    kbd.sh status | toggle | step +10 | step -10 | brightness 50 | color '#0a84ff' | theme

## License

MIT. External dependency: tuxedo-drivers (GPL-2.0), installed separately.
