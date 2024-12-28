#!/usr/bin/sh

sudo pacman -S neofetch
sudo pacman -S git
sudo pacman -S man-db
sudo pacman -S stow
sudo pacman -S btop

stow -d ~/dotfiles -t ~ .
