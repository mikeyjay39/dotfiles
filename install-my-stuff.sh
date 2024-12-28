#!/usr/bin/sh

sudo pacman -S git
sudo pacman -S man-db
sudo pacman -S stow

stow -d ~/dotfiles -t ~ .
