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
