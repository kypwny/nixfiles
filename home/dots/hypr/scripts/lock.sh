#!/bin/sh

# Number of seconds before screen turns off
timeout=30

# Turn screen off after $timeout seconds of inactivity.
# Turn it on again when there is activity.
#
# swayidle acts like a daemon, meaning it continues execution even after
# the script is terminated, so we need to execute it in the background
# to be able to terminate it later (unless you like your screen turning
# off every 10 seconds for some reason?)
swayidle \
    timeout $timeout 'hyprctl dispatch dpms off' \
    resume           'hyprctl dispatch dpms on' \
    &

# Lock the screen and wait for it to be unlocked.
hyprlock

# Screen unlocked: terminate swayidle and clean up PID
kill -TERM $!
wait
