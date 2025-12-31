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
    echo $PACKAGE already install
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


install_if_not_found which
install_if_not_found cc base-devel
install_if_not_found fastfetch
install_if_not_found git
install_if_not_found man man-db
install_if_not_found stow
install_if_not_found btop
install_if_not_found nvim neovim
install_if_not_found kubectl
install_if_not_found k9s
install_if_not_found psql postgresql
install_if_not_found xclip
install_if_not_found unzip
install_if_not_found ghostty
install_if_not_round npm
install_if_not_found rustup
rustup component add rust-analyzer

# yay
if which yay >/dev/null 2>&1; then
	echo yay already installed
else
sudo pacman -S --needed base-devel git
git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si
cd ..
rm -rf yay
fi

# github cli tool
install_if_not_found gh github-cli
# gh tui
gh extension install dlvhdr/gh-dash

install_with_yay_if_not_found git-crypt

install_if_not_found starship
# for nvim telescope
install_if_not_found rg ripgrep
# for nvim telescope. sharkdp/dp
install_if_not_found fd
install_if_not_found fzf
instanll_if_not_found rustup
install_if_not_found rust-analyzer


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

# zoxide
install_with_yay_if_not_found zoxide

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

stow -d ~/dotfiles -t ~ . --adopt

# nvm
if which node >/dev/null 2>&1; then
	echo node already installed
else
    # Download and install nvm:
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
    
    # in lieu of restarting the shell
    \. "$HOME/.nvm/nvm.sh"
    
    # Download and install Node.js:
    nvm install 22
    
    # Verify the Node.js version:
    node -v # Should print "v22.16.0".
    nvm current # Should print "v22.16.0".
    
    # Verify npm version:
    npm -v # Should print "10.9.2".
fi

npm install -g typescript

