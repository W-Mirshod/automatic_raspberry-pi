#!/bin/bash

# CH340 Multi-Display Picture Script (Docker Version)
# This script monitors for CH340 connection and opens pictures on ALL displays

# Log the connection
echo "$(date): CH340 Multi-Display Docker container started!" >> /tmp/ch340-multi-display.log

# Function to launch pictures
launch_pictures() {
    echo "$(date): CH340 detected! Launching multi-display picture..." >> /tmp/ch340-multi-display.log

    # Set the picture path (container path)
    PICTURE_PATH="/app/ch340-welcome.jpg"

    # Check if picture exists, if not create a simple one
    if [ ! -f "$PICTURE_PATH" ]; then
        echo "Creating default welcome image..."
        # Create a simple colored image using ImageMagick
        magick -size 1920x1080 xc:"#1a86" -pointsize 72 -fill white -gravity center -annotate +0+0 "CH340 CONNECTED!\nMulti-Display Active" "$PICTURE_PATH"
    fi

    # Launch 3 feh instances for multi-display
    echo "Launching image viewers on all displays..."

    # Launch feh instances for each display (feh fullscreen mode)
    feh --fullscreen --auto-zoom --geometry 1920x1080+0+0 "$PICTURE_PATH" &
    sleep 2
    feh --fullscreen --auto-zoom --geometry 1920x1080+1920+0 "$PICTURE_PATH" &
    sleep 2
    feh --fullscreen --auto-zoom --geometry 1920x1080+3840+0 "$PICTURE_PATH" &
    sleep 2

    echo "Launched 3 feh instances on multi-display setup..."

    # Try to position the windows using xdotool (feh windows)
    all_windows=$(xdotool search --onlyvisible --class "feh" 2>/dev/null)
    if [ ! -z "$all_windows" ]; then
        offset=0
        for window in $all_windows; do
            xdotool windowmove $window $offset 0
            xdotool windowsize $window 1920 1080
            echo "Positioned window $window at offset $offset"
            offset=$((offset + 1920))
        done
    else
        echo "Could not find gwenview windows to position automatically"
        echo "You may need to manually move the windows to each display"
    fi

    echo "Multi-display picture launched on all screens!"
    echo "$(date): Pictures launched successfully" >> /tmp/ch340-multi-display.log
}

# Main monitoring loop
echo "Starting CH340 monitoring loop..."
echo "$(date): Monitoring for CH340 devices..." >> /tmp/ch340-multi-display.log

# Monitor for CH340 devices
while true; do
    if lsusb | grep -q "1a86:7523"; then
        echo "CH340 detected!"
        launch_pictures
        # Wait a bit to prevent multiple triggers
        sleep 10
    fi
    sleep 2
done
