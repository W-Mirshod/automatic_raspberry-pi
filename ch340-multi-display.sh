#!/bin/bash

# CH340 Multi-Display Picture Script (Docker Version)
# This script monitors for CH340 connection and opens pictures on ALL displays

# Log the connection
echo "$(date): CH340 Multi-Display Docker container started!"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

list_monitor_geometries() {
    xrandr --query 2>/dev/null | grep " connected" | grep -o '[0-9]\+x[0-9]\++[0-9]\++[0-9]\+'
}

parse_monitor_geom() {
    local geom=$1
    MONITOR_W=$(echo "$geom" | cut -d'x' -f1)
    MONITOR_H=$(echo "$geom" | cut -d'x' -f2 | cut -d'+' -f1)
    MONITOR_X=$(echo "$geom" | cut -d'+' -f2)
    MONITOR_Y=$(echo "$geom" | cut -d'+' -f3)
}

stop_terminals() {
    if [ -f /tmp/ch340-terminals.pids ]; then
        while read -r pid; do
            kill "$pid" 2>/dev/null || true
        done < /tmp/ch340-terminals.pids
        rm -f /tmp/ch340-terminals.pids
    fi
    pkill -f "ch340-auto-[123]" 2>/dev/null || true
    pkill -f "xterm.*ch340-auto" 2>/dev/null || true
}

launch_terminals() {
    echo "$(date): Launching compact terminals (left / right / bottom layout)..."
    stop_terminals
    sleep 0.5

    local commands=(
        "cd '$SCRIPT_DIR' && cd .. && cd .. && cd .. && tree /"
        "neofetch --ascii_distro archlinux"
        "hollywood"
    )

    local term_cols=80
    local term_rows=12
    local char_w=9 char_h=18
    local term_w=$((term_cols * char_w + 28))
    local term_h=$((term_rows * char_h + 66))
    local margin=48

    local mon_x=0 mon_y=0 mon_w=1366 mon_h=768
    local monitors
    monitors=$(list_monitor_geometries)
    if [ -n "$monitors" ]; then
        parse_monitor_geom "$(echo "$monitors" | head -n1)"
        mon_x=$MONITOR_X
        mon_y=$MONITOR_Y
        mon_w=$MONITOR_W
        mon_h=$MONITOR_H
    fi

    local positions_x=(
        $((mon_x + margin))
        $((mon_x + mon_w - term_w - margin))
        $((mon_x + (mon_w - term_w) / 2))
    )
    local positions_y=(
        $((mon_y + (mon_h - term_h) / 2))
        $((mon_y + (mon_h - term_h) / 2))
        $((mon_y + mon_h - term_h - margin))
    )

    local xterm_bin="$SCRIPT_DIR/bin/xterm"
    if [ ! -x "$xterm_bin" ]; then
        xterm_bin="$(command -v xterm || true)"
    fi
    if [ -z "$xterm_bin" ]; then
        echo "xterm not found; cannot place windows on Wayland"
        return 1
    fi

    : > /tmp/ch340-terminals.pids
    local n
    for n in 0 1 2; do
        GDK_BACKEND=x11 "$xterm_bin" -fa 'Monospace' -fs 10 \
            -geometry "${term_cols}x${term_rows}+${positions_x[$n]}+${positions_y[$n]}" \
            -title "ch340-auto-$((n + 1))" \
            -e bash -lc "${commands[$n]}; exec bash" &
        echo $! >> /tmp/ch340-terminals.pids
        echo "Launched ch340-auto-$((n + 1)) at ${term_cols}x${term_rows}+${positions_x[$n]}+${positions_y[$n]}"
        sleep 0.3
    done

    echo "Terminals launched."
}

# Function to launch pictures
launch_pictures() {
    echo "$(date): CH340 detected! Launching fullscreen picture..."

    pkill -f feh 2>/dev/null || true
    sleep 0.5

    if [ -f "$SCRIPT_DIR/ch340-welcome.jpg" ]; then
        PICTURE_PATH="$SCRIPT_DIR/ch340-welcome.jpg"
    elif [ -f /app/ch340-welcome.jpg ]; then
        PICTURE_PATH="/app/ch340-welcome.jpg"
    else
        PICTURE_PATH="$SCRIPT_DIR/ch340-welcome.jpg"
        echo "Creating default welcome image..."
        magick -size 1920x1080 xc:"#1a86" -pointsize 72 -fill white -gravity center -annotate +0+0 "CH340 CONNECTED!\nMulti-Display Active" "$PICTURE_PATH"
    fi

    echo "Launching fullscreen image on all monitors..."
    monitors=$(list_monitor_geometries)

    if [ -z "$monitors" ]; then
        feh --fullscreen --auto-zoom --borderless --zoom fill "$PICTURE_PATH" &
    else
        idx=0
        for geom in $monitors; do
            parse_monitor_geom "$geom"
            echo "Monitor $idx: ${MONITOR_W}x${MONITOR_H}+${MONITOR_X}+${MONITOR_Y}"
            feh --auto-zoom --borderless --zoom fill --geometry "${MONITOR_W}x${MONITOR_H}+${MONITOR_X}+${MONITOR_Y}" "$PICTURE_PATH" &
            idx=$((idx + 1))
        done
    fi

    sleep 2

    block_keyboard
    control_leds

    echo "Fullscreen picture launched."
}

# Function to block/unblock keyboard input
block_keyboard() {
    echo "Blocking keyboard input..."

    # Method 1: Try to disable keyboard devices with xinput
    echo "Attempting to disable keyboard devices with xinput..."
    xinput --list | grep -i keyboard | grep -o 'id=[0-9]*' | cut -d'=' -f2 | while read id; do
        echo "Disabling keyboard device $id"
        xinput --disable "$id" 2>/dev/null || echo "Failed to disable keyboard $id"
    done

    # Method 2: Use xtrlock as backup screen lock
    echo "Starting screen lock with xtrlock..."
    xtrlock &
    echo $! > /tmp/xtrlock.pid

    # Method 3: Disable keyboard layout as additional measure
    echo "Disabling keyboard layout..."
    setxkbmap -option 2>/dev/null || echo "Failed to disable keyboard layout"
}

unblock_keyboard() {
    echo "Unblocking keyboard input..."

    # Method 1: Re-enable keyboard devices
    echo "Re-enabling keyboard devices..."
    xinput --list | grep -i keyboard | grep -o 'id=[0-9]*' | cut -d'=' -f2 | while read id; do
        echo "Re-enabling keyboard device $id"
        xinput --enable "$id" 2>/dev/null || echo "Failed to enable keyboard $id"
    done

    # Method 2: Kill screen lock
    if [ -f /tmp/xtrlock.pid ]; then
        echo "Killing screen lock process..."
        kill $(cat /tmp/xtrlock.pid) 2>/dev/null || true
        rm -f /tmp/xtrlock.pid
    fi
    pkill -f xtrlock 2>/dev/null || true

    # Method 3: Restore keyboard layout
    echo "Restoring keyboard layout..."
    setxkbmap -layout us 2>/dev/null || echo "Failed to restore keyboard layout"
}

# Function to control LEDs
control_leds() {
    echo "Starting LED control sequence..."

    # Find all available LED devices
    led_devices=$(find /sys/class/leds -name "*" -type d 2>/dev/null | grep -v "device" | head -20)

    if [ -z "$led_devices" ]; then
        echo "No LED devices found"
        return
    fi

    echo "Found LED devices: $led_devices"

    # Kill any existing LED control processes
    pkill -f "led_blink\|led_control" 2>/dev/null || true

    # Start LED control in background
    (
        # Keep one LED always on (first available LED)
        first_led=$(echo "$led_devices" | head -n1)
        if [ -n "$first_led" ] && [ -w "$first_led/brightness" ]; then
            echo "Keeping LED always on: $first_led"
            echo 1 > "$first_led/brightness"
        fi

        # Make remaining LEDs blink fast
        echo "$led_devices" | tail -n +2 | while read led; do
            if [ -w "$led/brightness" ]; then
                echo "Making LED blink fast: $led"
                # Fast blinking pattern
                while true; do
                    echo 1 > "$led/brightness" 2>/dev/null || break
                    sleep 0.1
                    echo 0 > "$led/brightness" 2>/dev/null || break
                    sleep 0.1
                done &
            fi
        done

        # Also control keyboard LEDs if available
        # Caps lock blink
        if [ -w "/sys/class/leds/input3::capslock/brightness" ]; then
            echo "Making caps lock LED blink fast..."
            while true; do
                echo 1 > /sys/class/leds/input3::capslock/brightness 2>/dev/null || break
                sleep 0.05
                echo 0 > /sys/class/leds/input3::capslock/brightness 2>/dev/null || break
                sleep 0.05
            done &
        fi

        # Num lock blink
        if [ -w "/sys/class/leds/input3::numlock/brightness" ]; then
            echo "Making num lock LED blink fast..."
            while true; do
                echo 1 > /sys/class/leds/input3::numlock/brightness 2>/dev/null || break
                sleep 0.08
                echo 0 > /sys/class/leds/input3::numlock/brightness 2>/dev/null || break
                sleep 0.08
            done &
        fi

        # Scroll lock blink
        if [ -w "/sys/class/leds/input3::scrolllock/brightness" ]; then
            echo "Making scroll lock LED blink fast..."
            while true; do
                echo 1 > /sys/class/leds/input3::scrolllock/brightness 2>/dev/null || break
                sleep 0.06
                echo 0 > /sys/class/leds/input3::scrolllock/brightness 2>/dev/null || break
                sleep 0.06
            done &
        fi

        # Keep power LED on if available
        if [ -w "/sys/class/leds/power/brightness" ]; then
            echo "Keeping power LED on..."
            echo 1 > /sys/class/leds/power/brightness
        fi

    ) &

    # Store the PID for later cleanup
    echo $! > /tmp/led_control.pid
}

# Function to stop LED control
stop_leds() {
    echo "Stopping LED control..."

    # Kill LED control process
    if [ -f /tmp/led_control.pid ]; then
        kill $(cat /tmp/led_control.pid) 2>/dev/null || true
        rm -f /tmp/led_control.pid
    fi
    pkill -f "led_blink\|led_control" 2>/dev/null || true

    # Turn off all LEDs
    led_devices=$(find /sys/class/leds -name "*" -type d 2>/dev/null | grep -v "device" | head -20)
    echo "$led_devices" | while read led; do
        if [ -w "$led/brightness" ]; then
            echo 0 > "$led/brightness" 2>/dev/null || true
        fi
    done

    # Turn off keyboard LEDs
    for led in input3::capslock input3::numlock input3::scrolllock; do
        if [ -w "/sys/class/leds/$led/brightness" ]; then
            echo 0 > "/sys/class/leds/$led/brightness" 2>/dev/null || true
        fi
    done
}

# Main monitoring loop
echo "Starting CH340 monitoring loop..."
echo "$(date): Monitoring for CH340 devices..."

# Track connection state
device_connected=false

# Monitor for CH340 devices
while true; do
    if lsusb | grep -q "1a86:7523"; then
        if [ "$device_connected" = false ]; then
            echo "CH340 newly detected!"
            device_connected=true
            launch_pictures
            sleep 1
            launch_terminals
            sleep 5
        fi
    else
        if [ "$device_connected" = true ]; then
            echo "CH340 disconnected"
            device_connected=false
            # Unblock keyboard when device is disconnected
            unblock_keyboard
            # Stop LED control sequence
            stop_leds
            pkill -f feh 2>/dev/null || true
            stop_terminals
        fi
    fi
    sleep 2
done
