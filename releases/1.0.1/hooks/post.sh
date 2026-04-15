#!/usr/bin/env bash

# Make /etc/os-release a symlink to the canonical location
if [ -f /etc/os-release ] && [ ! -L /etc/os-release ]; then
    rm /etc/os-release
    ln -s /usr/lib/os-release /etc/os-release
fi

# Ensure the new scripts are executable
chmod 755 /usr/local/bin/xyvorra-chroot-setup.sh
chmod 755 /usr/local/bin/xyvorra-restore-osrelease

exit 0
