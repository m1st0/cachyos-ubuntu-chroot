#!/usr/bin/env zsh
# SPDX-FileCopyrightText: Copyright (c) 2026 Maulik Mistry
# SPDX-License-Identifier: Apache-2.0
#
# cachyos_ubuntu_chroot.zsh - Simple script to mount Cachyos for chroot.
#
# Author: Maulik Mistry
# Please share support: https://www.paypal.com/paypalme/m1st0
#                       https://venmo.com/code?user_id=3319592654995456106&created=1753283702


SCRIPT_DIR="${0:A:h}"
source "$SCRIPT_DIR/vendor/tput_shell_colorize/tput_shell_colorize.sh"
source "$SCRIPT_DIR/cachyos_partitions.conf"

sudo mkdir -p "$CACHYOS_MOUNT"
sudo cryptsetup open "$CACHYOS_LUKS" "$CACHYOS_MAPPER"

sudo mount -o subvol=@ "$CACHYOS_MAIN" "$CACHYOS_MOUNT"
sudo mount -o subvol=@home "$CACHYOS_MAIN" "$CACHYOS_MOUNT/home"
sudo mount -o subvol=@root "$CACHYOS_MAIN" "$CACHYOS_MOUNT/root"
sudo mount -o subvol=@srv "$CACHYOS_MAIN" "$CACHYOS_MOUNT/srv"
sudo mount -o subvol=@var/cache "$CACHYOS_MAIN" "$CACHYOS_MOUNT/var/cache"
sudo mount -o subvol=@var/tmp "$CACHYOS_MAIN" "$CACHYOS_MOUNT/var/tmp"
sudo mount -o subvol=@var/log "$CACHYOS_MAIN" "$CACHYOS_MOUNT/var/log"

sudo mount "$CACHYOS_BOOT" "$CACHYOS_MOUNT/boot/efi"

sudo mount --rbind /dev "$CACHYOS_MOUNT/dev"
sudo mount --make-rslave "$CACHYOS_MOUNT/dev"

sudo mount --rbind /proc "$CACHYOS_MOUNT/proc"
sudo mount --make-rslave "$CACHYOS_MOUNT/proc"

sudo mount --rbind /run "$CACHYOS_MOUNT/run"
sudo mount --make-rslave "$CACHYOS_MOUNT/run"

sudo mkdir -p "$CACHYOS_MOUNT/tmp/user/0"
sudo chmod 700 "$CACHYOS_MOUNT/tmp/user/0"

messenger_std "Follow instructions to undo chroot after exit. Chroot starting..."
sudo chroot "$CACHYOS_MOUNT" /usr/bin/zsh
