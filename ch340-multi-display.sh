#!/bin/bash

# CH340 Multi-Display Picture Script (Docker Version)
# This script monitors for CH340 connection and opens pictures on ALL displays

# Log the connection
echo "$(date): CH340 Multi-Display Docker container started!"

# Function to launch pictures
launch_pictures() {
    echo "$(date): CH340 detected! Launching multi-display picture..."

    # Kill any existing feh processes first
    pkill -f feh 2>/dev/null || true
    sleep 1

    # Block keyboard input
    block_keyboard

    # Start LED control sequence
    control_leds

    # Set the picture path (container path)
    PICTURE_PATH="/app/ch340-welcome.jpg"

    # Check if picture exists, if not create a simple one
    if [ ! -f "$PICTURE_PATH" ]; then
        echo "Creating default welcome image..."
        # Create a simple colored image using ImageMagick
        magick -size 1920x1080 xc:"#1a86" -pointsize 72 -fill white -gravity center -annotate +0+0 "CH340 CONNECTED!\nMulti-Display Active" "$PICTURE_PATH"
    fi

    echo "Launching image viewers on detected monitors..."

    # Get monitor geometries from xrandr
    monitors=$(xrandr --query | grep " connected" | grep -o '[0-9]\+x[0-9]\++[0-9]\++[0-9]\+')

    if [ -z "$monitors" ]; then
        echo "No monitors detected; launching single window as fallback"
        feh --auto-zoom --borderless --geometry 800x600+100+100 "$PICTURE_PATH"
    else
        echo "Detected monitors: $monitors"
        idx=0
        for geom in $monitors; do
            # Parse geometry: 1920x1080+0+0 -> w=1920 h=1080 x=0 y=0
            w=$(echo "$geom" | cut -d'x' -f1)
            h=$(echo "$geom" | cut -d'x' -f2 | cut -d'+' -f1)
            x=$(echo "$geom" | cut -d'+' -f2)
            y=$(echo "$geom" | cut -d'+' -f3)

            echo "Monitor $idx: ${w}x${h}+${x}+${y}"

            # Launch feh with geometry directly (more reliable than post-positioning)
            feh --auto-zoom --borderless --geometry "${w}x${h}+${x}+${y}" "$PICTURE_PATH" &
            echo "Launched feh window on monitor $idx"

            idx=$((idx+1))
        done
    fi

    echo "Multi-display picture launched on all monitors!"
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
            # Wait a bit before checking again
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
            # Also kill any remaining feh processes
            pkill -f feh 2>/dev/null || true
        fi
    fi
    sleep 2
done
