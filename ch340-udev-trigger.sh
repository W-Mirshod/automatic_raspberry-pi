#!/bin/bash

for runtime_dir in /run/user/[0-9]*; do
    uid="${runtime_dir#/run/user/}"
    user=$(id -nu "$uid" 2>/dev/null) || continue
    [ -S "$runtime_dir/bus" ] || continue
    runuser -u "$user" -- \
        env XDG_RUNTIME_DIR="$runtime_dir" \
        DBUS_SESSION_BUS_ADDRESS="unix:path=$runtime_dir/bus" \
        systemctl --user start ch340-multi-display.service 2>/dev/null || true
done
