#!/bin/bash

# Swap Primary Display Script for KDE Plasma (Wayland)
# Assumes exactly two monitors are connected

# Strip ANSI codes and get output information
kscreen_output=$(kscreen-doctor -o | sed 's/\x1b\[[0-9;]*m//g')

# Get list of output names (e.g., HDMI-A-2, DP-3)
readarray -t outputs < <(echo "$kscreen_output" | grep "Output:" | awk '{print $3}')

# Check if we have exactly 2 monitors
if [ ${#outputs[@]} -ne 2 ]; then
    echo "Error: Expected 2 monitors, found ${#outputs[@]}"
    exit 1
fi

# Find which output currently has priority 1
current_primary=""
for output in "${outputs[@]}"; do
    # Check if this output has priority 1
    if echo "$kscreen_output" | grep -A20 "Output:.*$output" | grep -q "priority 1"; then
        current_primary="$output"
        break
    fi
done

if [ -z "$current_primary" ]; then
    # No primary set, make first output primary
    echo "No primary display detected. Setting ${outputs[0]} as primary."
    kscreen-doctor output.${outputs[0]}.priority.1 output.${outputs[1]}.priority.2
else
    # Swap primary to the other monitor
    if [ "$current_primary" = "${outputs[0]}" ]; then
        echo "Swapping primary from ${outputs[0]} to ${outputs[1]}"
        kscreen-doctor output.${outputs[1]}.priority.1 output.${outputs[0]}.priority.2
    else
        echo "Swapping primary from ${outputs[1]} to ${outputs[0]}"
        kscreen-doctor output.${outputs[0]}.priority.1 output.${outputs[1]}.priority.2
    fi
fi

echo "Primary display swap complete!"
