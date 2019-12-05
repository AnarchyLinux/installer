#!/usr/bin/env bash
# Checks if user is connected to the internet

# Install netcat if it is not already installed
if [[ ! $(pacman -Qi nc) ]]; then
    pacman -Sy nc
fi

# Use netcat (nc) to check if we can connect to 1.1.1.1 on port 443
if nc -zw1 1.0.0.1 443; then
    exit 0
else
    exit 1
fi