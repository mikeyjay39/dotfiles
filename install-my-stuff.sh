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

install_with_yay_if_not_found() {
  local PACKAGE="$1"

yay -Qi $PACKAGE >/dev/null 2>&1

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
 yay -S "$PACKAGE"
fi

}

source ./install/install-base-packages.sh

install_if_not_found kubectl 
install_if_not_found k9s 
install_if_not_found psql postgresql 
install_if_not_found ghostty 
install_if_not_round npm 
install_if_not_found rustup 
component add rust-analyzer

# kaf
if which kaf >/dev/null 2>&1; then
	echo kaf already installed
else
curl https://raw.githubusercontent.com/birdayz/kaf/master/godownloader.sh | BINDIR=$HOME/bin bash
sudo mv ${HOME}/bin/kaf /usr/bin/kaf
rmdir ${HOME}/bin
fi

# git-autocompletion
if [ -f ~/.git-completion.bash ]; then
	echo git-completion already installed
else
sudo curl https://raw.githubusercontent.com/git/git/master/contrib/completion/git-completion.bash -o /usr/share/git/completion/git-completion.bash
ln -s /usr/share/git/completion/git-completion.bash ~/.git-completion.bash
fi

# java
install_with_yay_if_not_found openjdk21-src
if [ archlinux-java get -ne "java-21-openjdk" ]; then
	sudo archlinux-java set java-21-openjdk
fi

# jdtls
install_with_yay_if_not_found jdtls

# typescript debugger
install_with_yay_if_not_found vscode-js-debug

# informant
if which informant >/dev/null 2>&1; then
	echo informant already installed
else
	yay -S informant
fi

# codelldb - for rust debugging
install_with_aur_if_not_found codelldb codelldb-bin

# zsh
install_with_yay_if_not_found zsh
install_with_yay_if_not_found zsh-autosuggestions 
install_with_yay_if_not_found zsh-completions
install_with_yay_if_not_found zsh-syntax-highlighting

# set up my custom functions and aliases
if [ ! -e ~/.my_functions.sh ]; then
        ln -s ~/dotfiles/.my_functions.sh ~/.my_functions.sh
fi

source ~/.my_functions.sh

if [ ! -e ~/.my_aliases.sh ]; then
        ln -s ~/dotfiles/.my_aliases.sh ~/.my_aliases.sh
fi

systemctl start docker.service
systemctl enable docker.service
usermod -aG docker $USER
newgrp docker
stow -d ~/dotfiles -t ~ . --adopt

# nvm
install_with_yay_if_not_found nvm
source /usr/share/nvm/init-nvm.sh
nvm install 22
nvm use 22

npm install -g typescript

