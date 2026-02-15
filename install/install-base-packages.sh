#!/usr/bin/env bash
set -Eeuo pipefail

# Contains basic packages needed for my main driver, for wsl, and for inside containers.

 pacman -Syu --noconfirm
 pacman -S --noconfirm \
	 base-devel \
	 git \
	 which

 # yay
if which yay >/dev/null 2>&1; then
	echo yay already installed
else
	pacman -S --needed base-devel git
	git clone https://aur.archlinux.org/yay.git
	cd yay
	makepkg -si
	cd ..
	rm -rf yay
fi

yay -S --noconfirm \
	btop \
	curl \
	docker \
	docker-compose \
	fastfetch \
	fd \
	fzf \
	git-crypt \
	github-cli \
	man-db \
	neovim \
	rg \
	ripgrep \
	starship \
	stow \
	ttf-jetbrains-mono-nerd \
	unzip \
	wl-clipboard \
	xclip \
	zoxide \
	zsh \
	zsh-autosuggestions \
	zsh-completions\
	zsh-syntax-highlighting

gh extension install dlvhdr/gh-dash
fc-cache -fv
