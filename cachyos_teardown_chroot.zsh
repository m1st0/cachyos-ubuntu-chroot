#!/usr/bin/env zsh
# SPDX-FileCopyrightText: Copyright (c) 2026 Maulik Mistry
# SPDX-License-Identifier: Apache-2.0
#
# cachyos_teardown_chroot.zsh - Simple script teardown CachyOS chroot on Ubuntu live environment.
#
# Author: Maulik Mistry
# Please share support: https://www.paypal.com/paypalme/m1st0
#                       https://venmo.com/code?user_id=3319592654995456106&created=1753283702


setopt ERR_EXIT
setopt PIPE_FAIL
setopt NO_UNSET

# Re-execute the complete script as root.
if (( EUID != 0 )); then
    exec sudo -- "$0" "$@"
fi

SCRIPT_DIR="${0:A:h}"
source "$SCRIPT_DIR/vendor/tput_shell_colorize/tput_shell_colorize.sh"
source "$SCRIPT_DIR/cachyos_partitions.conf"

# Check required configuration variables before using them.
typeset -a required_variables=(
    CACHYOS_MOUNT
    CACHYOS_MAIN
    CACHYOS_BOOT
    CACHYOS_LUKS
    CACHYOS_MAPPER
)

for variable_name in "${required_variables[@]}"; do
    if [[ -z "${(P)variable_name:-}" ]]; then
        messenger_end "Required variable is missing or empty: $variable_name"
        exit 1
    fi
done

# Refuse dangerous or ambiguous mount targets.
if [[ "$CACHYOS_MOUNT" != /* || "$CACHYOS_MOUNT" == "/" ]]; then
    messenger_end "Unsafe CachyOS mount target: '$CACHYOS_MOUNT'"
    exit 1
fi

if [[ "$CACHYOS_MOUNT" == "/mnt" || "$CACHYOS_MOUNT" == "/home" ]]; then
    messenger_end "Refusing to recursively unmount broad directory: '$CACHYOS_MOUNT'"
    exit 1
fi

if ! mountpoint -q -- "$CACHYOS_MOUNT"; then
    messenger_end "CachyOS mount target is not mounted: '$CACHYOS_MOUNT'"
    exit 1
fi

messenger_std "Unmounting everything beneath $CACHYOS_MOUNT"

# First remove the visible CachyOS mount tree. This unmounts the main
# root subvolume (@) and the other visible subvolume/system mounts.
umount --recursive -- "$CACHYOS_MOUNT"

# The main root mount may have hidden the temporary subvolume-id=5 mount.
# Check again after removing @, because .btrfs-top may now be visible.
BTRFS_TOP_MOUNT="${CACHYOS_MOUNT%/}/.btrfs-top"

if mountpoint -q -- "$BTRFS_TOP_MOUNT"; then
    messenger_std "Unmounting hidden Btrfs top-level mount: $BTRFS_TOP_MOUNT"
    umount --recursive -- "$BTRFS_TOP_MOUNT"
fi

# Confirm that neither the main mount nor the temporary top-level mount
# remains active.
if mountpoint -q -- "$CACHYOS_MOUNT"; then
    messenger_end "CachyOS mount is still active: '$CACHYOS_MOUNT'"
    exit 1
fi

if mountpoint -q -- "$BTRFS_TOP_MOUNT"; then
    messenger_end "Btrfs top-level mount is still active: '$BTRFS_TOP_MOUNT'"
    exit 1
fi

# Close the encrypted mapping only if it is currently open.
if cryptsetup status "$CACHYOS_MAPPER" >/dev/null 2>&1; then
    messenger_std "Closing encrypted mapping: $CACHYOS_MAPPER"
    cryptsetup close "$CACHYOS_MAPPER"
else
    messenger_std "Encrypted mapping is already closed: $CACHYOS_MAPPER"
fi

messenger_end "CachyOS chroot teardown complete."
