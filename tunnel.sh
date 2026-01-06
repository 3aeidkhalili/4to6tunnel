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

# Validate IP addresses (basic validation)
if [[ ! $local_ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Invalid local IP address format."
  exit 1
fi

if [[ ! $remote_ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Invalid remote IP address format."
  exit 1
fi

if [[ ! $ipv6_addr =~ ^[0-9a-fA-F:]+$ ]]; then
  echo "Invalid IPv6 address format."
  exit 1
fi

# Increase buffer limits
echo "Setting buffer limits..."
sudo sysctl -w net.ipv4.ipfrag_high_thresh=262144
sudo sysctl -w net.ipv4.ipfrag_low_thresh=196608
sudo sysctl -w net.ipv4.ipfrag_max_dist=64

# Remove existing tunnel if exists
echo "Removing existing tunnel $network_device if exists..."
sudo ip link set $network_device down 2>/dev/null
sudo ip tunnel del $network_device 2>/dev/null

# Create tunnel using ip tunnel add
echo "Creating new tunnel $network_device..."
sudo ip tunnel add $network_device mode sit remote $remote_ip local $local_ip ttl 126
if [ $? -ne 0 ]; then
  echo "Failed to create tunnel."
  exit 1
fi

# Activate network device using ip link set
echo "Activating network device $network_device..."
sudo ip link set dev $network_device up mtu 1500
if [ $? -ne 0 ]; then
  echo "Failed to activate network device."
  exit 1
fi

# Add IPv6 address to network device using ip addr add
echo "Adding IPv6 address $ipv6_addr/64 to $network_device..."
sudo ip addr add $ipv6_addr/64 dev $network_device
if [ $? -ne 0 ]; then
  echo "Failed to add IPv6 address."
  exit 1
fi

# Set mtu for network device using ip link set
echo "Setting MTU to 1436 for $network_device..."
sudo ip link set $network_device mtu 1436
if [ $? -ne 0 ]; then
  echo "Failed to set MTU."
  exit 1
fi

# Prepare the new configuration to be inserted into /etc/rc.local
new_config="
# IP configuration for network tunnel setup $network_device
sudo ip tunnel add $network_device mode sit remote $remote_ip local $local_ip ttl 126
sudo ip link set dev $network_device up mtu 1500
sudo ip addr add $ipv6_addr/64 dev $network_device
sudo ip link set $network_device mtu 1500
sudo ip link set $network_device up
"

# Insert the new configuration into /etc/rc.local before the exit 0
echo -e "$new_config" | sudo tee -a /etc/rc.local >/dev/null
if [ $? -ne 0 ]; then
  echo "Failed to update /etc/rc.local."
  exit 1
fi

# Make /etc/rc.local executable
sudo chmod +x /etc/rc.local
if [ $? -ne 0 ]; then
  echo "Failed to make /etc/rc.local executable."
  exit 1
fi

echo "Script executed successfully and configuration saved to /etc/rc.local."
