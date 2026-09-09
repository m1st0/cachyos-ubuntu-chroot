<!--
SPDX-FileCopyrightText: Copyright (c) 2026 Maulik Mistry
SPDX-License-Identifier: Apache-2.0
-->
# CachyOS Ubuntu CHROOT

A minimal tool set to mount, prepare, and enter a CachyOS environment from an Ubuntu live session (or installed Ubuntu host) without needing `arch-install-scripts`.

Copyright © 2026 Maulik Mistry  
Licensed under the [Apache License 2.0](LICENSE.txt).

## Overview

While CachyOS provides `cachy-chroot` for Arch-based live environments, setting up a proper chroot from Ubuntu often requires extra dependencies like `arch-install-scripts`. This project provides standalone scripts to quickly mount BTRFS subvolumes, set up pseudo-filesystems (`/dev`, `/proc`, `/sys`), and manage teardown safely.

## Features

- Mounts CachyOS BTRFS subvolumes automatically using standard layout configurations.
- Prepares pseudo-filesystems inside the chroot.
- Includes a dedicated teardown script to unmount all targets cleanly.

## Prerequisites

- Ubuntu live environment or active Ubuntu host.
- BTRFS utilities installed (`sudo apt install btrfs-progs`).
- ZSH shell available (`sudo apt install zsh`).

## Setup and Usage

1. **Clone the repository:**

   ```bash
   git clone --recurse-submodules https://github.com/m1st0/cachyos-ubuntu-chroot.git
   cd cachyos-ubuntu-chroot
   ```

   If already cloned without submodules:

   ```bash
   git submodule update --init --recursive
   ```

2. **Make scripts executable:**

   ```bash
   chmod +x cachyos_ubuntu_chroot.zsh cachyos_teardown_chroot.zsh
   ```

3. **Configure partition mappings:**

   Edit `cachyos_paritions.conf` to match your target drive and BTRFS subvolume layout before running the scripts.

4. **Enter the CHROOT environment:**

   ```bash
   sudo ./cachyos_ubuntu_chroot.zsh
   ```

5. **Teardown and unmount:**

   After exiting the chroot session, run the teardown script to safely unmount all partitions:

   ```bash
   sudo ./cachyos_teardown_chroot.zsh
   ```

## Support

Please share support:

- [PayPal](https://www.paypal.com/paypalme/m1st0)
- [Venmo](https://venmo.com/code?user_id=3319592654995456106&created=1753283702)
