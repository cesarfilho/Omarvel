# Repository Guidelines

## Project Structure & Module Organization

This repository is a small Omarchy bar-widget plugin. `BarWidget.qml` defines the bar control and `Panel.qml` the popup controls; `kbd.sh` implements LED status, brightness, and color operations. `manifest.json` declares the plugin and widget settings. `kbd-theme-hook.sh` optionally applies the active theme accent. The udev rule and `modules-load.conf` support color access and driver loading. `README.md` documents installation and removal; `preview.png` is the widget image. There is no separate test directory.

## Build, Test, and Development Commands

No build system, formatter, or automated test suite is currently configured. Validate the plugin with `omarchy plugin validate .` and check QML with `qmllint -I "$OMARCHY_PATH/shell" BarWidget.qml Panel.qml`. CI runs ShellCheck, manifest, required-file, and symlink checks. On compatible hardware, `bash kbd.sh status` reports LED state; color writes require the configured udev permission.

## Coding Style & Naming Conventions

Keep shell scripts POSIX-conscious where practical, but preserve Bash-specific syntax already used by `kbd.sh`; use two-space indentation and quote variable expansions. Keep QML properties and handlers inside the existing `BarWidget` component and use descriptive lower camel case for properties and functions. Preserve the plugin ID `io.github.cesarfilho.kbd-backlight` consistently across the manifest, hook path, and widget. Keep manifest JSON valid and its schema aligned with the settings used by QML.

## Testing Guidelines

There is no established test framework or coverage requirement. For changes, run the relevant checks above and review JSON edits for valid syntax. Hardware-dependent behavior should be checked on a supported laptop with `/sys/class/leds/rgb:kbd_backlight` present. Do not assume brightness or color operations work on systems without the TUXEDO/Clevo driver.

## Commit & Pull Request Guidelines

Recent commits use short imperative summaries (for example, `Add keyboard backlight bar widget`). Follow that style and keep each change focused. Pull requests should describe user-visible behavior, list manual or automated checks performed, and include a screenshot when the widget’s appearance changes. Call out any changes to required system files or installation/removal steps so users can review them.

## Security & Configuration

System configuration is opt-in: users install the udev rule and module list themselves. Changes affecting `/etc`, group permissions, sysfs, or driver loading must be clearly documented and must not silently write system files during plugin installation or normal widget use.
