# CH340 Auto-Launch (Image + 3 Terminals)

When a CH340 USB serial adapter (`1a86:7523`) is connected, this project:

1. Shows a fullscreen welcome image on every monitor (`feh`)
2. Opens 3 `gnome-terminal` windows on top with:

| Terminal | Command |
|----------|---------|
| 1 | `cd ..` × 3 from project dir, then `tree /` |
| 2 | `neofetch --ascii_distro archlinux` |
| 3 | `hollywood` |

On disconnect: closes `feh` and terminals, unlocks keyboard, stops LED blink.

## Dependencies

```bash
sudo apt install feh tree neofetch hollywood imagemagick xinput xtrlock x11-xserver-utils usbutils xterm
```

Optional welcome image: place `ch340-welcome.jpg` next to the script (otherwise ImageMagick generates one in Docker at `/app/ch340-welcome.jpg`).

## Setup

One command (installs listener + udev plug trigger):

```bash
chmod +x install-local.sh
./install-local.sh
```

Prompts for sudo once to install the udev rule. Re-run anytime to update; skips udev if already up to date.

Manual equivalent:

```bash
mkdir -p ~/.config/systemd/user
cp ch340-multi-display.service ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable --now ch340-multi-display.service
```

Check status:

```bash
systemctl --user status ch340-multi-display.service
journalctl --user -u ch340-multi-display.service -f
```

Unplug and replug the CH340 to test.

## How it works

1. **User service** — poll loop runs continuously (`Restart=always`), starts at login.
2. **udev on USB add** — starts the user service for your session if it is not already running.
3. **On plug** — listener detects CH340, fullscreen image then 3 xterm windows.
4. **On unplug** — cleanup (feh, terminals, keyboard, LEDs).

## Files

| File | Purpose |
|------|---------|
| `ch340-multi-display.sh` | Polls for CH340, launches image + terminals |
| `ch340-multi-display.service` | systemd user unit |
| `99-ch340-multi-display.rules` | udev trigger on USB add |
| `ch340-udev-trigger.sh` | udev helper: starts user service on plug |
| `install-local.sh` | Enable listener + print udev install steps |
| `docker-compose.yml` / `Dockerfile` | Optional Docker deployment for Pi |

## Notes

- Terminals use compact xterm windows (80×12): **left** (`tree`), **right** (`neofetch`), **bottom-center** (`hollywood`). On GNOME Wayland, `gnome-terminal` ignores window position; the script uses `GDK_BACKEND=x11 xterm` so placement works. Bundled copy: `bin/xterm`.
- Disconnect cleanup uses PIDs in `/tmp/ch340-terminals.pids` and titles `ch340-auto-1` … `ch340-auto-3`.

## Docker (Raspberry Pi)

See `docker-compose.yml`. Container runs the same script with `lsusb` polling and X11 mounts.
