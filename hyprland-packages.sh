#!/usr/bin/sh

install_if_not_found() {
local COMMAND="$1"

if [ -z "$2" ]; then
	local PACKAGE="$COMMAND"
else
	local PACKAGE="$2"
fi

if pacman -Q "$COMMAND" >/dev/null 2>&1; then
	echo "$COMMAND already installed"
else
	echo "Installing $PACKAGE"
sudo pacman -S "$PACKAGE"
fi
}

# arg 1 is name of command, arg 2 is package name
install_with_aur_if_not_found() {
local COMMAND="$1"

if [ -z "$2" ]; then
	local PACKAGE="$COMMAND"
else
	local PACKAGE="$2"
fi

if which "$COMMAND" >/dev/null 2>&1; then
	echo "$COMMAND already installed"
else
	echo "Installing $PACKAGE"
 yay -S "$PACKAGE"
fi

}


install_if_not_found wireplumber
install_if_not_found networkmanager
install_if_not_found network-manager-applet
sudo systemctl enable NetworkManager.service --now
install_if_not_found xdg-desktop-portal-hyprland
install_if_not_found swww
install_if_not_found blueman
sudo systemctl enable --now bluetooth
install_if_not_found mako
# clipboard for Neovim to work on Wayland
install_if_not_found wl-clipboard

# printers
install_if_not_found system-config-printer
# below is the driver for HP printers, uncomment if you have an HP printer
# install_if_not_found hplip
install_if_not_found avahi
install_if_not_found nss-mdns
install_if_not_found cups
install_if_not_found cups-filters
install_if_not_found cups-browsed
sudo systemctl enable --now avahi-daemon.service
sudo systemctl enable --now cups.service
# end printers

install_with_aur_if_not_found timeshift-autosnap
