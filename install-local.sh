#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

chmod +x "$ROOT/ch340-multi-display.sh" "$ROOT/ch340-udev-trigger.sh"

mkdir -p "$ROOT/bin"
if [ ! -x "$ROOT/bin/feh" ] || [ ! -x "$ROOT/bin/xterm" ]; then
    echo "Bundling feh + xterm into bin/..."
    tmp=$(mktemp -d)
    (cd "$tmp" && apt download feh xterm 2>/dev/null)
    for deb in "$tmp"/*.deb; do
        [ -f "$deb" ] || continue
        dpkg-deb -x "$deb" "$tmp/extract"
    done
    cp "$tmp/extract/usr/bin/feh" "$tmp/extract/usr/bin/xterm" "$ROOT/bin/" 2>/dev/null || true
    chmod +x "$ROOT/bin/"* 2>/dev/null || true
    rm -rf "$tmp"
fi

mkdir -p "$HOME/.config/systemd/user"
cp "$ROOT/ch340-multi-display.service" "$HOME/.config/systemd/user/"
systemctl --user daemon-reload
systemctl --user enable --now ch340-multi-display.service

echo "User listener: $(systemctl --user is-active ch340-multi-display.service)"

install_udev() {
    cp "$ROOT/99-ch340-multi-display.rules" /etc/udev/rules.d/
    udevadm control --reload-rules
    udevadm trigger -c add -s usb
}

UDEV_RULE=/etc/udev/rules.d/99-ch340-multi-display.rules
if [ -f "$UDEV_RULE" ] && cmp -s "$ROOT/99-ch340-multi-display.rules" "$UDEV_RULE"; then
    echo "udev plug trigger: already installed"
elif [ "$(id -u)" -eq 0 ]; then
    install_udev
    echo "udev plug trigger: installed"
else
    echo "Installing udev plug trigger (sudo)..."
    sudo cp "$ROOT/99-ch340-multi-display.rules" /etc/udev/rules.d/
    sudo udevadm control --reload-rules
    sudo udevadm trigger -c add -s usb
    echo "udev plug trigger: installed"
fi

echo "Done. Unplug and replug the CH340 to test."
