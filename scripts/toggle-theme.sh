#!/usr/bin/env bash

# Define the configuration file path
CONFIG_FILE="${HOME}/.config/ghostty/config"
K9S_CONFIG_FILE="${HOME}/.config/k9s/config.yaml"

# Define the themes to toggle between
THEME_ONE="TokyoNight Night"
THEME_TWO="Atom One Light"

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
  sed -i 's/cursor-color/# cursor-color/' "$CONFIG_FILE"
  sed -i 's/# background = #0C0C0C/background = #0C0C0C/' "$CONFIG_FILE"
      # GTK
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
    gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark'
    # Qt
    # sed -i 's/Light/Dark/' ~/.config/qt5ct/qt5ct.conf
    pkill brave  # close Brave  
    nohup brave --enable-features=WebUIDarkMode --force-dark-mode > /dev/null 2>&1 &
  

else
  sed -i '/^\s*skin:/s/:.*/: catppuccin-latte-transparent/' "$K9S_CONFIG_FILE"
  sed -i 's/# cursor-color/cursor-color/' "$CONFIG_FILE"
  sed -i 's/background = #0C0C0C/# background = #0C0C0C/' "$CONFIG_FILE"
      # GTK
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-light'
    gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita'
    # Qt
    # sed -i 's/Dark/Light/' ~/.config/qt5ct/qt5ct.conf
    pkill brave  
    nohup brave --disable-features=WebUIDarkMode > /dev/null 2>&1 &

fi

echo "Theme toggled to: $NEW_THEME. Presee Ctrl+Shift+, to apply the changes."

