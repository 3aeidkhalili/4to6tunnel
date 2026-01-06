#!/bin/bash

# Clear the screen
echo -e "\033c"

# Display the banner
echo -e "\e[1;32m
 ____  ____  ____  ____  _  ____  ____  _     
/  _ \/  _ \/ ___\/ ___\/ \/  __\/  _ \/ \  /|
| / \|| / \||    \|    \| ||  \/|| / \|| |\ ||
| |-||| |-||\___ |\___ || ||    /| |-||| | \||
\_/ \|\_/ \|\____/\____/\_/\_/\_\\_/ \|\_/  \|

TeleGram ID : @s3aeidkhalili

\e[0m"

# Paths and files configuration
WG_CONFIG_PATH="/etc/wireguard/wg0.conf"
CLIENTS_DIR="/etc/wireguard/clients/"
USER_DATA_FILE="/etc/wireguard/user_data.txt"
QR_CODES_DIR="/etc/wireguard/qr_codes/"

# Port configuration
PORT=443  # Default port for WireGuard

# Function to generate WireGuard keys
generate_keys() {
    private_key=$(wg genkey)
    public_key=$(echo "$private_key" | wg pubkey)
    echo "$private_key,$public_key"
}

# Function to get server's public key from WireGuard config file
get_server_public_key() {
    public_key=$(awk '/^PublicKey/{print $3}' "$WG_CONFIG_PATH")
    echo "$public_key"
}

# Function to find the next available IP address
get_next_ip_address() {
    existing_ips=()
    if [[ -f "$USER_DATA_FILE" ]]; then
        while IFS=, read -r username ip_address _ _ _; do
            existing_ips+=("$ip_address")
        done < "$USER_DATA_FILE"
    fi

    if [[ ${#existing_ips[@]} -gt 0 ]]; then
        last_ip="${existing_ips[-1]}"
        IFS='.' read -r -a ip_parts <<< "$last_ip"
        next_ip="${ip_parts[0]}.${ip_parts[1]}.${ip_parts[2]}.$((${ip_parts[3]} + 1))"
        echo "$next_ip"
    else
        echo "10.0.0.3"
    fi
}

# Function to add a user to WireGuard config file
add_user_to_config() {
    local username=$1
    local private_key=$2
    local public_key=$3
    local ip_address=$4

    cat <<EOF >> "$WG_CONFIG_PATH"
[Peer]
# $username
PublicKey = $public_key
AllowedIPs = $ip_address/32
EOF

    cat <<EOF > "$CLIENTS_DIR/${username}_wg0.conf"
[Interface]
PrivateKey = $private_key
Address = $ip_address/24
DNS = 8.8.8.8

[Peer]
PublicKey = $(get_server_public_key)
Endpoint = $server_ip:$PORT
AllowedIPs = 0.0.0.0/0
EOF
}

# Function to generate QR code and save it to user's directory
generate_qr_code() {
    local client_config="$1"
    local username="$2"
    local qr_directory="$QR_CODES_DIR/$username"

    mkdir -p "$qr_directory"

    qrencode -o "$qr_directory/${username}_qr.png" -l L < "$client_config"

    echo "QR code for $username saved: $qr_directory/${username}_qr.png"

    # Displaying the QR code using feh
    feh "$qr_directory/${username}_qr.png" &
}

# Function to restart WireGuard service
restart_wireguard() {
    sudo wg-quick down wg0
    sudo wg-quick up wg0
}

# Function to save user data to a file
save_user_data() {
    local username=$1
    local ip_address=$2
    local expiration_date=$3
    local data_limit=$4
    local data_used=$5
    echo "$username,$ip_address,$expiration_date,$data_limit,$data_used" >> "$USER_DATA_FILE"
}

# Function to list all users
list_users() {
    echo -e "\e[32mUsername | IP Address | Expiration Date | Data Limit | Data Used\e[0m"
    echo -e "\e[32m--------------------------------------------------------------\e[0m"
    if [[ -f "$USER_DATA_FILE" ]]; then
        while IFS=, read -r username ip_address expiration_date data_limit data_used; do
            echo -e "\e[32m$username | $ip_address | $expiration_date | $data_limit | $data_used\e[0m"
        done < "$USER_DATA_FILE"
    else
        echo -e "\e[32mNo users found.\e[0m"
    fi
}

# Function to create a new user
create_new_user() {
    local username=$1
    local expiration_days=$2
    local data_limit=$3

    ip_address=$(get_next_ip_address)
    keys=$(generate_keys)
    private_key=$(echo "$keys" | cut -d',' -f1)
    public_key=$(echo "$keys" | cut -d',' -f2)

    add_user_to_config "$username" "$private_key" "$public_key" "$ip_address"
    restart_wireguard

    expiration_date=$(date -d "+$expiration_days days" +%Y-%m-%d)
    save_user_data "$username" "$ip_address" "$expiration_date" "$data_limit" "0"

    echo -e "\e[32mUser $username added successfully!\e[0m"
    generate_qr_code "$CLIENTS_DIR/${username}_wg0.conf" "$username"
}

# Function to interactively ask for the Iran WireGuard server IP address and port
ask_for_server_ip_and_port() {
    read -p $'\e[32mEnter your Iran WireGuard server IP address: \e[0m' server_ip
    read -p $'\e[32mEnter the port for the WireGuard server (default is 51820): \e[0m' PORT
}

# Function to check and set up prerequisites
setup_prerequisites() {
    # Example: Install required packages for WireGuard
    sudo apt update
    sudo apt install -y qrencode feh wireguard-tools
}

# Check if prerequisites and server IP are set
if [[ ! -f "$USER_DATA_FILE" || -z "$server_ip" ]]; then
    echo -e "\e[32mSetting up prerequisites or server IP is required...\e[0m"
    setup_prerequisites
    ask_for_server_ip_and_port
fi

# Ping the Iran server
ping_result=$(ping -c 4 "$server_ip" 2>&1)
if [[ $? -eq 0 ]]; then
    echo -e "\e[32mPing to server in Iran successful.\e[0m"
    while true; do
        echo -e "\e[32mWireGuard User Management\e[0m"
        echo -e "\e[32m1. Add New User\e[0m"
        echo -e "\e[32m2. List Users\e[0m"
        echo -e "\e[32m3. Show QR Code for User\e[0m"
        echo -e "\e[32m4. Exit\e[0m"

        read -p $'\e[32mEnter your choice: \e[0m' choice
        case $choice in
            1)
                read -p $'\e[32mEnter the username for the new WireGuard client: \e[0m' username
                read -p $'\e[32mEnter the number of days until the user\'s account expires: \e[0m' expiration_days
                read -p $'\e[32mEnter the data limit for the user (e.g., 10GB): \e[0m' data_limit
                create_new_user "$username" "$expiration_days" "$data_limit"
                ;;
            2)
                list_users
                ;;
            3)
                read -p $'\e[32mEnter the username to display QR code: \e[0m' username
                qr_file="$QR_CODES_DIR/$username/${username}_qr.png"
                if [[ -f "$qr_file" ]]; then
                    echo -e "\e[32mDisplaying QR code for $username...\e[0m"
                    feh "$qr_file" &
                else
                    echo -e "\e[32mQR code for $username not found.\e[0m"
                fi
                ;;
            4)
                break
                ;;
            *)
                echo -e "\e[32mInvalid choice. Please try again.\e[0m"
                ;;
        esac
    done
else
    echo -e "\e[32mPing to server in Iran failed. Please check the connection and server IP.\e[0m"
fi
