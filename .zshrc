
# The following lines were added by compinstall
zstyle :compinstall filename '/home/mikeyjay/.zshrc'

autoload -Uz compinit
compinit
# End of lines added by compinstall
# Lines configured by zsh-newuser-install
HISTFILE=~/.histfile
HISTSIZE=1000
SAVEHIST=1000
bindkey -e
# End of lines configured by zsh-newuser-install
#
eval "$(starship init zsh)"

# open commands in neovim like with bash
autoload -U edit-command-line
zle -N edit-command-line
bindkey '^X^E' edit-command-line
export EDITOR=nvim

# zoxide
eval "$(zoxide init zsh)"

zstyle ':completion:*' menu select

source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# enable color support of ls and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    #alias dir='dir --color=auto'
    #alias vdir='vdir --color=auto'
    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

# set up my custom functions and aliases
source ~/.my_functions.sh
source ~/.my_aliases.sh
source ~/.scripts/mount-encrypted-usb-drive.sh

# nvm setup
source /usr/share/nvm/init-nvm.sh

fastfetch
