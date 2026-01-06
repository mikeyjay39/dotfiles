#!/usr/bin/env bash

# https://wiki.archlinux.org/title/Dm-crypt/Encrypting_a_non-root_file_system

mount-encrypted-usb-drive() {
		if [ "$#" -ne 1 ]; then
				echo "Usage: mount-encrypted-usb-drive <device>. <device> is like /dev/sdx1 and <name>. Use lsblk to find the device."
				return 1
		fi

		local device="$1"
		local name="usb-drive"

		# Create /mnt/usb-drive if it doesn't exist
		if [ ! -d /mnt/usb-drive ]; then
				sudo mkdir -p /mnt/usb-drive
		fi	

		sudo cryptsetup open "$device" "${name}"
		sudo mount "/dev/mapper/$name" /mnt/${name}
	}

unmount-encrypted-usb-drive() {
		if [ "$#" -ne 1 ]; then
				echo "Usage: unmount-encrypted-usb-drive <device>. <device> is like /dev/sdx without the suffix partition number. Use lsblk to find the device."
				return 1
		fi

		local name="usb-drive"
		local device="$1"

		sudo umount -l /mnt/${name}
		sudo cryptsetup close "$name"
		sudo eject "$device"
}
