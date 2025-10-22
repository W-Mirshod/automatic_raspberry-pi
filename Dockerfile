FROM ubuntu:22.04

# Install required packages (lightweight alternatives)
RUN apt-get update && apt-get install -y \
    feh \
    imagemagick \
    xdotool \
    x11-apps \
    x11-xserver-utils \
    wmctrl \
    procps \
    usbutils \
    udev \
    xinput \
    xtrlock \
    x11-xkb-utils \
    && rm -rf /var/lib/apt/lists/*

# Create app directory
WORKDIR /app

# Copy the script and image
COPY ch340-multi-display.sh /app/
COPY ch340-welcome.jpg /app/

# Make script executable
RUN chmod +x /app/ch340-multi-display.sh

# Set up X11 forwarding
ENV DISPLAY=:0

# Start the monitoring script
CMD ["/app/ch340-multi-display.sh"]
