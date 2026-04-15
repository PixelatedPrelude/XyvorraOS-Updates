#!/usr/bin/env bash
# /usr/local/bin/xyvorra-chroot-setup.sh
# XyvorraOS Post-Pacstrap Chroot Configuration — v1.1.0
#
# Runs inside the newly-installed system via arch-chroot.
# Called by xyvorra-install with these environment variables:
#
#   XYVORRA_HOSTNAME    e.g. "xyvorra"
#   XYVORRA_ROOT_PASS   plain-text root password
#   XYVORRA_BOOT_MODE   "uefi" or "bios"
#   XYVORRA_TARGET_DISK bare disk name, e.g. "sda"
#   XYVORRA_OS_VER      e.g. "v1.0.0"
#
# NOTE: User account (username/password/timezone/locale) is no longer collected
# by the installer.  Instead, a temporary 'xyvorra' account is created here with
# SDDM auto-login so the first-boot PyQt6 setup wizard (xysetup) runs on the
# desktop.  The wizard creates the real user account, then reboots to the SDDM
# login screen.

set -euo pipefail
exec >> /var/log/xyvorra-install.log 2>&1

log() { printf '[%s] %s\n' "$(date '+%F %T')" "$*"; }
log "=== chroot setup start ==="

# ── Validate required variables ───────────────────────────────────────────────
for _var in XYVORRA_HOSTNAME XYVORRA_ROOT_PASS \
            XYVORRA_BOOT_MODE XYVORRA_TARGET_DISK XYVORRA_OS_VER; do
    [[ -n "${!_var:-}" ]] || {
        log "ERROR: ${_var} not set"
        printf '\n[XyvorraOS] ✗  Missing variable: %s\n' "${_var}" >&2
        exit 1
    }
done

# ── Timezone (placeholder — xysetup wizard will finalise on first boot) ───────
log "Timezone: UTC (placeholder — wizard sets the real timezone on first boot)"
ln -sf "/usr/share/zoneinfo/UTC" /etc/localtime
hwclock --systohc

# ── Locale (placeholder — xysetup wizard will finalise on first boot) ─────────
log "Locale: en_US.UTF-8 (placeholder — wizard sets the real locale on first boot)"
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# ── Hostname ──────────────────────────────────────────────────────────────────
log "Hostname: ${XYVORRA_HOSTNAME}"
echo "${XYVORRA_HOSTNAME}" > /etc/hostname
cat > /etc/hosts << HOSTS
127.0.0.1   localhost
::1         localhost
127.0.1.1   ${XYVORRA_HOSTNAME}.localdomain ${XYVORRA_HOSTNAME}
HOSTS

# ── Console keymap ────────────────────────────────────────────────────────────
echo "KEYMAP=us" > /etc/vconsole.conf

# ── OS branding ───────────────────────────────────────────────────────────────
# Write to the canonical location (/usr/lib/os-release) first.  On Arch-based
# systems /etc/os-release is a symlink to ../usr/lib/os-release and the
# 'filesystem' package owns that file, so a plain `pacman -Syu` would silently
# restore "Arch Linux" branding.  Writing here plus the NoUpgrade guard below
# keeps XyvorraOS branding intact across all future updates.
log "Writing OS branding to /usr/lib/os-release"
mkdir -p /usr/lib
cat > /usr/lib/os-release << OSREL
NAME="XyvorraOS"
VERSION="${XYVORRA_OS_VER}"
VERSION_ID="${XYVORRA_OS_VER}"
ID=xyvorraos
ID_LIKE=arch
PRETTY_NAME="XyvorraOS ${XYVORRA_OS_VER}"
CPE_NAME="cpe:2.3:o:xyvorraos:xyvorraos:${XYVORRA_OS_VER}:*:*:*:*:*:*:*"
BUILD_ID=rolling
ANSI_COLOR="38;2;88;36;178"
HOME_URL="https://github.com/PixelatedPrelude/XyvorraOS-Linux-Distro"
DOCUMENTATION_URL="https://github.com/PixelatedPrelude/XyvorraOS-Linux-Distro"
SUPPORT_URL="https://github.com/PixelatedPrelude/XyvorraOS-Linux-Distro/issues"
BUG_REPORT_URL="https://github.com/PixelatedPrelude/XyvorraOS-Linux-Distro/issues"
LOGO=xyvorraos
OSREL

# Point /etc/os-release at the canonical file (replace any existing symlink or
# stale regular file left behind by the Arch 'filesystem' package).
ln -sf ../usr/lib/os-release /etc/os-release

# Prevent pacman from overwriting /usr/lib/os-release when the 'filesystem'
# package is upgraded.
if ! grep -q 'NoUpgrade.*usr/lib/os-release' /etc/pacman.conf 2>/dev/null; then
    sed -i 's|^#NoUpgrade\s*=\s*$|NoUpgrade   = usr/lib/os-release|' /etc/pacman.conf \
        || echo 'NoUpgrade   = usr/lib/os-release' >> /etc/pacman.conf
fi

cat > /etc/xyvorra-release << XYREL
XYVORRA_VERSION="${XYVORRA_OS_VER}"
XYVORRA_CODENAME="StarForge"
XYREL

# ── MOTD ──────────────────────────────────────────────────────────────────────
cat > /etc/motd << 'MOTD'

  ╔════════════════════════════════════════════════════════════════╗
  ║  ✦  XyvorraOS  ·  Space-Age Linux  ✦                          ║
  ╚════════════════════════════════════════════════════════════════╝

    Run  xysetup --force            to relaunch setup wizard
    Run  xyvorra-set-theme <name>   to change colour theme
    Run  nmtui                      to manage network connections

  ──────────────────────────────────────────────────────────────

MOTD

# ── Initramfs ─────────────────────────────────────────────────────────────────
log "Generating initramfs"
mkinitcpio -P

# ── Passwords ────────────────────────────────────────────────────────────────
log "Setting passwords"
echo "root:${XYVORRA_ROOT_PASS}" | chpasswd

# ── Temporary first-boot user ('xyvorra') ────────────────────────────────────
# The real user account is created by the PyQt6 first-boot wizard (xysetup).
# This temporary account exists only to auto-login on first boot so the wizard
# can run on the desktop.  The wizard renames it (or creates a new account)
# and removes the auto-login SDDM config before rebooting.
log "Creating temporary first-boot user: xyvorra"
useradd -m -G wheel,audio,video,storage,network,input -s /bin/bash xyvorra
passwd -d xyvorra                                    # no password — auto-login only
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers
# Allow xyvorra to run privileged commands without a password during first-boot setup
cat > /etc/sudoers.d/xyvorra-firstboot << 'SUDOEOF'
Defaults:xyvorra !requiretty
xyvorra ALL=(ALL:ALL) NOPASSWD: ALL
SUDOEOF
chmod 0440 /etc/sudoers.d/xyvorra-firstboot

# ── GRUB ─────────────────────────────────────────────────────────────────────
log "Installing GRUB (mode: ${XYVORRA_BOOT_MODE})"
cat > /etc/default/grub << 'GRUBCFG'
GRUB_DEFAULT=0
GRUB_TIMEOUT=5
GRUB_DISTRIBUTOR="XyvorraOS"
GRUB_CMDLINE_LINUX_DEFAULT="quiet"
GRUB_CMDLINE_LINUX=""
GRUB_PRELOAD_MODULES="part_gpt part_msdos"
GRUBCFG

if [[ "${XYVORRA_BOOT_MODE}" == "uefi" ]]; then
    grub-install \
        --target=x86_64-efi \
        --efi-directory=/boot/efi \
        --bootloader-id=XyvorraOS \
        --recheck \
        || { log "grub-install (primary) failed"; exit 1; }

    grub-install \
        --target=x86_64-efi \
        --efi-directory=/boot/efi \
        --bootloader-id=BOOT \
        --removable \
        --recheck \
        || { log "grub-install (fallback) failed"; exit 1; }

    mkdir -p /boot/efi/EFI/BOOT
    cp /boot/efi/EFI/XyvorraOS/grubx64.efi /boot/efi/EFI/BOOT/BOOTX64.EFI \
        || log "Warning: could not copy grubx64.efi to fallback path"
else
    grub-install \
        --target=i386-pc \
        "/dev/${XYVORRA_TARGET_DISK}" \
        || { log "grub-install failed"; exit 1; }
fi

echo 'GRUB_DISABLE_OS_PROBER=true' >> /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg \
    || { log "grub-mkconfig failed"; exit 1; }

# ── Services ──────────────────────────────────────────────────────────────────
log "Enabling services"
systemctl enable NetworkManager
systemctl enable sddm
systemctl set-default graphical.target

# ── VM guest services ─────────────────────────────────────────────────────────
# Detect the hypervisor and enable the appropriate guest agent so the VM
# environment (display scaling, shared clipboard, etc.) works out of the box.
_PRODUCT_NAME=$(cat /sys/class/dmi/id/product_name 2>/dev/null || true)
_SYS_VENDOR=$(cat /sys/class/dmi/id/sys_vendor     2>/dev/null || true)
if [[ "${_PRODUCT_NAME}" == *"VirtualBox"* ]] || [[ "${_SYS_VENDOR}" == *"innotek"* ]]; then
    log "VirtualBox detected — enabling vboxservice"
    systemctl enable vboxservice.service 2>/dev/null || true
elif [[ "${_PRODUCT_NAME}" == *"VMware"* ]] || [[ "${_SYS_VENDOR}" == *"VMware"* ]]; then
    log "VMware detected — enabling vmtoolsd"
    systemctl enable vmtoolsd.service 2>/dev/null || true
elif [[ -d /sys/bus/vmbus ]]; then
    log "Hyper-V detected — enabling hv services"
    systemctl enable hv_fcopy_daemon.service hv_kvp_daemon.service hv_vss_daemon.service 2>/dev/null || true
fi

# Mask systemd-firstboot so it never prompts for timezone/locale/hostname on
# first boot — all of those are already configured above by this script.
log "Masking systemd-firstboot.service"
systemctl mask systemd-firstboot.service

# ── SDDM ─────────────────────────────────────────────────────────────────────
mkdir -p /etc/sddm.conf.d
# ── XyLog SDDM theme (permanent base config) ────────────────────────────────
cat > /etc/sddm.conf.d/xylog.conf << SDDMCFG
[Theme]
Current=XyLog

[General]
HaltCommand=/usr/bin/systemctl poweroff
RebootCommand=/usr/bin/systemctl reboot
Numlock=none
DefaultSession=plasma.desktop

[Users]
RememberLastUser=true
RememberLastSession=true
DefaultUser=xyvorra
SDDMCFG

# ── First-boot auto-login (removed by xysetup wizard after setup) ────────────
# xysetup deletes this file before rebooting to the SDDM login screen.
cat > /etc/sddm.conf.d/xysetup-autologin.conf << 'AUTOLOGIN'
[Autologin]
User=xyvorra
Session=plasma
Relogin=false
AUTOLOGIN

cat > /etc/sddm.conf.d/xylog-env.conf << 'ENVEOF'
[Environment]
QML_XHR_ALLOW_FILE_READ=1
QML_XHR_ALLOW_FILE_WRITE=1
# Force Qt Quick software renderer so SDDM/XyLog renders without hardware
# OpenGL — required in VirtualBox and other VMs without 3D acceleration.
QSG_RHI_BACKEND=software
QT_QUICK_BACKEND=software
ENVEOF

# Pre-select KDE Plasma as the remembered session for the temporary first-boot user.
mkdir -p /var/lib/sddm
cat > /var/lib/sddm/state.conf << 'SDDMSTATE'
[Last]
User=xyvorra
Session=plasma.desktop

[Users]
xyvorra=plasma.desktop
SDDMSTATE
chown -R sddm:sddm /var/lib/sddm 2>/dev/null || true

# Ensure the XyLog theme cache directory exists and is writable by sddm
# so that SystemHUD.qml can persist the chosen theme colour across reboots.
mkdir -p /var/cache/xylog
chown sddm:sddm /var/cache/xylog 2>/dev/null || true
chmod 755 /var/cache/xylog

# ── User config — copy from /etc/skel ────────────────────────────────────────
# /etc/skel was fully populated by customize_airootfs.sh during the ISO build.
# Copy configs into the temporary first-boot user's home.
# The xysetup wizard will copy these to the real user's home after account creation.
log "Copying /etc/skel configs to xyvorra's home"

USER_HOME="/home/xyvorra"

# useradd -m already ran above and copied /etc/skel — but only the files
# that existed at install time. Re-copy explicitly to be safe and pick up
# any files created later in this script or missed by useradd.
if [[ -d /etc/skel ]]; then
    cp -rn /etc/skel/. "${USER_HOME}/" 2>/dev/null || true
fi

# Ensure all config subdirs exist (belt and suspenders)
mkdir -p \
    "${USER_HOME}/.config/hypr" \
    "${USER_HOME}/.config/waybar" \
    "${USER_HOME}/.config/alacritty" \
    "${USER_HOME}/.config/dunst" \
    "${USER_HOME}/.config/wofi" \
    "${USER_HOME}/.config/xyvorra" \
    "${USER_HOME}/.config/sway" \
    "${USER_HOME}/.config/openbox" \
    "${USER_HOME}/Pictures" \
    "${USER_HOME}/.local/state/xyvorra"

# ── KDE Plasma — suppress first-run wizard ────────────────────────────────────
# plasma-initial-setup and plasma-welcome both check for this marker file.
log "Suppressing KDE initial-setup wizard"
touch "${USER_HOME}/.config/plasma-initial-setup-skipped"

# plasma-welcome (KDE 5.27+ / KDE 6) uses this key to decide whether to show.
mkdir -p "${USER_HOME}/.config"
cat > "${USER_HOME}/.config/plasma-welcomerc" << 'PLASMAWELCOME'
[General]
LiveEnvironment=false
PLASMAWELCOME

# ── Fallback: write configs directly if skel copy missed anything ─────────────
# Hyprland color defaults
if [[ ! -f "${USER_HOME}/.config/hypr/xyvorra-colors.conf" ]]; then
    cat > "${USER_HOME}/.config/hypr/xyvorra-colors.conf" << 'COLORS'
# XyvorraOS default theme: Galactic Byzantium
$col_active_border   = rgba(a78bfaee) rgba(7c3aedee) 45deg
$col_inactive_border = rgba(1e0a3a99)
$col_background      = 0x0d0520
$col_accent          = 0xa78bfa
COLORS
fi

# Empty monitor conf (xysetup fills this in)
touch "${USER_HOME}/.config/hypr/xyvorra-monitors.conf"

# Hyprpaper config
if [[ ! -f "${USER_HOME}/.config/hypr/hyprpaper.conf" ]]; then
    cat > "${USER_HOME}/.config/hypr/hyprpaper.conf" << 'HYPRPAPER'
preload  = /usr/share/xyvorra/wallpapers/wallpaper-byzantium.svg
wallpaper = ,/usr/share/xyvorra/wallpapers/wallpaper-byzantium.svg
splash = false
HYPRPAPER
fi

# Waybar theme CSS
if [[ ! -f "${USER_HOME}/.config/waybar/xyvorra-theme.css" ]]; then
    cat > "${USER_HOME}/.config/waybar/xyvorra-theme.css" << 'WAYBARTHEME'
/* XyvorraOS Waybar theme: Galactic Byzantium */
@define-color accent      #a78bfa;
@define-color background  #0a0718;
@define-color surface     #13093a;
@define-color text        #e2dcf8;
@define-color border      #4c1d95;
WAYBARTHEME
fi

# Hyprland main config
if [[ ! -f "${USER_HOME}/.config/hypr/hyprland.conf" ]]; then
    cat > "${USER_HOME}/.config/hypr/hyprland.conf" << 'HYPRCONF'
# XyvorraOS Hyprland config

monitor = ,preferred,auto,1
source   = ~/.config/hypr/xyvorra-colors.conf
source   = ~/.config/hypr/xyvorra-monitors.conf

env = WLR_NO_HARDWARE_CURSORS,1
env = XCURSOR_SIZE,24
env = XDG_SESSION_TYPE,wayland
env = XDG_CURRENT_DESKTOP,Hyprland
env = XDG_SESSION_DESKTOP,Hyprland
env = QT_QPA_PLATFORM,wayland

exec-once = dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE
exec-once = /usr/lib/polkit-kde-authentication-agent-1
exec-once = xyvorra-apply-theme
exec-once = hyprpaper
exec-once = waybar
exec-once = dunst
exec-once = nm-applet --indicator
exec-once = sleep 2 && xysetup

general {
    gaps_in  = 5; gaps_out = 10; border_size = 2
    col.active_border   = $col_active_border
    col.inactive_border = $col_inactive_border
    layout = dwindle; resize_on_border = true
}
decoration {
    rounding = 10
    blur   { enabled = true; size = 3; passes = 1 }
    shadow { enabled = true; range = 8; color = rgba(7c3aed55) }
}
animations {
    enabled = yes
    bezier  = snap, 0.05, 0.9, 0.1, 1.05
    animation = windows,    1, 7, snap
    animation = windowsOut, 1, 7, default, popin 80%
    animation = border,     1, 10, default
    animation = fade,       1, 7, default
    animation = workspaces, 1, 6, default
}
input {
    kb_layout    = us; follow_mouse = 1; sensitivity = 0
    touchpad { natural_scroll = no; tap-to-click = yes }
}
misc {
    force_default_wallpaper  = 0
    disable_hyprland_logo    = true
    disable_splash_rendering = true
}

$mainMod = SUPER
bind = $mainMod,       Return, exec,        alacritty
bind = $mainMod,       Q,      killactive
bind = $mainMod,       M,      exit
bind = $mainMod,       E,      exec,        thunar
bind = $mainMod,       V,      togglefloating
bind = $mainMod,       R,      exec,        wofi --show drun
bind = $mainMod,       F,      fullscreen
bind = $mainMod SHIFT, T,      exec,        echo -e "byzantium\nverdance\nvoid\nrosefire" | wofi --dmenu --prompt "Theme:" | xargs -r xyvorra-set-theme

bind = $mainMod, left,  movefocus, l
bind = $mainMod, right, movefocus, r
bind = $mainMod, up,    movefocus, u
bind = $mainMod, down,  movefocus, d

bind = $mainMod, 1, workspace, 1
bind = $mainMod, 2, workspace, 2
bind = $mainMod, 3, workspace, 3
bind = $mainMod, 4, workspace, 4
bind = $mainMod, 5, workspace, 5

bind = $mainMod SHIFT, 1, movetoworkspace, 1
bind = $mainMod SHIFT, 2, movetoworkspace, 2
bind = $mainMod SHIFT, 3, movetoworkspace, 3
bind = $mainMod SHIFT, 4, movetoworkspace, 4
bind = $mainMod SHIFT, 5, movetoworkspace, 5

bind = , Print, exec, grim -g "$(slurp)" ~/Pictures/shot-$(date +%F-%H%M%S).png
bind = , XF86AudioRaiseVolume,  exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+
bind = , XF86AudioLowerVolume,  exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
bind = , XF86AudioMute,         exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
bind = , XF86MonBrightnessUp,   exec, brightnessctl set 10%+
bind = , XF86MonBrightnessDown, exec, brightnessctl set 10%-
HYPRCONF
fi

# ── Sway config ───────────────────────────────────────────────────────────────
if [[ ! -f "${USER_HOME}/.config/sway/config" ]]; then
    cat > "${USER_HOME}/.config/sway/config" << 'SWAYCONF'
# XyvorraOS Sway config

output * bg /usr/share/xyvorra/wallpapers/wallpaper-byzantium.svg fill

input "type:keyboard" {
    xkb_layout us
}
input "type:touchpad" {
    tap enabled
    natural_scroll enabled
}

set $mod Mod4
set $term alacritty
set $menu wofi --show drun

bindsym $mod+Return exec $term
bindsym $mod+q kill
bindsym $mod+d exec $menu
bindsym $mod+v floating toggle
bindsym $mod+f fullscreen toggle
bindsym $mod+Left focus left
bindsym $mod+Right focus right
bindsym $mod+Up focus up
bindsym $mod+Down focus down
bindsym $mod+Shift+1 move container to workspace number 1
bindsym $mod+Shift+2 move container to workspace number 2
bindsym $mod+Shift+3 move container to workspace number 3
bindsym $mod+Shift+4 move container to workspace number 4
bindsym $mod+Shift+5 move container to workspace number 5
bindsym $mod+1 workspace number 1
bindsym $mod+2 workspace number 2
bindsym $mod+3 workspace number 3
bindsym $mod+4 workspace number 4
bindsym $mod+5 workspace number 5

exec dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE
exec xyvorra-apply-theme
exec waybar
exec dunst
exec nm-applet --indicator
exec xysetup
SWAYCONF
fi

# ── Openbox autostart ─────────────────────────────────────────────────────────
if [[ ! -f "${USER_HOME}/.config/openbox/autostart" ]]; then
    cat > "${USER_HOME}/.config/openbox/autostart" << 'OBSTART'
# XyvorraOS Openbox autostart
xyvorra-apply-theme &
nm-applet &
dunst &
xysetup &
OBSTART
fi

# ── XDG autostart (for KDE Plasma and other non-Hyprland sessions) ───────────
mkdir -p /etc/xdg/autostart
cat > /etc/xdg/autostart/xyvorra-apply-theme.desktop << 'DESKTOP'
[Desktop Entry]
Type=Application
Name=XyvorraOS Apply Theme
Comment=Re-applies the saved XyvorraOS colour theme on login
Exec=/usr/local/bin/xyvorra-apply-theme
Categories=Settings;System;
X-KDE-autostart-phase=1
X-GNOME-Autostart-enabled=true
X-GNOME-Autostart-Delay=0
DESKTOP

# xysetup first-boot wizard autostart (removed by the wizard itself after setup)
cat > /etc/xdg/autostart/xysetup.desktop << 'DESKTOP'
[Desktop Entry]
Type=Application
Name=XyvorraOS First-Boot Setup
Comment=First-boot configuration wizard. Re-run: xysetup --force
Exec=/usr/local/bin/xysetup
Categories=Settings;System;
X-KDE-autostart-phase=2
X-GNOME-Autostart-enabled=true
DESKTOP

# ── xdg-user-dirs ────────────────────────────────────────────────────────────
su - xyvorra -c "xdg-user-dirs-update" 2>/dev/null || true

# ── SDDM user avatar ──────────────────────────────────────────────────────────
# Copy the default astronaut SVG so the login screen shows an avatar.
log "Configuring SDDM user avatar for xyvorra"
_AVATAR_SRC="/usr/share/sddm/themes/XyLog/assets/default-avatar.svg"
_ACCOUNTS_ICONS="/var/lib/AccountsService/icons"
mkdir -p "${_ACCOUNTS_ICONS}"
if [[ -f "${_AVATAR_SRC}" ]]; then
    cp "${_AVATAR_SRC}" "${_ACCOUNTS_ICONS}/xyvorra"
    chmod 644 "${_ACCOUNTS_ICONS}/xyvorra"
fi
# ~/.face — primary lookup used by SDDM's Qt user model
ln -sf "${_ACCOUNTS_ICONS}/xyvorra" "${USER_HOME}/.face" 2>/dev/null || true

# ── Ownership ────────────────────────────────────────────────────────────────
chown -R xyvorra:xyvorra "${USER_HOME}"
# Allow the sddm daemon (runs as its own user) to traverse the home directory.
chmod o+x "${USER_HOME}"

log "=== chroot setup complete ==="
