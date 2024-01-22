#!/bin/bash

hosts_file="hosts"
etc_hosts_file="/etc/hosts"

# Check if the hosts file exists
if [ -f "$hosts_file" ]; then
    # Append the contents of hosts file to /etc/hosts
    cat "$hosts_file" >> "$etc_hosts_file"
    echo "Contents of $hosts_file appended to $etc_hosts_file"
else
    echo "Error: $hosts_file not found."
fi
