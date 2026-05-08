# XyvorraOS Changelog


## 1.0.4
Upgraded to Linux kernel 7.0. xyvorra-update now automatically upgrades the kernel on existing machines via pacman and regenerates the GRUB configuration if needed. Added linux-headers package for DKMS module compatibility.

## 1.0.3
Added Xy Command Center — a full-featured system settings app accessible from the app launcher. Covers display, audio, network, firewall, storage, power, Bluetooth, appearance, wallpaper, users, updates, and more. Settings daemon (xysettingsd) runs as a privileged D-Bus service so the GUI never needs root. Wallpaper changes apply live to KDE Plasma. XyvorraOS wallpapers now ship with the OS and appear in the Featured section of the wallpaper picker.

## 1.0.2
Improved staging update pipeline to send only changed files rather than a full payload. Added per-version changelog displayed to users before applying updates. Fixed xyvorra-update.conf being overwritten by OTA updates.

## 1.0.1
Fixed sleep and wake behaviour — monitors now restore layout and system clock syncs after resume. Configured HID-aware USB wakeup at boot and on each sleep cycle. Polkit now allows wheel-group users to mount drives without repeated authentication prompts.

## 1.0.0
Initial release of XyvorraOS. Includes full Hyprland desktop environment, first-boot setup wizard, theme system, and OTA update manager.
