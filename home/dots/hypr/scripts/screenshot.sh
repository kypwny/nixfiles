#!/bin/bash

# Disable animations
hyprctl keyword animations:enabled 0

# Take screenshot and open in swappy
grimblast save area - | swappy -f -

# Re-enable animations
hyprctl keyword animations:enabled 1
