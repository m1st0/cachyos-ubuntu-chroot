#!/usr/bin/env zsh
# SPDX-FileCopyrightText: Copyright (c) 2026 Maulik Mistry
# SPDX-License-Identifier: Apache-2.0
#
# cachyos_teardown_chroot.zsh - Simple script teardown CachyOS chroot on Ubuntu live environment.
#
# Author: Maulik Mistry
# Please share support: https://www.paypal.com/paypalme/m1st0
#                       https://venmo.com/code?user_id=3319592654995456106&created=1753283702


SCRIPT_DIR="${0:A:h}"
source "$SCRIPT_DIR/vendor/tput_shell_colorize/tput_shell_colorize.sh"
source "$SCRIPT_DIR/cachyos_partitions.conf"

# Leave CachyOS directories
cd ~

# Undo chroot after exit
sudo rm -rfi "$CACHYOS_MOUNT/tmp/user/0"
sudo rm -rfi "$CACHYOS_MOUNT/tmp/user/"

sudo umount "$CACHYOS_MOUNT/boot/efi"

sudo umount -R "$CACHYOS_MOUNT/dev"
sudo umount -R "$CACHYOS_MOUNT/proc"
sudo umount -R "$CACHYOS_MOUNT/run"

sudo umount -R "$CACHYOS_MOUNT/home"
sudo umount -R "$CACHYOS_MOUNT/root"
sudo umount -R "$CACHYOS_MOUNT/srv"
sudo umount -R "$CACHYOS_MOUNT/var/cache"
sudo umount -R "$CACHYOS_MOUNT/var/tmp"
sudo umount -R "$CACHYOS_MOUNT/var/log"

sudo umount "$CACHYOS_MOUNT"

sudo cryptsetup close "$CACHYOS_MAPPER"

messenger_end "Check for umount and cryptsetup errors. Script done."
