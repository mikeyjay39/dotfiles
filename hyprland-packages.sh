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

install_with_yay_if_not_found() {
  local PACKAGE="$1"

  yay -Qi $PACKAGE >/dev/null 2>&1;

  if [ $? -eq 0 ]; then
    echo $PACKAGE already installed
  else
    yay -S "$PACKAGE"
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

# emojis for Waybar
install_if_not_found noto-fonts-emoji

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

# keyboard pointer for Hyprland
install_with_aur_if_not_found wl-kbptr 

# save power on laptops
install_if_not_found tlp
sudo systemctl enable --now tlp.service

# screenshot tool
install_if_not_found hyprshot

# themes for GTK and light dark mode toggle NOTE: Make sure Brave is set to GTK mode and system theme
install_with_yay_if_not_found gnome-themes-extra
