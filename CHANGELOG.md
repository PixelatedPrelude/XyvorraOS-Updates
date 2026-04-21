# XyvorraOS Changelog

## 1.0.2
Improved staging update pipeline to send only changed files rather than a full payload. Added per-version changelog displayed to users before applying updates. Fixed xyvorra-update.conf being overwritten by OTA updates.

## 1.0.1
Fixed sleep and wake behaviour — monitors now restore layout and system clock syncs after resume. Configured HID-aware USB wakeup at boot and on each sleep cycle. Polkit now allows wheel-group users to mount drives without repeated authentication prompts.

## 1.0.0
Initial release of XyvorraOS. Includes full Hyprland desktop environment, first-boot setup wizard, theme system, and OTA update manager.
