#!/usr/bin/env zsh
# SPDX-FileCopyrightText: Copyright (c) 2026 Maulik Mistry
# SPDX-License-Identifier: Apache-2.0
#
# cachyos_ubuntu_chroot.zsh - Mount Cachyos for chroot from Ubuntu.
#
# Author: Maulik Mistry
# Please share support: https://www.paypal.com/paypalme/m1st0
#                       https://venmo.com/code?user_id=3319592654995456106&created=1753283702


setopt ERR_EXIT
setopt PIPE_FAIL
setopt NO_UNSET

# Re-execute as root so the complete script runs with root privileges.
if (( EUID != 0 )); then
    exec sudo -- "$0" "$@"
fi

# Severe issues existed with namespace mounts not releasing including Snap and
# systemd-resolvd. Therefore attempting to make sure we stay isolated with a
# private namespace.
if [[ -z ${IN_PRIVATE_MOUNT_NS-} ]]; then
    export IN_PRIVATE_MOUNT_NS=1
    exec unshare --mount --fork --propagation private "$0" "$@"
fi

mount --make-rprivate /

SCRIPT_DIR="${0:A:h}"
source "$SCRIPT_DIR/vendor/tput_shell_colorize/tput_shell_colorize.sh"
source "$SCRIPT_DIR/cachyos_partitions.conf"

# Verify required configuration variables.
REQUIRED_VARIABLES=(
    CACHYOS_MOUNT
    CACHYOS_MAIN
    CACHYOS_BOOT
    CACHYOS_LUKS
    CACHYOS_MAPPER
)

for variable_name in "${REQUIRED_VARIABLES[@]}"; do
    if [[ -z "${(P)variable_name:-}" ]]; then
        messenger_end "Required variable is missing or empty: $variable_name"
        exit 1
    fi
done

# Refuse obviously dangerous mount targets.
if [[ "$CACHYOS_MOUNT" != /* || "$CACHYOS_MOUNT" == "/" ]]; then
    messenger_end "Unsafe CachyOS mount target: $CACHYOS_MOUNT"
    exit 1
fi

# This is used for checking whether subvolumes exist.
BTRFS_TOP="$CACHYOS_MOUNT/.btrfs-top"

is_mounted() {
    mountpoint -q -- "$1"
}

die() {
    messenger_end "$*"
    exit 1
}

mount_btrfs_subvolume() {
    local subvol="$1"
    local target="$2"

    mkdir -p -- "$target"

    if is_mounted "$target"; then
        messenger_std "Already mounted: $target"
        return 0
    fi

    if ! btrfs subvolume show "$BTRFS_TOP/$subvol" >/dev/null 2>&1; then
        messenger_std "Skipping missing subvolume: $subvol"
        return 0
    fi

    messenger_std "Mounting subvolume $subvol at $target ..."
    mount -o "subvol=$subvol" "$CACHYOS_MAIN" "$target"
}

mount_bind_tree() {
    local source="$1"
    local target="$2"

    mkdir -p -- "$target"

    if is_mounted "$target"; then
        messenger_end "Already mounted: $target ."
        return 0
    fi

    messenger_std "Binding $source to $target ..."
    mount --rbind "$source" "$target"
    mount --make-rslave "$target"
}

teardown() {
    local variable_name

    for variable_name in "${REQUIRED_VARIABLES[@]}"; do
        if [[ -z "${(P)variable_name:-}" ]]; then
            messenger_end "Required variable is missing or empty: $variable_name"
            return 1
        fi
    done

    # Refuse dangerous or ambiguous mount targets.
    if [[ "$CACHYOS_MOUNT" != /* || "$CACHYOS_MOUNT" == "/" ]]; then
        messenger_end "Unsafe CachyOS mount target: '$CACHYOS_MOUNT'"
        return 1
    fi

    if [[ "$CACHYOS_MOUNT" == "/mnt" || "$CACHYOS_MOUNT" == "/home" ]]; then
        messenger_end "Refusing to recursively unmount broad directory: '$CACHYOS_MOUNT'"
        return 1
    fi

    if ! mountpoint -q -- "$CACHYOS_MOUNT"; then
        messenger_end "CachyOS mount target is not mounted: '$CACHYOS_MOUNT'"
        return 1
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
        return 1
    fi

    if mountpoint -q -- "$BTRFS_TOP_MOUNT"; then
        messenger_end "Btrfs top-level mount is still active: '$BTRFS_TOP_MOUNT'"
        return 1
    fi

    # Close the encrypted mapping only if it is currently open.
    if cryptsetup status "$CACHYOS_MAPPER" >/dev/null 2>&1; then
        messenger_std "Closing encrypted mapping: $CACHYOS_MAPPER"
        cryptsetup close "$CACHYOS_MAPPER"
    else
        messenger_std "Encrypted mapping is already closed: $CACHYOS_MAPPER"
    fi

    messenger_end "CachyOS chroot teardown complete."
}

# Teardown setup against private namespace and failures.
CLEANUP_STATUS=0

TRAPEXIT() {
    local ORIGINAL_STATUS=$?

    if (( ! CLEANUP_STATUS )); then
        CLEANUP_STATUS=1
        teardown
    fi

    return $ORIGINAL_STATUS
}

TRAPINT() {
    exit 130
}

TRAPTERM() {
    exit 143
}

# Validate the configured block device before changing mounts.
if [[ ! -b "$CACHYOS_LUKS" ]]; then
    die "Btrfs device does not exist: $CACHYOS_LUKS"
fi

mkdir -p -- "$CACHYOS_MOUNT"

# Open the encrypted device if it is not already open.
if ! cryptsetup status "$CACHYOS_MAPPER" >/dev/null 2>&1; then
    messenger_std "Opening encrypted CachyOS filesystem..."
    cryptsetup open "$CACHYOS_LUKS" "$CACHYOS_MAPPER"
else
    messenger_end "LUKS mapping already open: $CACHYOS_MAPPER ."
fi

# Mount the Btrfs top-level subvolume temporarily.
# This exposes all subvolumes, including currently unmounted ones.
mkdir -p -- "$BTRFS_TOP"

if ! is_mounted "$BTRFS_TOP"; then
    messenger_std "Mounting Btrfs top-level subvolume..."
    mount -o subvolid=5 "$CACHYOS_MAIN" "$BTRFS_TOP"
fi

# Mount the CachyOS root subvolume first.
if ! is_mounted "$CACHYOS_MOUNT"; then
    messenger_std "Mounting CachyOS root subvolume..."
    mount -o subvol=@ "$CACHYOS_MAIN" "$CACHYOS_MOUNT"
fi

# Keep only subvolumes that are actually present in the CachyOS installation.
#
# Verify these against:
#
#   grep -E '^[^#].*[[:space:]]btrfs[[:space:]]' \
#       "$CACHYOS_MOUNT/etc/fstab"
#
# Missing entries are skipped automatically.
typeset -a CACHYOS_SUBVOLUMES=(
    "@home:$CACHYOS_MOUNT/home"
    "@root:$CACHYOS_MOUNT/root"
    "@srv:$CACHYOS_MOUNT/srv"
    "@var/cache:$CACHYOS_MOUNT/var/cache"
    "@var/tmp:$CACHYOS_MOUNT/var/tmp"
    "@var/log:$CACHYOS_MOUNT/var/log"
)

for entry in "${CACHYOS_SUBVOLUMES[@]}"; do
    subvol="${entry%%:*}"
    target="${entry#*:}"

    mount_btrfs_subvolume "$subvol" "$target"
done

# Mount the EFI system partition.
mkdir -p -- "$CACHYOS_MOUNT/boot/efi"

if ! is_mounted "$CACHYOS_MOUNT/boot/efi"; then
    messenger_std "Mounting EFI system partition..."
    mount "$CACHYOS_BOOT" "$CACHYOS_MOUNT/boot/efi"
fi

# Prepare virtual filesystems for chroot.
mount_bind_tree /dev  "$CACHYOS_MOUNT/dev"
mount_bind_tree /proc "$CACHYOS_MOUNT/proc"
mount_bind_tree /sys  "$CACHYOS_MOUNT/sys"
mount_bind_tree /run  "$CACHYOS_MOUNT/run"

# Optional directory used by some tools or desktop-related operations.
mkdir -p -- "$CACHYOS_MOUNT/tmp/user/0"
chmod 700 -- "$CACHYOS_MOUNT/tmp/user/0"

messenger_std "Final CachyOS mount layout:"
findmnt -R -- "$CACHYOS_MOUNT"

messenger_std "Follow instructions to undo chroot after exit."
messenger_std "Starting chroot..."

while :; do
    linefeed
    messenger_std "  r) Re-enter CachyOS chroot"
    messenger_std "  s) Open shell outside chroot"
    messenger_std "  t) Teardown and exit"
    print -n "> "

    if ! read -r choice; then
        exit 130
    fi

    case "$choice" in
        r|R)
            setopt local_options no_err_exit
            chroot "$CACHYOS_MOUNT" /usr/bin/zsh
            ;;

        s|S)
            /usr/bin/env zsh
            ;;

        t|T)
            exit 0
            ;;

        *)
            messenger_end "Invalid choice."
            ;;
    esac
done
