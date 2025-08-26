#!/usr/bin/env bash

options=" Lock | hyprlock
 Sleep | systemctl suspend
󰈆 Logout | hyprctl dispatch exit
 Reboot | systemctl reboot
 Shutdown | systemctl poweroff"

choice=$(echo -e "$options" | wofi --show dmenu -p "Power:" -L 5 | cut -d'|' -f2)

[ -n "$choice" ] && bash -c "$choice"
