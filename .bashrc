#
# ~/.bashrc
#

# If not running interactively, don't do anything
#if [ -n "$BASH_VERSION" ]; then
#    # Check if we are running interactively
#    if [ -z "$PS1" ]; then
#        return
#    fi
#
#    # Source .bashrc if it hasn't been sourced already
#    if [ -z "${BASH_SOURCE[0]}" -o "${BASH_SOURCE[0]}" != "$BASH_SOURCE" ]; then
#        source ~/.bashrc
#    fi
#
#    # Source .bash_profile if present
#  if [ -f ~/.bash_profile ]; then
#      source ~/.bash_profile
#  fi
#fi

alias ls='ls --color=auto'
alias grep='grep --color=auto'
PS1='[\u@\h \W]\$ '

# don't put duplicate lines or lines starting with space in the history.
# See bash(1) for more options
HISTCONTROL=ignoreboth

# append to the history file, don't overwrite it
shopt -s histappend

# for setting history length see HISTSIZE and HISTFILESIZE in bash(1)
HISTSIZE=1000
HISTFILESIZE=2000

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

# If set, the pattern "**" used in a pathname expansion context will
# match all files and zero or more directories and subdirectories.
#shopt -s globstar

# make less more friendly for non-text input files, see lesspipe(1)
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# set variable identifying the chroot you work in (used in the prompt below)
if [ -z "${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
    debian_chroot=$(cat /etc/debian_chroot)
fi

# set a fancy prompt (non-color, unless we know we "want" color)
case "$TERM" in
    xterm-color|*-256color) color_prompt=yes;;
esac

# uncomment for a colored prompt, if the terminal has the capability; turned
# off by default to not distract the user: the focus in a terminal window
# should be on the output of commands, not on the prompt
#force_color_prompt=yes

if [ -n "$force_color_prompt" ]; then
    if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
	# We have color support; assume it's compliant with Ecma-48
	# (ISO/IEC-6429). (Lack of such support is extremely rare, and such
	# a case would tend to support setf rather than setaf.)
	color_prompt=yes
    else
	color_prompt=
    fi
fi

if [ "$color_prompt" = yes ]; then
    PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
else
    PS1='${debian_chroot:+($debian_chroot)}\u@\h:\w\$ '
fi
unset color_prompt force_color_prompt

# enable programmable completion features (you don't need to enable
# this, if it's already enabled in /etc/bash.bashrc and /etc/profile
# sources /etc/bash.bashrc).
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi

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

# Add git completion
if [ ~/.git-completion.bash ]; then
    . ~/.git-completion.bash
fi

# To auto open browser on aws sso login
export BROWSER=wslview

# nvm
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

export XDG_CONFIG_HOME=~/.config
export JAVA_HOME=/usr/lib/jvm/java-21-openjdk
export PATH=$JAVA_HOME/bin:$PATH
export EDITOR=nvim

# git repo name in bash
force_color_prompt=yes
color_prompt=yes
parse_git_branch() {
git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/(\1)/'
}
if [ "$color_prompt" = yes ]; then
PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[01;31m\]$(parse_git_branch)\[\033[00m\]\$ '
else
PS1='${debian_chroot:+($debian_chroot)}\u@\h:\w$(parse_git_branch)\$ '
fi
unset color_prompt force_color_prompt

# git remember ssh
env=~/.ssh/agent.env

agent_load_env () { test -f "$env" && . "$env" >| /dev/null ; }

agent_start () {
    (umask 077; ssh-agent >| "$env")
    . "$env" >| /dev/null ; }

agent_load_env

# agent_run_state: 0=agent running w/ key; 1=agent w/o key; 2=agent not running
agent_run_state=$(ssh-add -l >| /dev/null 2>&1; echo $?)

if [ ! "$SSH_AUTH_SOCK" ] || [ $agent_run_state = 2 ]; then
    agent_start
    ssh-add
elif [ "$SSH_AUTH_SOCK" ] && [ $agent_run_state = 1 ]; then
    ssh-add
fi

unset env

fastfetch

eval "$(starship init bash)"

# functions
# TODO: move to separate file
# search for packages in pacman and yay using fzf
yayfzf() {
  yay -Slq | fzf \
    --preview 'yay -Si {} | awk -F ": +" '\''{
      gsub(/^ +| +$/, "", $1);
      gsub(/^ +| +$/, "", $2);
      printf "%-15s: %-45s", $1, $2;
      count++;
      if (count % 2 == 0) printf "\n"
    }'\''' \
    --preview-window=top:70%:wrap \
    --layout=reverse
}

# theme toggle
toggle-theme() {

# Define the configuration file path
CONFIG_FILE="${HOME}/.config/ghostty/config"
K9S_CONFIG_FILE="${HOME}/.config/k9s/config.yaml"

# Define the themes to toggle between
THEME_ONE="tokyonight_night"
THEME_TWO="AtomOneLight"

# Check if the configuration file exists
if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "Configuration file not found: $CONFIG_FILE"
  exit 1
fi

# Read the current theme from the configuration file
CURRENT_THEME=$(grep "^theme =" "$CONFIG_FILE" | awk -F'= ' '{print $2}')

# Determine the new theme
if [[ "$CURRENT_THEME" == "$THEME_ONE" ]]; then
  NEW_THEME=$THEME_TWO
else
  NEW_THEME=$THEME_ONE
fi

# Update the theme in the configuration file
sed -i "s/^theme = .*/theme = $NEW_THEME/" "$CONFIG_FILE"

if [[ $NEW_THEME == "$THEME_ONE" ]]; then
  sed -i '/^\s*skin:/s/:.*/: transparent/' "$K9S_CONFIG_FILE"
else
  sed -i '/^\s*skin:/s/:.*/: catppuccin-latte-transparent/' "$K9S_CONFIG_FILE"
fi

echo "Theme toggled to: $NEW_THEME. Presee Ctrl+Shift+, to apply the changes."
}

# Created by `pipx` on 2025-05-25 01:13:53
export PATH="$PATH:/home/mikeyjay/.local/bin"
