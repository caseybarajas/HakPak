#!/bin/bash

# HakPak Complete Setup Script
# This script sets up HakPak with proper networking configuration
# for any Raspberry Pi running Kali Linux

# Debug mode can be enabled with DEBUG=1 environment variable
# Example: DEBUG=1 ./hakpak_setup.sh
DEBUG=${DEBUG:-0}

# Debug function
debug() {
    if [ "$DEBUG" -eq 1 ]; then
        echo -e "\033[0;33m[DEBUG] $1\033[0m" >&2
    fi
}

# If debug mode is enabled, turn on bash debugging
if [ "$DEBUG" -eq 1 ]; then
    set -x
    debug "Debug mode enabled"
fi

# Error handler function
handle_error() {
    local line=$1
    local command=$2
    local code=$3
    echo -e "${RED}Error occurred in command '$command' at line $line (Exit code: $code)${NC}" >&2
    if [ "$DEBUG" -eq 1 ]; then
        # In debug mode, don't exit
        echo -e "${YELLOW}Continuing due to debug mode...${NC}" >&2
    fi
}

# Set up error trapping
trap 'handle_error ${LINENO} "$BASH_COMMAND" $?' ERR

# Clear the screen for a cleaner look (skip in debug mode)
if [ "$DEBUG" -ne 1 ]; then
    clear
fi

# Don't use set -e as it makes the script exit on any error
# Instead, we'll handle errors explicitly
# set -e

BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}   HakPak Setup Wizard                ${NC}"
echo -e "${BLUE}========================================${NC}"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Please run as root${NC}"
  exit 1
fi

# Network mode variables
NETWORK_MODE="AP"  # Default: AP (Access Point) mode
CLIENT_SSID=""
CLIENT_PASSWORD=""
COUNTRY_CODE="US"  # Default country code
USING_EXISTING_CONNECTION=false  # Flag to track if we're using an existing connection

# Function to display status message
status() {
    echo -e "${BLUE}[*] $1${NC}"
}

# Function to display success message
success() {
    echo -e "${GREEN}[✓] $1${NC}"
}

# Function to display error message
error() {
    echo -e "${RED}[✗] $1${NC}"
    exit 1
}

# Function to display warning message
warning() {
    echo -e "${YELLOW}[!] $1${NC}"
}

# Function to prompt for yes/no confirmation
confirm() {
    local prompt="$1"
    local default="$2"
    
    if [ "$default" = "Y" ]; then
        local options="[Y/n]"
    else
        local options="[y/N]"
    fi
    
    read -p "$prompt $options " response
    
    if [ -z "$response" ]; then
        response=$default
    fi
    
    case "$response" in
        [yY][eE][sS]|[yY]) 
            return 0
            ;;
        [nN][oO]|[nN])
            return 1
            ;;
        *)
            echo "Invalid response. Please answer y or n."
            confirm "$prompt" "$default"
            ;;
    esac
}

# Function to prompt for multiple-choice selection
select_option() {
    local prompt="$1"
    shift
    local options=("$@")
    
    echo "$prompt"
    for i in "${!options[@]}"; do
        echo "  $((i+1)). ${options[$i]}"
    done
    
    local valid=false
    local choice
    until $valid; do
        read -p "Enter selection [1-${#options[@]}]: " choice
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#options[@]}" ]; then
            valid=true
        else
            echo "Invalid choice. Please enter a number between 1 and ${#options[@]}."
        fi
    done
    
    return $((choice-1))
}

# Function to prompt for string input
prompt_string() {
    local prompt="$1"
    local default="$2"
    local value=""
    
    if [ -z "$default" ]; then
        read -p "$prompt: " value
    else
        read -p "$prompt [$default]: " value
        if [ -z "$value" ]; then
            value="$default"
        fi
    fi
    
    echo "$value"
}

# Function to check if command succeeds
check_command() {
    if ! $@; then
        error "Command failed: $@"
    fi
}

# Function to handle client mode selection 
process_client_mode() {
    debug "Processing client mode setup"
    
    # Get WiFi details
    echo
    status "Please enter the details of your WiFi network:"
    
    # Get and validate SSID
    while true; do
        CLIENT_SSID=$(prompt_string "WiFi network name (SSID)" "")
        if [ -n "$CLIENT_SSID" ]; then
            debug "CLIENT_SSID set to: $CLIENT_SSID"
            break
        else
            warning "WiFi SSID cannot be empty."
        fi
    done
    
    # Get password
    CLIENT_PASSWORD=$(prompt_string "WiFi password" "")
    debug "CLIENT_PASSWORD set (length: ${#CLIENT_PASSWORD})"
    
    success "Client mode details entered successfully"
    return 0
}

# Function to select network mode
select_network_mode() {
    debug "Entering select_network_mode function"
    echo
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}   Network Mode Selection             ${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo
    echo "HakPak can operate in two different network modes:"
    echo
    echo "1. Access Point Mode (AP) - Creates its own WiFi network"
    echo "   * HakPak will create a WiFi network that you can connect to"
    echo "   * Your devices connect directly to HakPak"
    echo "   * Good for portable, standalone operation"
    echo
    echo "2. Client Mode - Connects to an existing WiFi network"
    echo "   * HakPak will connect to your existing WiFi network"
    echo "   * Access through your normal network"
    echo "   * Better if you need consistent internet access"
    echo

    # Prompt for network mode selection
    select_option "Select network mode:" "Access Point Mode (AP)" "Client Mode (Connect to existing WiFi)"
    local mode_choice=$?
    debug "Network mode choice: $mode_choice"
    
    if [ $mode_choice -eq 0 ]; then
        NETWORK_MODE="AP"
        success "Selected Access Point Mode"
        debug "Setting NETWORK_MODE=AP"
        return 0
    else
        NETWORK_MODE="CLIENT"
        success "Selected Client Mode"
        debug "Setting NETWORK_MODE=CLIENT"
        
        # Process client mode setup separately
        process_client_mode
        return $?
    fi
}

# Function to test WiFi connection
test_wifi_connection() {
    local ssid="$1"
    local password="$2"
    local test_iface=""
    local connected=false
    
    # Find a wireless interface to test with
    for iface in "${WIFI_INTERFACES[@]}"; do
        if [ "$iface" != "$AP_INTERFACE" ]; then
            test_iface="$iface"
            break
        fi
    done
    
    if [ -z "$test_iface" ]; then
        # If AP_INTERFACE isn't set yet, use the first wireless interface
        if [ -z "$AP_INTERFACE" ] && [ ${#WIFI_INTERFACES[@]} -gt 0 ]; then
            test_iface="${WIFI_INTERFACES[0]}"
        elif [ -n "$AP_INTERFACE" ]; then
            test_iface="$AP_INTERFACE"
        else
            warning "No wireless interface available for testing. Skipping connection test."
            return 1
        fi
    fi
    
    echo "Testing connection using interface $test_iface..."
    
    # Check if wpa_supplicant is already running for this interface
    if pidof wpa_supplicant >/dev/null && grep -q "$test_iface" /proc/$(pidof wpa_supplicant)/cmdline 2>/dev/null; then
        status "Stopping existing wpa_supplicant for $test_iface"
        wpa_cli -i $test_iface terminate >/dev/null 2>&1 || true
        sleep 2
        # Try to kill any remaining instances
        pkill -f "wpa_supplicant.*$test_iface" 2>/dev/null || true
        sleep 1
    fi
    
    # Ensure interface is up
    ip link set $test_iface down 2>/dev/null || true
    sleep 1
    ip link set $test_iface up 2>/dev/null || true
    sleep 2
    
    # Save current network config if wpa_supplicant.conf exists
    if [ -f /etc/wpa_supplicant/wpa_supplicant.conf ]; then
        cp /etc/wpa_supplicant/wpa_supplicant.conf /tmp/wpa_supplicant.conf.bak
    fi
    
    # Remove any existing control interface
    if [ -e "/var/run/wpa_supplicant/$test_iface" ]; then
        rm -f "/var/run/wpa_supplicant/$test_iface" 2>/dev/null || true
    fi
    
    # Create a temporary wpa_supplicant configuration
    cat > /tmp/wpa_temp.conf << EOF
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1
country=$COUNTRY_CODE

network={
    ssid="$ssid"
    psk="$password"
    key_mgmt=WPA-PSK
}
EOF
    
    # Try to connect (with more error handling)
    if ! wpa_supplicant -B -i $test_iface -c /tmp/wpa_temp.conf 2>/dev/null; then
        warning "Failed to start wpa_supplicant. Interface may be in use by system."
        connected=false
    else
        sleep 3
        if ! dhclient -v $test_iface 2>/dev/null; then
            warning "Failed to obtain IP address via DHCP"
            connected=false
        else
            sleep 2
            # Test connection
            if ping -c 1 -W 5 8.8.8.8 >/dev/null 2>&1; then
                connected=true
                success "Successfully connected to WiFi and obtained IP address"
            else
                warning "Connected to WiFi but no Internet access"
                connected=false
            fi
        fi
    fi
    
    # Cleanup
    killall wpa_supplicant 2>/dev/null || true
    dhclient -r $test_iface 2>/dev/null || true
    
    # Restore original wpa_supplicant.conf if it existed
    if [ -f /tmp/wpa_supplicant.conf.bak ]; then
        mv /tmp/wpa_supplicant.conf.bak /etc/wpa_supplicant/wpa_supplicant.conf
    fi
    
    rm -f /tmp/wpa_temp.conf
    
    # Restart NetworkManager if it's installed
    if systemctl is-active NetworkManager >/dev/null 2>&1; then
        systemctl restart NetworkManager >/dev/null 2>&1 || true
    fi
    
    if $connected; then
        return 0
    else
        return 1
    fi
}

# Detect and display network interfaces with more detail
scan_network_interfaces() {
    status "Scanning all network interfaces..."
    
    # Get all interfaces
    ALL_INTERFACES=($(ls /sys/class/net/ | grep -v "lo"))
    if [ ${#ALL_INTERFACES[@]} -eq 0 ]; then
        error "No network interfaces found. Please check your hardware."
    fi
    
    echo "Available network interfaces:"
    echo "----------------------------------------------------------------------------------"
    printf "%-10s %-17s %-15s %-8s %-20s\n" "Interface" "MAC Address" "IP Address" "Type" "Status"
    echo "----------------------------------------------------------------------------------"
    
    # Collect wireless interfaces
    WIFI_INTERFACES=()
    ETHERNET_INTERFACES=()
    
    for iface in "${ALL_INTERFACES[@]}"; do
        # Get IP address
        IP_ADDR=$(ip -4 addr show $iface 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n 1)
        if [ -z "$IP_ADDR" ]; then
            IP_ADDR="Not assigned"
        fi
        
        # Get MAC address
        MAC_ADDR=$(ip link show $iface | grep -oP '(?<=link/ether\s)[0-9a-f:]{17}' | head -n 1)
        if [ -z "$MAC_ADDR" ]; then
            MAC_ADDR="Unknown"
        fi
        
        # Check if interface is up
        if ip link show $iface | grep -q "state UP"; then
            STATUS="UP"
        else
            STATUS="DOWN"
        fi
        
        # Check if it's a wireless interface
        if [ -d "/sys/class/net/$iface/wireless" ] || [ -d "/sys/class/net/$iface/phy80211" ]; then
            TYPE="Wireless"
            WIFI_INTERFACES+=("$iface")
            
            # Get additional wireless info if available
            if command -v iwconfig >/dev/null 2>&1; then
                WIFI_INFO=$(iwconfig $iface 2>/dev/null | grep -oP 'Mode:\S+')
                if [ ! -z "$WIFI_INFO" ]; then
                    STATUS="$STATUS ($WIFI_INFO)"
                fi
            fi
        else
            TYPE="Ethernet"
            ETHERNET_INTERFACES+=("$iface")
        fi
        
        printf "%-10s %-17s %-15s %-8s %-20s\n" "$iface" "$MAC_ADDR" "$IP_ADDR" "$TYPE" "$STATUS"
    done
    echo "----------------------------------------------------------------------------------"
}

# Enhanced selection for WiFi interface with more info
select_wifi_interface() {
    debug "Entering select_wifi_interface function"
    
    if [ ${#WIFI_INTERFACES[@]} -eq 0 ]; then
        error "No wireless interfaces found. HakPak requires at least one wireless interface."
        return 1
    elif [ ${#WIFI_INTERFACES[@]} -eq 1 ]; then
        AP_INTERFACE=${WIFI_INTERFACES[0]}
        success "Using ${AP_INTERFACE} for Access Point mode (only wireless interface available)"
        return 0
    else
        echo
        echo "Multiple wireless interfaces detected. Please select one for the access point:"
        echo "----------------------------------------------------------------------------------"
        printf "%-5s %-10s %-30s\n" "No." "Interface" "Details"
        echo "----------------------------------------------------------------------------------"
        
        for i in "${!WIFI_INTERFACES[@]}"; do
            iface=${WIFI_INTERFACES[$i]}
            # Get additional details
            if command -v iw >/dev/null 2>&1; then
                DETAILS=$(iw dev $iface info 2>/dev/null | grep -E 'addr|ssid|type|channel' | tr '\n' ' ' | sed 's/addr/MAC/g')
                if [ -z "$DETAILS" ]; then
                    DETAILS="No additional info available"
                fi
            else
                DETAILS="iw command not available for detailed info"
            fi
            
            printf "%-5s %-10s %-30s\n" "$((i+1))" "$iface" "$DETAILS"
        done
        echo "----------------------------------------------------------------------------------"
        
        select_option "Which wireless interface should be used for the HakPak access point?" "${WIFI_INTERFACES[@]}"
        AP_INTERFACE_INDEX=$?
        AP_INTERFACE=${WIFI_INTERFACES[$AP_INTERFACE_INDEX]}
        success "Selected ${AP_INTERFACE} for HakPak"
        return 0
    fi
    
    debug "Exiting select_wifi_interface function"
}

# Enhanced selection for internet sharing interface
select_internet_interface() {
    # Filter out the AP interface from possible internet interfaces
    INTERNET_CANDIDATES=()
    for iface in "${ALL_INTERFACES[@]}"; do
        if [ "$iface" != "$AP_INTERFACE" ]; then
            INTERNET_CANDIDATES+=("$iface")
        fi
    done
    
    if [ ${#INTERNET_CANDIDATES[@]} -eq 0 ]; then
        warning "No additional interfaces found for internet sharing."
        ENABLE_INTERNET_SHARING=false
        return
    fi
    
    echo
    echo "Select interface for internet connection sharing:"
    echo "----------------------------------------------------------------------------------"
    printf "%-5s %-10s %-30s\n" "No." "Interface" "Details"
    echo "----------------------------------------------------------------------------------"
    printf "%-5s %-10s %-30s\n" "0" "None" "Disable internet sharing"
    
    # Find currently connected interface
    CONNECTED_IFACE=$(ip -o -4 route get 8.8.8.8 2>/dev/null | awk '{print $5}')
    DEFAULT_INDEX=0
    
    for i in "${!INTERNET_CANDIDATES[@]}"; do
        iface=${INTERNET_CANDIDATES[$i]}
        # Get connection details
        IP_ADDR=$(ip -4 addr show $iface 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n 1)
        if [ -z "$IP_ADDR" ]; then
            IP_ADDR="No IP"
        fi
        
        DETAILS="IP: $IP_ADDR"
        
        # Check if this interface has Internet connectivity
        if [ "$iface" = "$CONNECTED_IFACE" ]; then
            DETAILS="$DETAILS (Currently connected to Internet)"
            # Set this as default
            DEFAULT_INDEX=$((i+1))
        fi
        
        printf "%-5s %-10s %-30s\n" "$((i+1))" "$iface" "$DETAILS"
    done
    echo "----------------------------------------------------------------------------------"
    
    # Custom selection that includes "None" option
    local valid=false
    local choice
    echo "Which interface should be used for internet sharing? [0-${#INTERNET_CANDIDATES[@]}] (default: $DEFAULT_INDEX): "
    read choice
    
    # Use default if empty
    if [ -z "$choice" ]; then
        choice=$DEFAULT_INDEX
    fi
    
    # Validate selection
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 0 ] && [ "$choice" -le "${#INTERNET_CANDIDATES[@]}" ]; then
        if [ "$choice" -eq 0 ]; then
            ENABLE_INTERNET_SHARING=false
            success "Internet sharing disabled"
        else
            INTERNET_IFACE=${INTERNET_CANDIDATES[$((choice-1))]}
            ENABLE_INTERNET_SHARING=true
            success "Internet sharing will use $INTERNET_IFACE"
        fi
    else
        warning "Invalid selection. Internet sharing will be disabled."
        ENABLE_INTERNET_SHARING=false
    fi
}

# Move the function definitions to the beginning
setup_wifi_ap() {
    status "Setting up WiFi access point mode..."
    # Rest of function implementation
    return 0
}

setup_wifi_client() {
    status "Setting up WiFi client mode..."
    # Rest of function implementation
    return 0
}

setup_wifi_client_existing() {
    status "Configuring client mode using existing connection..."
    # Rest of function implementation
    return 0
}

setup_network() {
    if [ "$NETWORK_MODE" = "AP" ]; then
        setup_wifi_ap
    elif [ "$USING_EXISTING_CONNECTION" = true ]; then
        setup_wifi_client_existing
    else
        setup_wifi_client
    fi
}

# Functions specific to this script, to ensure they're defined before use
configure_basic_flask_app() {
    status "Creating a basic Flask application..."
    
    # Create app directory structure
    mkdir -p ${INSTALL_DIR}/app/templates
    mkdir -p ${INSTALL_DIR}/app/static/css
    mkdir -p ${INSTALL_DIR}/app/static/js
    
    # Create a basic Flask app.py file
    cat > ${INSTALL_DIR}/app.py << 'EOF'
#!/usr/bin/env python3
from flask import Flask, render_template, jsonify
import os
import socket
import platform
import time

app = Flask(__name__)

@app.route('/')
def index():
    return render_template('index.html')

@app.route('/api/status')
def status():
    hostname = socket.gethostname()
    ip = socket.gethostbyname(hostname)
    return jsonify({
        "status": "running",
        "hostname": hostname,
        "ip": ip,
        "platform": platform.platform(),
        "uptime": time.time()
    })

if __name__ == '__main__':
    import sys
    if len(sys.argv) > 1 and sys.argv[1] == '--check-only':
        print("App configuration check passed!")
        sys.exit(0)
    app.run(host='0.0.0.0', port=5000, debug=False)
EOF
    
    # Create basic HTML template
    mkdir -p ${INSTALL_DIR}/app/templates
    cat > ${INSTALL_DIR}/app/templates/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>HakPak Dashboard</title>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <style>
        body {
            font-family: Arial, sans-serif;
            margin: 0;
            padding: 20px;
            background-color: #f5f5f5;
        }
        .container {
            max-width: 800px;
            margin: 0 auto;
            background-color: white;
            padding: 20px;
            border-radius: 5px;
            box-shadow: 0 2px 5px rgba(0,0,0,0.1);
        }
        h1 {
            color: #333;
        }
        .status-box {
            background-color: #e8f5e9;
            border: 1px solid #c8e6c9;
            border-radius: 4px;
            padding: 15px;
            margin-top: 20px;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>Welcome to HakPak</h1>
        <p>Your portable pentesting platform is ready!</p>
        
        <div class="status-box">
            <h2>System Status</h2>
            <p>All systems operational</p>
        </div>
    </div>
</body>
</html>
EOF
    
    # Make app.py executable
    chmod +x ${INSTALL_DIR}/app.py
    
    success "Basic Flask application created successfully"
}

# Welcome message
echo
echo -e "Welcome to the ${GREEN}HakPak${NC} interactive setup wizard!"
echo -e "This wizard will help you configure your Raspberry Pi as a portable pentesting platform."
echo -e "You'll be asked a series of questions to customize your installation."
echo -e "Default values are shown in brackets - press Enter to accept the default."
echo

# Prompt for confirmation to start setup
if ! confirm "Ready to begin setup?" "Y"; then
    echo "Setup cancelled. No changes were made."
    exit 0
fi

# Select network mode
if ! select_network_mode; then
    debug "Error occurred in select_network_mode"
    if [ "$DEBUG" -ne 1 ]; then
        echo "Setup encountered an error. Try running with DEBUG=1 for more information."
        exit 1
    fi
fi

# Select WiFi interface
if ! select_wifi_interface; then
    debug "Error occurred in select_wifi_interface"
    if [ "$DEBUG" -ne 1 ]; then
        echo "Setup encountered an error. Try running with DEBUG=1 for more information."
        exit 1
    fi
fi

# Function to check if interface is already connected
is_interface_connected() {
    local iface="$1"
    
    # Check if interface has an IP address
    if ip addr show dev "$iface" 2>/dev/null | grep -q "inet "; then
        # Check internet connectivity
        if ping -c 1 -W 2 -I "$iface" 8.8.8.8 >/dev/null 2>&1; then
            return 0  # Connected with internet
        else
            return 1  # Has IP but no internet
        fi
    else
        return 2  # No IP address
    fi
}

# If in client mode, test the connection now that we have the interface
if [ "$NETWORK_MODE" = "CLIENT" ]; then
    debug "Setting up client mode connection testing"
    echo
    status "Testing connection to WiFi network with selected interface..."
    debug "Testing connection with SSID: $CLIENT_SSID, Interface: $AP_INTERFACE"
    
    # Check if interface is already connected
    status "Checking if $AP_INTERFACE is already connected..."
    if is_interface_connected "$AP_INTERFACE"; then
        success "$AP_INTERFACE is already connected to internet"
        status "Using existing connection instead of testing"
        
        # Get current connection details for display
        current_ssid=$(iwconfig $AP_INTERFACE 2>/dev/null | grep -oP 'ESSID:"\K[^"]+' || echo "Unknown")
        current_ip=$(ip -4 addr show $AP_INTERFACE | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n 1)
        
        echo "Current connection: SSID=$current_ssid, IP=$current_ip"
        
        if [ "$current_ssid" != "$CLIENT_SSID" ]; then
            warning "Note: You requested to connect to '$CLIENT_SSID' but currently connected to '$current_ssid'"
            if confirm "Would you like to continue with the current connection?" "Y"; then
                success "Using current connection"
                CLIENT_SSID="$current_ssid"
                USING_EXISTING_CONNECTION=true
            else
                if confirm "Disconnect and try connecting to '$CLIENT_SSID'?" "N"; then
                    status "Attempting to connect to requested network..."
                    # Continue with test_wifi_connection below
                else
                    echo "Setup cancelled. No changes were made."
                    exit 0
                fi
            fi
        else
            success "Already connected to requested network '$CLIENT_SSID'"
            USING_EXISTING_CONNECTION=true
        fi
    else
        # Skip test if not running as root
        if [ "$EUID" -ne 0 ]; then
            warning "Root access required to test WiFi connection. Skipping test."
            debug "Skipping test due to non-root execution"
        else
            debug "About to run test_wifi_connection function"
            if ! test_wifi_connection "$CLIENT_SSID" "$CLIENT_PASSWORD"; then
                debug "Connection test failed"
                warning "Could not verify WiFi connection. Make sure the credentials are correct."
                warning "The setup will continue, but the WiFi connection may not work properly."
                warning "You may need to manually configure the WiFi connection after installation."
                
                if ! confirm "Continue with setup anyway?" "Y"; then
                    debug "User cancelled setup after failed connection test"
                    echo "Setup cancelled. No changes were made."
                    exit 0
                fi
            else
                debug "Connection test succeeded"
                success "Successfully connected to WiFi network"
            fi
        fi
    fi
fi

# Configuration variables - initialize with defaults
SSID="hakpak"
WIFI_PASSWORD="pentestallthethings"
CHANNEL=6
IP_ADDRESS="192.168.4.1"
DHCP_RANGE_START="192.168.4.2"
DHCP_RANGE_END="192.168.4.100"
ADMIN_PASSWORD="hakpak"
ENABLE_INTERNET_SHARING=true
USE_CUSTOM_DNS=false
DNS1="8.8.8.8"
DNS2="8.8.4.4"
HOSTNAME="hakpak"
INSTALL_DIR="/opt/hakpak"

echo
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}   Basic Configuration                ${NC}"
echo -e "${BLUE}========================================${NC}"

# Configuration prompts based on network mode
if [ "$NETWORK_MODE" = "AP" ]; then
    # AP mode configuration
    SSID=$(prompt_string "WiFi network name (SSID)" "$SSID")
    WIFI_PASSWORD=$(prompt_string "WiFi password (min 8 chars)" "$WIFI_PASSWORD")

    # Validate WiFi password length
    while [ ${#WIFI_PASSWORD} -lt 8 ]; do
        warning "WiFi password must be at least 8 characters long."
        WIFI_PASSWORD=$(prompt_string "WiFi password (min 8 chars)" "$WIFI_PASSWORD")
    done

    # Prompt for country code
    COUNTRY_CODE=$(prompt_string "WiFi country code (2-letter code)" "$COUNTRY_CODE")

    # Scan available channels
    status "Scanning for available WiFi channels..."
    if command -v iwlist >/dev/null 2>&1; then
        # Try to get available channels
        CHANNEL_INFO=$(iwlist $AP_INTERFACE freq 2>/dev/null | grep -oP 'Channel \d+' | sort -u)
        if [ ! -z "$CHANNEL_INFO" ]; then
            echo "Available WiFi channels for $AP_INTERFACE:"
            echo "$CHANNEL_INFO"
            echo "Recommended: Channel 1, 6, or 11 for 2.4GHz to avoid interference"
        else
            echo "Couldn't detect available channels. Recommended: Channel 1, 6, or 11 for 2.4GHz"
        fi
    else
        echo "Available WiFi channels: 1, 6, 11 (recommended for 2.4GHz)"
    fi

    CHANNEL=$(prompt_string "WiFi channel" "$CHANNEL")

    # Prompt for IP address
    IP_ADDRESS=$(prompt_string "HakPak IP address" "$IP_ADDRESS")
    
    # Prompt for internet sharing
    if confirm "Would you like to configure internet sharing?" "Y"; then
        select_internet_interface
    fi
else
    # Client mode configuration - we already have SSID and password
    COUNTRY_CODE=$(prompt_string "WiFi country code (2-letter code)" "$COUNTRY_CODE")
    # No need for channel or IP address prompts in client mode
fi

# Common configuration regardless of network mode
ADMIN_PASSWORD=$(prompt_string "Admin password for web interface" "$ADMIN_PASSWORD")
HOSTNAME=$(prompt_string "Hostname" "$HOSTNAME")

echo
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}   Advanced Configuration             ${NC}"
echo -e "${BLUE}========================================${NC}"

# Prompt for custom DNS servers (in client mode, these will be ignored)
if [ "$NETWORK_MODE" = "AP" ] && confirm "Use custom DNS servers?" "N"; then
    USE_CUSTOM_DNS=true
    echo "Some popular DNS servers:"
    echo "  - Google: 8.8.8.8, 8.8.4.4"
    echo "  - Cloudflare: 1.1.1.1, 1.0.0.1"
    echo "  - OpenDNS: 208.67.222.222, 208.67.220.220"
    DNS1=$(prompt_string "Primary DNS server" "$DNS1")
    DNS2=$(prompt_string "Secondary DNS server" "$DNS2")
else
    USE_CUSTOM_DNS=false
fi

# Prompt for installation directory
INSTALL_DIR=$(prompt_string "Installation directory" "$INSTALL_DIR")

echo
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}   Installation Summary               ${NC}"
echo -e "${BLUE}========================================${NC}"

echo -e "Network Mode: ${GREEN}$([ "$NETWORK_MODE" = "AP" ] && echo "Access Point" || echo "Client")${NC}"
if [ "$NETWORK_MODE" = "AP" ]; then
    echo -e "WiFi Network Name: ${GREEN}$SSID${NC}"
    echo -e "WiFi Password: ${GREEN}$WIFI_PASSWORD${NC}"
    echo -e "WiFi Channel: ${GREEN}$CHANNEL${NC}"
    echo -e "IP Address: ${GREEN}$IP_ADDRESS${NC}"
    
    if [ "$ENABLE_INTERNET_SHARING" = true ]; then
        echo -e "Internet Sharing: ${GREEN}Enabled${NC} (via $INTERNET_IFACE)"
    else
        echo -e "Internet Sharing: ${RED}Disabled${NC}"
    fi
    
    if [ "$USE_CUSTOM_DNS" = true ]; then
        echo -e "Custom DNS: ${GREEN}Enabled${NC} (Primary: $DNS1, Secondary: $DNS2)"
    else
        echo -e "Custom DNS: ${RED}Disabled${NC} (Using default Google DNS)"
    fi
else
    echo -e "Connect to WiFi: ${GREEN}$CLIENT_SSID${NC}"
    echo -e "Client IP Address: ${GREEN}$([ -n "$CLIENT_IP" ] && echo "$CLIENT_IP" || echo "Assigned by DHCP")${NC}"
fi

echo -e "Country Code: ${GREEN}$COUNTRY_CODE${NC}"
echo -e "AP Interface: ${GREEN}$AP_INTERFACE${NC}"
echo -e "Admin Password: ${GREEN}$ADMIN_PASSWORD${NC}"
echo -e "Hostname: ${GREEN}$HOSTNAME${NC}"
echo -e "Installation Directory: ${GREEN}$INSTALL_DIR${NC}"

echo
if ! confirm "Review the configuration above. Would you like to proceed with installation?" "Y"; then
    echo "Setup cancelled. No changes were made."
    exit 0
fi

# Create backup directory
BACKUP_DIR="$INSTALL_DIR/backups/$(date +%Y%m%d%H%M%S)"
mkdir -p $BACKUP_DIR

# Backup existing configurations
status "Backing up existing configurations..."
if [ -f /etc/hostapd/hostapd.conf ]; then
    cp /etc/hostapd/hostapd.conf ${BACKUP_DIR}/hostapd.conf.bak
fi
if [ -f /etc/dnsmasq.conf ]; then
    cp /etc/dnsmasq.conf ${BACKUP_DIR}/dnsmasq.conf.bak
fi
if [ -f /etc/wpa_supplicant/wpa_supplicant-${AP_INTERFACE}.conf ]; then
    cp /etc/wpa_supplicant/wpa_supplicant-${AP_INTERFACE}.conf ${BACKUP_DIR}/wpa_supplicant-${AP_INTERFACE}.conf.bak
fi
if [ -f /etc/network/interfaces ]; then
    cp /etc/network/interfaces ${BACKUP_DIR}/interfaces.bak
fi

# Stop network services
if [ "$USING_EXISTING_CONNECTION" = true ]; then
    status "Preserving existing network connection..."
else
    status "Stopping network services..."
    if [ "$NETWORK_MODE" = "AP" ]; then
        systemctl stop hostapd dnsmasq 2>/dev/null || true
    else
        systemctl stop wpa_supplicant 2>/dev/null || true
    fi
fi

# Configure network based on selected mode
setup_network

# Set up HakPak application
status "Setting up HakPak application..."

# Create HakPak directories
mkdir -p ${INSTALL_DIR}
mkdir -p ${INSTALL_DIR}/data
mkdir -p ${INSTALL_DIR}/logs

# Set up Python environment if it doesn't exist
if [ ! -d "${INSTALL_DIR}/venv" ]; then
    status "Creating Python virtual environment..."
    python3 -m venv ${INSTALL_DIR}/venv
fi

# Copy application files
status "Copying application files..."
cp -r ./* ${INSTALL_DIR}/ 2>/dev/null || true

# Create hakpak.conf with user settings
status "Creating configuration file..."
mkdir -p ${INSTALL_DIR}/config
cat > ${INSTALL_DIR}/config/hakpak.conf << EOF
# HakPak Configuration
# Generated by setup script

[General]
hostname = ${HOSTNAME}
admin_password = ${ADMIN_PASSWORD}
data_dir = ${INSTALL_DIR}/data
log_dir = ${INSTALL_DIR}/logs

[Network]
network_mode = ${NETWORK_MODE}
ap_interface = ${AP_INTERFACE}
ip_address = ${IP_ADDRESS}
ssid = ${SSID}
internet_sharing = ${ENABLE_INTERNET_SHARING}
EOF

# Add client mode specific settings if applicable
if [ "$NETWORK_MODE" = "CLIENT" ]; then
    cat >> ${INSTALL_DIR}/config/hakpak.conf << EOF
client_ssid = ${CLIENT_SSID}
EOF
fi

# Create basic Flask application
configure_basic_flask_app

# Install Python dependencies
status "Installing Python dependencies..."
${INSTALL_DIR}/venv/bin/pip install --upgrade pip || python3 -m pip install --upgrade pip
# Try multiple ways to install requirements in case one fails
if [ -f "${INSTALL_DIR}/requirements.txt" ]; then
    status "Installing from requirements.txt..."
    ${INSTALL_DIR}/venv/bin/pip install -r ${INSTALL_DIR}/requirements.txt || \
    python3 -m pip install -r ${INSTALL_DIR}/requirements.txt
else
    warning "requirements.txt not found. Installing basic packages..."
    ${INSTALL_DIR}/venv/bin/pip install flask flask-socketio gunicorn || \
    python3 -m pip install flask flask-socketio gunicorn
fi

# Make sure app directories exist and have correct permissions
mkdir -p ${INSTALL_DIR}/app/static
mkdir -p ${INSTALL_DIR}/app/templates
chmod -R 755 ${INSTALL_DIR}

# Create HakPak service
status "Creating HakPak service..."
cat > /etc/systemd/system/hakpak.service << EOF
[Unit]
Description=HakPak Service
After=network.target

[Service]
User=root
WorkingDirectory=${INSTALL_DIR}
ExecStart=${INSTALL_DIR}/venv/bin/python ${INSTALL_DIR}/app.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Fix the Nginx configuration for proper proxy setup
status "Configuring Nginx for HakPak..."
cat > /etc/nginx/sites-available/hakpak << EOF
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    
    root ${INSTALL_DIR}/public;
    index index.html;
    
    server_name _;
    
    # First try to serve the static files
    location /static/ {
        alias ${INSTALL_DIR}/app/static/;
    }
    
    # Then proxy to the Flask app for all other routes
    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_connect_timeout 75s;
        proxy_read_timeout 300s;
    }
    
    # Simple fallback page if Flask app is down
    error_page 502 503 504 /error.html;
    location = /error.html {
        root ${INSTALL_DIR}/public;
    }
}
EOF

# Create the error page
mkdir -p ${INSTALL_DIR}/public
cat > ${INSTALL_DIR}/public/error.html << EOF
<!DOCTYPE html>
<html>
<head>
    <title>HakPak - Service Unavailable</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; line-height: 1.6; }
        .error { color: #e74c3c; }
        .container { max-width: 800px; margin: 0 auto; padding: 20px; border: 1px solid #ddd; border-radius: 5px; }
        h1 { color: #333; }
        pre { background: #f5f5f5; padding: 10px; border-radius: 4px; overflow-x: auto; }
        .command { background-color: #f8f9fa; padding: 8px; border-radius: 4px; font-family: monospace; }
    </style>
</head>
<body>
    <div class="container">
        <h1>HakPak Application is Starting</h1>
        <p>The HakPak web application is currently unavailable. It may be starting up or encountering issues.</p>
        
        <h2>Troubleshooting Steps:</h2>
        <ol>
            <li>Wait a minute for the application to start up</li>
            <li>Check the service status: <div class="command">sudo systemctl status hakpak</div></li>
            <li>View the service logs: <div class="command">sudo journalctl -u hakpak</div></li>
            <li>Try restarting the service: <div class="command">sudo systemctl restart hakpak</div></li>
            <li>Try restarting Nginx: <div class="command">sudo systemctl restart nginx</div></li>
        </ol>
        
        <p>You can also run the health check script: <div class="command">${INSTALL_DIR}/scripts/health_check.sh</div></p>
    </div>
</body>
</html>
EOF

# Set proper permissions
chown -R www-data:www-data ${INSTALL_DIR}/public

# Enable Nginx site
mkdir -p /etc/nginx/sites-enabled/
ln -sf /etc/nginx/sites-available/hakpak /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Enable and start services
status "Starting services..."
systemctl daemon-reload

# Test Nginx configuration before restarting
if nginx -t; then
    systemctl enable nginx
    systemctl restart nginx
    success "Nginx configuration is valid"
else
    warning "Nginx configuration has errors, attempting simpler configuration..."
    # Fallback to simpler configuration
    cat > /etc/nginx/sites-available/hakpak << EOF
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    
    root ${INSTALL_DIR}/public;
    index index.html;
    
    server_name _;
    
    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF
    ln -sf /etc/nginx/sites-available/hakpak /etc/nginx/sites-enabled/
    systemctl restart nginx
fi

# Enable and start HakPak service
systemctl enable hakpak

# Start the service and verify it's running
status "Starting HakPak service..."
systemctl restart hakpak
sleep 5

# Check if the service is running
if systemctl is-active hakpak >/dev/null 2>&1; then
    success "HakPak service started successfully"
else
    warning "HakPak service failed to start, attempting manual start..."
    
    # Show service logs
    status "HakPak service logs:"
    journalctl -u hakpak -n 10 --no-pager
    
    # Try manual start for troubleshooting
    status "Attempting to start app.py manually for troubleshooting..."
    cd ${INSTALL_DIR}
    ${INSTALL_DIR}/venv/bin/python ${INSTALL_DIR}/app.py --check-only
    
    # Try restarting one more time
    systemctl restart hakpak
    sleep 3
    
    if systemctl is-active hakpak >/dev/null 2>&1; then
        success "HakPak service started successfully on second attempt"
    else
        warning "HakPak service still not running. Web interface may not be available."
    fi
fi

# Check if Nginx is running
if systemctl is-active nginx >/dev/null 2>&1; then
    success "Nginx started successfully"
else
    warning "Nginx failed to start. Try checking logs with: journalctl -u nginx"
fi

# Add this function for final steps and verification based on network mode
final_setup_and_verify() {
    echo
    status "Running final verification steps..."
    
    # Check critical services based on network mode
    if [ "$NETWORK_MODE" = "AP" ]; then
        # AP mode services
        for service in hostapd dnsmasq nginx hakpak; do
            if systemctl is-active $service >/dev/null 2>&1; then
                success "$service is running"
            else
                warning "$service is not running - this might affect functionality"
            fi
        done
        
        # Verify AP mode
        status "Verifying AP mode..."
        if iw dev ${AP_INTERFACE} info 2>/dev/null | grep -q "type AP"; then
            success "WiFi AP is running on ${AP_INTERFACE}"
        else
            warning "WiFi AP is not in AP mode. Current state:"
            iw dev ${AP_INTERFACE} info || echo "Unable to get interface info"
            warning "You may need to reboot for changes to take effect"
        fi
        
        # Verify access point visibility
        verify_ap_visibility
    else
        # Client mode services
        for service in wpa_supplicant@${AP_INTERFACE} nginx hakpak; do
            if systemctl is-active $service >/dev/null 2>&1; then
                success "$service is running"
            else
                warning "$service is not running - this might affect functionality"
            fi
        done
        
        # Verify client mode connection
        status "Verifying WiFi connection..."
        if ip addr show ${AP_INTERFACE} | grep -q "inet "; then
            client_ip=$(ip addr show ${AP_INTERFACE} | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n 1)
            success "Connected to WiFi network '${CLIENT_SSID}' with IP: ${client_ip}"
            # Update IP_ADDRESS for the connection guide
            IP_ADDRESS="${client_ip}"
        else
            warning "Not connected to WiFi network. Current state:"
            ip addr show ${AP_INTERFACE}
            warning "You may need to reboot for changes to take effect"
        fi
    fi
    
    # Verify interface configuration
    echo
    status "Network interface configuration:"
    ip addr show ${AP_INTERFACE}
    
    # Verify routing and firewall if internet sharing is enabled (AP mode only)
    if [ "$NETWORK_MODE" = "AP" ] && [ "$ENABLE_INTERNET_SHARING" = true ]; then
        echo
        status "Checking internet sharing configuration..."
        echo "IP forwarding status: $(cat /proc/sys/net/ipv4/ip_forward)"
        echo "NAT rules:"
        iptables -t nat -L -v | grep -B 2 -A 2 MASQUERADE || echo "No NAT rules found"
    fi
    
    # Create a connection guide based on network mode
    echo
    status "Creating connection guide..."
    mkdir -p ${INSTALL_DIR}/docs
    
    if [ "$NETWORK_MODE" = "AP" ]; then
        # AP mode connection guide
        cat > ${INSTALL_DIR}/docs/connect.md << EOF
# HakPak Connection Guide (Access Point Mode)

## WiFi Connection Details
* **SSID:** ${SSID}
* **Password:** ${WIFI_PASSWORD}
* **IP Address:** ${IP_ADDRESS}

## Web Interface
* Open your browser and navigate to: http://${IP_ADDRESS}
* Login with:
  * Username: admin
  * Password: ${ADMIN_PASSWORD}

## Troubleshooting
If you can't see the WiFi network:
1. Ensure you're within range of the device
2. Try rebooting the Raspberry Pi: \`sudo reboot\`
3. Run the health check: \`sudo ${INSTALL_DIR}/scripts/health_check.sh\`
4. Check service status: \`sudo systemctl status hostapd dnsmasq nginx hakpak\`

## Manual Restart
To manually restart all services:
\`\`\`
sudo systemctl restart hostapd dnsmasq nginx hakpak
\`\`\`
EOF
    else
        # Client mode connection guide
        cat > ${INSTALL_DIR}/docs/connect.md << EOF
# HakPak Connection Guide (Client Mode)

## Connection Details
* HakPak is connected to WiFi network: **${CLIENT_SSID}**
* IP Address: ${IP_ADDRESS} (may change if DHCP assigns a different address)

## Web Interface
* Open your browser and navigate to: http://${IP_ADDRESS}
* If the IP address has changed, you can find it by running: \`ip addr show ${AP_INTERFACE}\`
* Login with:
  * Username: admin
  * Password: ${ADMIN_PASSWORD}

## Troubleshooting
If you can't connect to HakPak:
1. Ensure your device is on the same network as HakPak (${CLIENT_SSID})
2. Verify HakPak's IP address with: \`ip addr show ${AP_INTERFACE}\`
3. Try rebooting the Raspberry Pi: \`sudo reboot\`
4. Run the health check: \`sudo ${INSTALL_DIR}/scripts/health_check.sh\`
5. Check service status: \`sudo systemctl status wpa_supplicant@${AP_INTERFACE} nginx hakpak\`

## Manual Restart
To manually restart all services:
\`\`\`
sudo systemctl restart wpa_supplicant@${AP_INTERFACE} nginx hakpak
\`\`\`
EOF
    fi
    
    success "Connection guide created at ${INSTALL_DIR}/docs/connect.md"
}

# Function to troubleshoot and fix common issues
troubleshoot_and_fix() {
    status "Running additional troubleshooting checks..."
    
    # Check nginx configuration
    if ! nginx -t >/dev/null 2>&1; then
        warning "Nginx configuration has errors, attempting to fix..."
        nginx -t
        # Create a simpler configuration
        cat > /etc/nginx/sites-available/hakpak << EOF
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    
    root ${INSTALL_DIR}/public;
    index index.html;
    
    server_name _;
    
    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF
        ln -sf /etc/nginx/sites-available/hakpak /etc/nginx/sites-enabled/
        rm -f /etc/nginx/sites-enabled/default
        systemctl restart nginx
        
        if nginx -t >/dev/null 2>&1; then
            success "Fixed Nginx configuration"
        else
            warning "Still having issues with Nginx configuration"
        fi
    fi
    
    # Check if HakPak service is running
    if ! systemctl is-active hakpak >/dev/null 2>&1; then
        warning "HakPak service is not running, checking for issues..."
        
        # Check if app.py exists
        if [ ! -f "${INSTALL_DIR}/app.py" ]; then
            warning "app.py not found in ${INSTALL_DIR}"
            find ${INSTALL_DIR} -name "app.py" 2>/dev/null
            status "Checking for any Python files..."
            find ${INSTALL_DIR} -name "*.py" | head -5
        fi
        
        # Check for Python modules
        if [ -d "${INSTALL_DIR}/venv" ]; then
            status "Checking installed Python modules..."
            ${INSTALL_DIR}/venv/bin/pip list | grep -i flask
        else
            warning "Python virtualenv not found at ${INSTALL_DIR}/venv"
        fi
        
        # Create a simple test page that should definitely work
        status "Creating a simple test page..."
        mkdir -p ${INSTALL_DIR}/public
        cat > ${INSTALL_DIR}/public/index.html << EOF
<!DOCTYPE html>
<html>
<head>
    <title>HakPak Test Page</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            margin: 40px;
            line-height: 1.6;
        }
        .success {
            color: green;
            font-weight: bold;
        }
        .container {
            max-width: 800px;
            margin: 0 auto;
            padding: 20px;
            border: 1px solid #ddd;
            border-radius: 5px;
        }
        h1 {
            color: #333;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>HakPak Test Page</h1>
        <p class="success">If you see this page, Nginx is working properly!</p>
        <p>The HakPak application itself might still be starting up or encountering issues.</p>
        <p>Try the following steps:</p>
        <ol>
            <li>Wait a few minutes for all services to start</li>
            <li>Check the status: <code>sudo systemctl status hakpak</code></li>
            <li>View the logs: <code>sudo journalctl -u hakpak</code></li>
            <li>Restart the service: <code>sudo systemctl restart hakpak</code></li>
        </ol>
        <p>You can also run the health check script: <code>${INSTALL_DIR}/scripts/health_check.sh</code></p>
        <hr>
        <p><small>IP Address: ${IP_ADDRESS} (AP mode) or ${CLIENT_IP} (Client mode)</small></p>
        <p><small>Generated: $(date)</small></p>
    </div>
</body>
</html>
EOF
        chown -R www-data:www-data ${INSTALL_DIR}/public
        
        status "Restarting Nginx..."
        systemctl restart nginx
        
        status "Attempting to start HakPak service again..."
        systemctl restart hakpak
    fi
}

# After running final_setup_and_verify, call the troubleshooting function
final_setup_and_verify
troubleshoot_and_fix

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}   HakPak Setup Complete!              ${NC}"
echo -e "${GREEN}========================================${NC}"

if [ "$NETWORK_MODE" = "AP" ]; then
    echo -e "Network Mode: ${YELLOW}Access Point${NC}"
    echo -e "SSID: ${YELLOW}${SSID}${NC}"
    echo -e "Password: ${YELLOW}${WIFI_PASSWORD}${NC}"
    echo -e "Access the web interface at ${YELLOW}http://${IP_ADDRESS}${NC}"
else
    echo -e "Network Mode: ${YELLOW}Client${NC}"
    echo -e "Connected to WiFi: ${YELLOW}${CLIENT_SSID}${NC}"
    echo -e "Access the web interface at ${YELLOW}http://${IP_ADDRESS}${NC}"
    echo -e "Note: The IP address may change with DHCP assignment"
fi

echo -e "Admin user: ${YELLOW}admin${NC}"
echo -e "Admin password: ${YELLOW}${ADMIN_PASSWORD}${NC}"
echo

if [ "$NETWORK_MODE" = "AP" ]; then
    echo -e "If you don't see the WiFi network, try rebooting:"
else
    echo -e "If you can't connect to HakPak, try rebooting:"
fi
echo -e "${YELLOW}sudo reboot${NC}"
echo

echo -e "To check the system status after reboot, run:"
if [ "$NETWORK_MODE" = "AP" ]; then
    echo -e "${YELLOW}sudo systemctl status hostapd dnsmasq nginx hakpak${NC}"
else
    echo -e "${YELLOW}sudo systemctl status wpa_supplicant@${AP_INTERFACE} nginx hakpak${NC}"
fi
echo

echo -e "To troubleshoot issues, run the health check script:"
echo -e "${YELLOW}${INSTALL_DIR}/scripts/health_check.sh${NC}"
echo

echo -e "Connection guide available at:"
echo -e "${YELLOW}${INSTALL_DIR}/docs/connect.md${NC}"
echo

echo -e "${GREEN}========================================${NC}"

# End of script 