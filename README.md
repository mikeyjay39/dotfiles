# Mikey Jay's Dotfiles

Tmux agent state, OpenCode V2 lifecycle integration, and mock tests: [`.config/tmux/README.md`](.config/tmux/README.md).

## Installation

```bash
./install-my-stuff.sh
```

### Hyprland

If on Hyprland, run:

```bash
./hyprland-packages.sh
```

You will need to also install drivers for your network printer(s).

#### HP
```bash
sudo pacman -S hplip
```

#### Generic / most printers
```bash
sudo pacman -S foomatic-db foomatic-db-engine foomatic-db-ppds foomatic-db-nonfree-ppds
```

#### Brother, Epson, Canon
often require AUR drivers (`brother-hll2390dw`, `epson-inkjet-printer`, etc).


