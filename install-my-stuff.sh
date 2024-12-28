#!/usr/bin/sh

sudo pacman -S neofetch
sudo pacman -S git
sudo pacman -S man-db
sudo pacman -S stow
sudo pacman -S btop
sudo pacman -Sy neovim
sudo pacman -S ttf-jetbrains-mono-nerd
fc-cache -fv
#sudo pacman -S zsh
#sudo chsh -s /usr/bin/zsh
sudo pacman -S k9s

# kaf
if which kaf >/dev/null 2>&1; then
	echo kaf already installed
else
curl https://raw.githubusercontent.com/birdayz/kaf/master/godownloader.sh | BINDIR=$HOME/bin bash
sudo mv /home/mikeyjay/bin/kaf /usr/bin/kaf
rmdir /home/mikeyjay/bin
fi


stow -d ~/dotfiles -t ~ .
