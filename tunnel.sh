#!/bin/bash

# Clear the screen
clear

# Display a banner
echo -e "\e[1;32m
 ____  ____  ____  ____  _  ____  ____  _     
/  _ \/  _ \/ ___\/ ___\/ \/  __\/  _ \/ \  /|
| / \|| / \||    \|    \| ||  \/|| / \|| |\ ||
| |-||| |-||\___ |\___ || ||    /| |-||| | \||
\_/ \|\_/ \|\____/\____/\_/\_/\_\\_/ \|\_/  \|

TeleGram ID : @s3aeidkhalili

\e[0m"

# Get network interface name from the user
read -p "Please enter the network interface name (e.g., eth0, ens33): " network_device

# Get remote and local IP addresses from the user
read -p "Please enter the local IP address: " local_ip
read -p "Please enter the remote IP address: " remote_ip
read -p "Please enter the IPv6 address to add to the device (example: 2a14:f080::1): " ipv6_addr

# Validate IP addresses (improved validation)
if [[ ! $local_ip =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
  echo "Invalid local IP address format."
  exit 1
fi

if [[ ! $remote_ip =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
  echo "Invalid remote IP address format."
  exit 1
fi

if [[ ! $ipv6_addr =~ ^[0-9a-fA-F:]+$ ]]; then
  echo "Invalid IPv6 address format."
  exit 1
fi

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

# Increase buffer limits
echo "Setting buffer limits..."
sysctl -w net.ipv4.ipfrag_high_thresh=262144
sysctl -w net.ipv4.ipfrag_low_thresh=196608
sysctl -w net.ipv4.ipfrag_max_dist=64

# Remove existing tunnel if exists
echo "Removing existing tunnel $network_device if exists..."
ip link set $network_device down 2>/dev/null
ip tunnel del $network_device 2>/dev/null

# Create tunnel using ip tunnel add
echo "Creating new tunnel $network_device..."
ip tunnel add $network_device mode sit remote $remote_ip local $local_ip ttl 126
if [ $? -ne 0 ]; then
  echo "Failed to create tunnel."
  exit 1
fi

# Set mtu for tunnel
echo "Setting MTU to 1480 for $network_device..."
ip link set $network_device mtu 1480
if [ $? -ne 0 ]; then
  echo "Warning: Failed to set MTU. Continuing..."
fi

# Activate network device
echo "Activating network device $network_device..."
ip link set dev $network_device up
if [ $? -ne 0 ]; then
  echo "Failed to activate network device."
  exit 1
fi

# Add IPv6 address to network device
echo "Adding IPv6 address $ipv6_addr/64 to $network_device..."
ip addr add $ipv6_addr/64 dev $network_device
if [ $? -ne 0 ]; then
  echo "Failed to add IPv6 address."
  exit 1
fi

# Create rc.local if it doesn't exist
if [ ! -f /etc/rc.local ]; then
  echo "Creating /etc/rc.local..."
  echo '#!/bin/bash' > /etc/rc.local
  echo '' >> /etc/rc.local
fi

# Check if configuration already exists in rc.local
if grep -q "ip tunnel add $network_device" /etc/rc.local; then
  echo "Configuration for $network_device already exists in /etc/rc.local"
  read -p "Do you want to replace it? (y/n): " replace
  if [[ $replace == "y" || $replace == "Y" ]]; then
    # Remove existing configuration
    sed -i "/# IP configuration for network tunnel setup $network_device/,/sudo ip link set $network_device up/d" /etc/rc.local
  else
    echo "Skipping rc.local update."
    echo "Script executed successfully."
    exit 0
  fi
fi

# Prepare the new configuration
new_config="
# IP configuration for network tunnel setup $network_device
ip tunnel add $network_device mode sit remote $remote_ip local $local_ip ttl 126
ip link set $network_device mtu 1480
ip link set dev $network_device up
ip addr add $ipv6_addr/64 dev $network_device
"

# Insert before the exit 0 line if it exists, otherwise append to the end
if grep -q "exit 0" /etc/rc.local; then
  sed -i "/exit 0/i\\$new_config" /etc/rc.local
else
  echo "$new_config" >> /etc/rc.local
  echo "exit 0" >> /etc/rc.local
fi

# Make /etc/rc.local executable
chmod +x /etc/rc.local

echo "========================================"
echo "Script executed successfully!"
echo "Tunnel configuration saved to /etc/rc.local"
echo "Interface: $network_device"
echo "Local IP: $local_ip"
echo "Remote IP: $remote_ip"
echo "IPv6 Address: $ipv6_addr/64"
echo "========================================"

# Show current configuration
echo ""
echo "Current tunnel status:"
ip -6 addr show dev $network_device
echo ""
ip link show $network_device
