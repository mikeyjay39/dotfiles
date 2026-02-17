#!/usr/bin/env bash
set -Eeuo pipefail

pacman -S --noconfirm \
	 rustup \
	 postgresql-libs 

rustup toolchain install stable
rustup default stable
rustup component add rust-analyzer

