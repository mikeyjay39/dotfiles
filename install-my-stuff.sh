#!/usr/bin/sh

install_if_not_found() {
local COMMAND="$1"

if [ -z "$2" ]; then
	local PACKAGE="$COMMAND"
else
	local PACKAGE="$2"
fi

if which "$COMMAND" >/dev/null 2>&1; then
	echo "$COMMAND already installed"
else
sudo pacman -S "$PACKAGE"
fi
}

install_if_not_found which
install_iff_not_found cc base-devel
install_if_not_found fastfetch
install_if_not_found git
install_if_not_found man man-db
install_if_not_found stow
install_if_not_found btop
install_if_not_found nvim neovim
install_if_not_found k9s
install_if_not_found psql postgresql
install_if_not_found xclip
install_if_not_found ghostty
install_if_not_found zellij

if which docker >/dev/null 2>&1; then
	echo docker already installed
else
install_if_not_found docker
sudo systemctl start docker.service
sudo systemctl enable docker.service
sudo usermod -aG docker $USER
newgrp docker
fi

install_if_not_found docker-compose

fc-list | grep "JetBrainsMono" >/dev/null 2>&1;
if [ $? -eq 0 ]; then
	echo "JetBrainsMonoNerdFont alrady installed"
else
sudo pacman -S ttf-jetbrains-mono-nerd
fc-cache -fv
fi

#sudo pacman -S zsh
#sudo chsh -s /usr/bin/zsh

# kaf
if which kaf >/dev/null 2>&1; then
	echo kaf already installed
else
curl https://raw.githubusercontent.com/birdayz/kaf/master/godownloader.sh | BINDIR=$HOME/bin bash
sudo mv /home/mikeyjay/bin/kaf /usr/bin/kaf
rmdir /home/mikeyjay/bin
fi


stow -d ~/dotfiles -t ~ .
