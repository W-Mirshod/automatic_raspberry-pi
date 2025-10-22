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
    echo "Blocking keyboard input with screen lock..."
    # Use xtrlock to lock the screen (blocks all keyboard input)
    xtrlock &
    # Store the PID for later killing
    echo $! > /tmp/xtrlock.pid
}

unblock_keyboard() {
    echo "Unblocking keyboard input..."
    # Kill the xtrlock process to unlock
    if [ -f /tmp/xtrlock.pid ]; then
        kill $(cat /tmp/xtrlock.pid) 2>/dev/null || true
        rm -f /tmp/xtrlock.pid
    fi
    # Also kill any remaining xtrlock processes just in case
    pkill -f xtrlock 2>/dev/null || true
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
            # Also kill any remaining feh processes
            pkill -f feh 2>/dev/null || true
        fi
    fi
    sleep 2
done
