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

