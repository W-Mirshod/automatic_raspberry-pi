#!/bin/bash

# CH340 Multi-Display Picture Script
# This script opens a picture in fullscreen on ALL connected displays when CH340 connects

# Log the connection
echo "$(date): CH340 connected! Launching multi-display picture..." >> /tmp/ch340-multi-display.log

# Set the picture path (change this to your desired image)
PICTURE_PATH="/home/w/Projects/automatic_raspberry-pi/ch340-welcome.jpg"

# Check if picture exists, if not create a simple one
if [ ! -f "$PICTURE_PATH" ]; then
    echo "Creating default welcome image..."
    # Create a simple colored image using ImageMagick
    magick -size 1920x1080 xc:"#1a86" -pointsize 72 -fill white -gravity center -annotate +0+0 "CH340 CONNECTED!\nMulti-Display Active" "$PICTURE_PATH"
fi

# Get all connected displays
DISPLAYS=$(xrandr --query | grep " connected" | awk '{print $1}')

# Launch 3 gwenview instances and position them using xdotool
echo "Launching image viewers on all displays..."

# Launch gwenview instances for each display
gwenview --fullscreen "$PICTURE_PATH" &
sleep 2
gwenview --fullscreen "$PICTURE_PATH" &
sleep 2  
gwenview --fullscreen "$PICTURE_PATH" &
sleep 2

echo "Launched 3 gwenview instances, attempting to position them..."

# Try to position the windows using xdotool
# Get all windows and try to move them
all_windows=$(xdotool search --onlyvisible --class "gwenview" 2>/dev/null)
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

# Optional: Add a sound effect (if you have a sound file)
# paplay /usr/share/sounds/gnome/default/alerts/drip.ogg 2>/dev/null || true

echo "Multi-display picture launched on all screens!"
echo "$(date): Script completed successfully" >> /tmp/ch340-multi-display.log
