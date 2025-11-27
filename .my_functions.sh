#!/bin/bash
#
# functions
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
  source ~/.scripts/toggle-theme.sh
}

