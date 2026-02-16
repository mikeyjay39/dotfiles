#!/usr/bin/env bash
set -Eeuo pipefail

yay -S --noconfirm \
	vscode-js-debug

npm install -g typescript

