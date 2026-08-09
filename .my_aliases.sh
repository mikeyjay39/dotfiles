#! /usr/bin/env

alias cd='z'

# history for zsh
alias history='history 0'

# rclone sync with protondrive
# can add --dry-run flag
alias proton-drive-docs-backup='rclone copy protondrive:file_cabinet/ /mnt/usb-drive/my_documents/file_cabinet/ --progress'
