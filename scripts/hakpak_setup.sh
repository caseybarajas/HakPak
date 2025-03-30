#!/bin/bash

# HakPak Complete Setup Script
# This script sets up HakPak with proper networking configuration
# for any Raspberry Pi running Kali Linux

set -e
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
    if [ ${#WIFI_INTERFACES[@]} -eq 0 ]; then
        error "No wireless interfaces found. HakPak requires at least one wireless interface."
    elif [ ${#WIFI_INTERFACES[@]} -eq 1 ]; then
        AP_INTERFACE=${WIFI_INTERFACES[0]}
        success "Using ${AP_INTERFACE} for Access Point mode (only wireless interface available)"
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
    fi
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

# Detect and scan all network interfaces
status "Scanning for network interfaces..."
scan_network_interfaces

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

echo
status "Configuring network interfaces..."

# Select WiFi interface for AP
select_wifi_interface

# Configuration variables - initialize with defaults
SSID="hakpak"
WIFI_PASSWORD="pentestallthethings"
COUNTRY_CODE="US"
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

# Prompt for WiFi settings
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

# Prompt for admin password
ADMIN_PASSWORD=$(prompt_string "Admin password for web interface" "$ADMIN_PASSWORD")

# Prompt for hostname
HOSTNAME=$(prompt_string "Hostname" "$HOSTNAME")

echo
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}   Advanced Configuration             ${NC}"
echo -e "${BLUE}========================================${NC}"

# Prompt for internet sharing
if confirm "Would you like to configure internet sharing?" "Y"; then
    select_internet_interface
fi

# Prompt for custom DNS servers
if confirm "Use custom DNS servers?" "N"; then
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

echo -e "WiFi Network Name: ${GREEN}$SSID${NC}"
echo -e "WiFi Password: ${GREEN}$WIFI_PASSWORD${NC}"
echo -e "WiFi Channel: ${GREEN}$CHANNEL${NC}"
echo -e "Country Code: ${GREEN}$COUNTRY_CODE${NC}"
echo -e "AP Interface: ${GREEN}$AP_INTERFACE${NC}"
echo -e "IP Address: ${GREEN}$IP_ADDRESS${NC}"
echo -e "Admin Password: ${GREEN}$ADMIN_PASSWORD${NC}"
echo -e "Hostname: ${GREEN}$HOSTNAME${NC}"
echo -e "Installation Directory: ${GREEN}$INSTALL_DIR${NC}"

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

echo
if ! confirm "Review the configuration above. Would you like to proceed with installation?" "Y"; then
    echo "Setup cancelled. No changes were made."
    exit 0
fi

# Create backup directory
BACKUP_DIR="$INSTALL_DIR/backups/$(date +%Y%m%d%H%M%S)"
mkdir -p $BACKUP_DIR

# Begin actual installation
echo
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}   Starting Installation              ${NC}"
echo -e "${BLUE}========================================${NC}"

# Confirm one last time before making changes
if ! confirm "This will modify system files. Are you sure you want to continue?" "Y"; then
    echo "Setup cancelled. No changes were made."
    exit 0
fi

# Check for required packages
status "Checking required packages..."
PACKAGES="hostapd dnsmasq nginx python3-pip python3-venv usbutils git rfkill iw wireless-tools"
apt update
for pkg in $PACKAGES; do
    if ! dpkg -s $pkg >/dev/null 2>&1; then
        status "Installing $pkg..."
        apt install -y $pkg
    fi
done
success "All required packages are installed"

# Stop network services
status "Stopping network services..."
systemctl stop hostapd dnsmasq 2>/dev/null || true

# Handle any conflicting services
status "Checking for conflicting services..."

# Check if NetworkManager is controlling wireless
if systemctl is-active NetworkManager >/dev/null 2>&1; then
    status "Configuring NetworkManager to ignore ${AP_INTERFACE}..."
    mkdir -p /etc/NetworkManager/conf.d/
    echo -e "[keyfile]\nunmanaged-devices=interface-name:${AP_INTERFACE}" > /etc/NetworkManager/conf.d/hakpak.conf
    check_command systemctl restart NetworkManager
fi

# Check for processes using port 53
PORT_53_PROCESS=$(lsof -i :53 2>/dev/null | grep LISTEN | awk '{print $1}' | uniq)
if [ ! -z "$PORT_53_PROCESS" ]; then
    warning "Found $PORT_53_PROCESS using port 53. Attempting to handle..."
    
    # Handle systemd-resolved
    if [[ "$PORT_53_PROCESS" == *"systemd-r"* ]]; then
        status "Configuring systemd-resolved to work with dnsmasq..."
        if [ -f /etc/systemd/resolved.conf ]; then
            cp /etc/systemd/resolved.conf ${BACKUP_DIR}/resolved.conf.bak
            sed -i 's/#DNSStubListener=yes/DNSStubListener=no/' /etc/systemd/resolved.conf
            systemctl restart systemd-resolved
        fi
    else
        warning "Unknown service using port 53. You may need to manually stop it."
    fi
fi

# Backup existing configurations
status "Backing up existing configurations..."
if [ -f /etc/hostapd/hostapd.conf ]; then
    cp /etc/hostapd/hostapd.conf ${BACKUP_DIR}/hostapd.conf.bak
fi
if [ -f /etc/dnsmasq.conf ]; then
    cp /etc/dnsmasq.conf ${BACKUP_DIR}/dnsmasq.conf.bak
fi
if [ -f /etc/network/interfaces ]; then
    cp /etc/network/interfaces ${BACKUP_DIR}/interfaces.bak
fi

# Configure hostapd
status "Configuring hostapd..."
cat > /etc/hostapd/hostapd.conf << EOF
# Basic configuration
interface=${AP_INTERFACE}
driver=nl80211
ssid=${SSID}
hw_mode=g
channel=${CHANNEL}
country_code=${COUNTRY_CODE}

# 802.11n support
ieee80211n=1
ht_capab=[HT40][SHORT-GI-20][DSSS_CCK-40]

# Security settings
auth_algs=1
wpa=2
wpa_passphrase=${WIFI_PASSWORD}
wpa_key_mgmt=WPA-PSK
wpa_pairwise=CCMP
rsn_pairwise=CCMP

# Other settings
macaddr_acl=0
ignore_broadcast_ssid=0
wmm_enabled=1
wpa_group_rekey=86400

# Logging
logger_syslog=-1
logger_syslog_level=2
logger_stdout=-1
logger_stdout_level=2

# Allow management frame protection
ieee80211w=0
EOF

# Configure hostapd default file
cat > /etc/default/hostapd << EOF
DAEMON_CONF="/etc/hostapd/hostapd.conf"
EOF

success "Hostapd configured"

# Extract network from IP address
IP_NETWORK=$(echo $IP_ADDRESS | cut -d. -f1-3)

# Configure dnsmasq
status "Configuring dnsmasq..."
cat > /etc/dnsmasq.conf << EOF
# Interface to bind to
interface=${AP_INTERFACE}
bind-interfaces
except-interface=lo
no-dhcp-interface=lo

# DHCP range and lease time
dhcp-range=${DHCP_RANGE_START},${DHCP_RANGE_END},255.255.255.0,24h

# Default gateway and DNS servers
dhcp-option=option:router,${IP_ADDRESS}
dhcp-option=option:dns-server,${IP_ADDRESS}
dhcp-option=option:netmask,255.255.255.0

# Domain name
domain=${HOSTNAME}.local
expand-hosts
local=/${HOSTNAME}.local/
address=/${HOSTNAME}.local/${IP_ADDRESS}

# Listen only on specific addresses
listen-address=127.0.0.1,${IP_ADDRESS}

# DNS options
domain-needed
bogus-priv
no-resolv
no-poll

# External DNS servers
EOF

if [ "$USE_CUSTOM_DNS" = true ]; then
    echo "server=${DNS1}" >> /etc/dnsmasq.conf
    echo "server=${DNS2}" >> /etc/dnsmasq.conf
else
    echo "server=8.8.8.8" >> /etc/dnsmasq.conf
    echo "server=8.8.4.4" >> /etc/dnsmasq.conf
fi

cat >> /etc/dnsmasq.conf << EOF

# DHCP options
dhcp-authoritative
dhcp-leasefile=/var/lib/misc/dnsmasq.leases

# Improve startup reliability
bind-dynamic
EOF

success "Dnsmasq configured"

# Add Nginx config for HakPak
status "Configuring Nginx..."
mkdir -p /etc/nginx/sites-available/
cat > /etc/nginx/sites-available/hakpak << EOF
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    
    root ${INSTALL_DIR}/public;
    index index.html;
    
    server_name _;
    
    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOF

# Create public directory
mkdir -p ${INSTALL_DIR}/public
echo "<html><body><h1>HakPak</h1><p>If you see this page, Nginx is running but the HakPak application is not.</p></body></html>" > ${INSTALL_DIR}/public/index.html

# Enable Nginx site
mkdir -p /etc/nginx/sites-enabled/
ln -sf /etc/nginx/sites-available/hakpak /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Configure network interfaces
status "Setting up ${AP_INTERFACE} interface..."
setup_wifi_ap

# Test hostapd configuration before starting
test_hostapd_config

# Set up IP forwarding and NAT if requested
if [ "$ENABLE_INTERNET_SHARING" = true ] && [ -n "$INTERNET_IFACE" ] && [ "$INTERNET_IFACE" != "$AP_INTERFACE" ]; then
    status "Setting up IP forwarding and NAT for internet sharing..."
    echo 1 > /proc/sys/net/ipv4/ip_forward
    
    # Set up persistent IP forwarding
    if ! grep -q "net.ipv4.ip_forward=1" /etc/sysctl.conf; then
        echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
    fi
    
    # Set up NAT rules
    iptables -t nat -F
    iptables -t nat -A POSTROUTING -o $INTERNET_IFACE -j MASQUERADE
    iptables -F
    iptables -A FORWARD -i $INTERNET_IFACE -o ${AP_INTERFACE} -m state --state RELATED,ESTABLISHED -j ACCEPT
    iptables -A FORWARD -i ${AP_INTERFACE} -o $INTERNET_IFACE -j ACCEPT
    
    # Make iptables rules persistent
    if command -v iptables-save >/dev/null 2>&1; then
        status "Making iptables rules persistent..."
        mkdir -p /etc/iptables/
        iptables-save > /etc/iptables/rules.v4
        
        # Create a service to restore iptables rules
        cat > /etc/systemd/system/iptables-restore.service << EOF
[Unit]
Description=Restore iptables rules
After=network.target

[Service]
Type=oneshot
ExecStart=/sbin/iptables-restore /etc/iptables/rules.v4
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
        systemctl daemon-reload
        systemctl enable iptables-restore.service
    fi
    
    success "IP forwarding and NAT configured"
else
    status "Internet sharing not configured. HakPak will operate in standalone mode."
fi

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
ap_interface = ${AP_INTERFACE}
ip_address = ${IP_ADDRESS}
ssid = ${SSID}
internet_sharing = ${ENABLE_INTERNET_SHARING}
internet_interface = ${INTERNET_IFACE}

[Flipper]
auto_detect = true
EOF

# Install Python dependencies
status "Installing Python dependencies..."
${INSTALL_DIR}/venv/bin/pip install --upgrade pip
if [ -f "${INSTALL_DIR}/requirements.txt" ]; then
    ${INSTALL_DIR}/venv/bin/pip install -r ${INSTALL_DIR}/requirements.txt
else
    warning "requirements.txt not found. Installing basic Python dependencies..."
    ${INSTALL_DIR}/venv/bin/pip install Flask Flask-SocketIO gunicorn eventlet pyserial RPi.GPIO gpiozero python-dotenv requests
fi

# Set up Flipper Zero udev rules
status "Setting up Flipper Zero udev rules..."
cat > /etc/udev/rules.d/42-flipper.rules << EOF
# Flipper Zero udev rules
SUBSYSTEMS=="usb", ATTRS{idVendor}=="0483", ATTRS{idProduct}=="5740", MODE="0666", SYMLINK+="flipper"
EOF

# Reload udev rules
udevadm control --reload-rules
udevadm trigger

# Set up HakPak service
status "Setting up HakPak service..."
cat > /etc/systemd/system/hakpak.service << EOF
[Unit]
Description=HakPak Web Service
After=network.target
Wants=hostapd.service dnsmasq.service

[Service]
ExecStart=${INSTALL_DIR}/venv/bin/gunicorn --worker-class eventlet -w 1 --bind 127.0.0.1:5000 app:app
WorkingDirectory=${INSTALL_DIR}
User=root
Group=root
Restart=always
RestartSec=5
Environment=PYTHONUNBUFFERED=1
Environment=HAKPAK_CONFIG=${INSTALL_DIR}/config/hakpak.conf

[Install]
WantedBy=multi-user.target
EOF

# Set appropriate permissions
status "Setting permissions..."
chown -R root:root ${INSTALL_DIR}
chmod -R 755 ${INSTALL_DIR}
find ${INSTALL_DIR}/scripts -type f -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true

# Start services in the correct order
status "Starting network services..."

# Ensure hostapd is unmasked
systemctl unmask hostapd

# Enable services
systemctl enable hostapd dnsmasq nginx hakpak

# Start hostapd
start_hostapd

# Start dnsmasq
status "Starting dnsmasq..."
systemctl restart dnsmasq
sleep 2

# Check if dnsmasq is running
if ! systemctl is-active dnsmasq >/dev/null 2>&1; then
    warning "Failed to start dnsmasq. Trying alternative configuration..."
    
    # Try alternative configuration
    cat > /etc/dnsmasq.conf << EOF
# Simpler configuration
interface=${AP_INTERFACE}
bind-interfaces
dhcp-range=${DHCP_RANGE_START},${DHCP_RANGE_END},255.255.255.0,24h
dhcp-option=option:router,${IP_ADDRESS}
dhcp-option=option:dns-server,8.8.8.8,8.8.4.4
listen-address=127.0.0.1,${IP_ADDRESS}
no-resolv
server=8.8.8.8
server=8.8.4.4
EOF
    
    systemctl restart dnsmasq
    sleep 2
    
    if ! systemctl is-active dnsmasq >/dev/null 2>&1; then
        warning "Dnsmasq still not starting. Check logs with: journalctl -xeu dnsmasq"
    else
        success "Dnsmasq started with alternative configuration"
    fi
else
    success "Dnsmasq started successfully"
fi

# Start nginx
status "Starting nginx..."
systemctl restart nginx

# Check if nginx is running
if ! systemctl is-active nginx >/dev/null 2>&1; then
    warning "Nginx failed to start. Check logs with: journalctl -xeu nginx"
else
    success "Nginx started successfully"
fi

# Start hakpak
status "Starting hakpak service..."
systemctl restart hakpak

# Check if hakpak is running
if ! systemctl is-active hakpak >/dev/null 2>&1; then
    warning "HakPak service failed to start. Check logs with: journalctl -xeu hakpak"
else
    success "HakPak service started successfully"
fi

# Verify AP mode
status "Verifying AP mode..."
if iw dev ${AP_INTERFACE} info 2>/dev/null | grep -q "type AP"; then
    success "WiFi AP is running on ${AP_INTERFACE}"
else
    warning "WiFi AP is not in AP mode. Current state:"
    iw dev ${AP_INTERFACE} info || echo "Unable to get interface info"
    warning "You may need to reboot for changes to take effect"
fi

# Add this function to check if the access point is visible
verify_ap_visibility() {
    status "Verifying access point visibility..."
    
    # Check if hostapd is actually running
    if ! pgrep hostapd >/dev/null; then
        warning "Hostapd process is not running!"
        return 1
    fi
    
    # Check if it's in AP mode
    if ! iw dev ${AP_INTERFACE} info 2>/dev/null | grep -q "type AP"; then
        warning "Interface ${AP_INTERFACE} is not in AP mode!"
        echo "Current interface mode:"
        iw dev ${AP_INTERFACE} info
        return 1
    fi
    
    # Try to scan for our own AP from another interface if available
    local TEST_IFACE=""
    for iface in "${WIFI_INTERFACES[@]}"; do
        if [ "$iface" != "$AP_INTERFACE" ]; then
            TEST_IFACE="$iface"
            break
        fi
    done
    
    if [ -n "$TEST_IFACE" ]; then
        status "Using ${TEST_IFACE} to scan for the access point..."
        # Put the interface in managed mode if it's not already
        ip link set ${TEST_IFACE} down
        sleep 1
        iwconfig ${TEST_IFACE} mode managed 2>/dev/null || true
        ip link set ${TEST_IFACE} up
        sleep 2
        
        # Scan for SSIDs
        echo "Scanning for SSIDs with ${TEST_IFACE}..."
        iw dev ${TEST_IFACE} scan | grep -A 2 "SSID:" || true
        
        if iw dev ${TEST_IFACE} scan | grep -q "SSID: ${SSID}"; then
            success "Access point '${SSID}' is visible!"
            return 0
        else
            warning "Could not see the access point '${SSID}' in scan results."
            # Return success anyway since this is just a verification
            return 0
        fi
    else
        echo "No secondary interface available to scan for the access point."
        # Try a different approach - check if hostapd has any stations connected
        echo "Checking hostapd status for active connections..."
        
        # Just return success since we can't verify further
        return 0
    fi
}

# Add this function for final steps and verification
final_setup_and_verify() {
    echo
    status "Running final verification steps..."
    
    # Check all critical services
    for service in hostapd dnsmasq nginx hakpak; do
        if systemctl is-active $service >/dev/null 2>&1; then
            success "$service is running"
        else
            warning "$service is not running - this might affect functionality"
        fi
    done
    
    # Verify interface configuration
    echo
    status "Network interface configuration:"
    ip addr show ${AP_INTERFACE}
    
    # Verify routing and firewall if internet sharing is enabled
    if [ "$ENABLE_INTERNET_SHARING" = true ]; then
        echo
        status "Checking internet sharing configuration..."
        echo "IP forwarding status: $(cat /proc/sys/net/ipv4/ip_forward)"
        echo "NAT rules:"
        iptables -t nat -L -v | grep -B 2 -A 2 MASQUERADE || echo "No NAT rules found"
    fi
    
    # Verify access point visibility
    echo
    verify_ap_visibility
    
    # Create a quick connection guide
    echo
    status "Creating connection guide..."
    mkdir -p ${INSTALL_DIR}/docs
    cat > ${INSTALL_DIR}/docs/connect.md << EOF
# HakPak Connection Guide

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
    success "Connection guide created at ${INSTALL_DIR}/docs/connect.md"
}

# Replace the current hostapd start process with this enhanced version
start_hostapd() {
    status "Starting hostapd access point..."
    
    # First, make sure hostapd is not running and is unmasked
    systemctl stop hostapd 2>/dev/null || true
    systemctl unmask hostapd
    
    # Enable the service for startup
    systemctl enable hostapd
    
    # Start with debug output to see what's happening
    status "Starting hostapd in debug mode briefly to diagnose any issues..."
    echo "Starting hostapd with config:"
    grep -v "#" /etc/hostapd/hostapd.conf | grep -v "^$"
    
    # Start hostapd in debug mode temporarily (will be killed shortly)
    echo "Debug output from hostapd:"
    echo "----------------------------------------------------------------------------------"
    timeout 5 hostapd -dd /etc/hostapd/hostapd.conf || true
    echo "----------------------------------------------------------------------------------"
    
    # Now start the actual service
    systemctl restart hostapd
    sleep 5
    
    # Check if hostapd is running
    if ! systemctl is-active hostapd >/dev/null 2>&1; then
        warning "Hostapd failed to start. Trying alternative approach..."
        
        # Try with different driver
        sed -i 's/^driver=nl80211/driver=nl80211\n#driver=nl80211/' /etc/hostapd/hostapd.conf
        systemctl restart hostapd
        sleep 3
        
        if ! systemctl is-active hostapd >/dev/null 2>&1; then
            warning "Hostapd still not running. Checking status..."
            systemctl status hostapd
            journalctl -xeu hostapd | tail -n 20
            
            warning "Trying one last attempt with direct execution..."
            killall hostapd 2>/dev/null || true
            hostapd -B /etc/hostapd/hostapd.conf
            sleep 3
            
            if ! pgrep hostapd >/dev/null; then
                error "Could not start hostapd after multiple attempts. Please check your WiFi hardware."
            else
                warning "Hostapd is running but not managed by systemd."
                success "Access point should be available"
            fi
        else
            success "Hostapd started successfully on second attempt"
        fi
    else
        success "Hostapd started successfully"
    fi
}

# Replace the current WiFi setup process with this more robust one
setup_wifi_ap() {
    status "Setting up Access Point on ${AP_INTERFACE}..."
    
    # Make sure WiFi is not blocked
    status "Ensuring WiFi is not blocked..."
    if rfkill list wifi | grep -q "Soft blocked: yes"; then
        rfkill unblock wifi
        success "WiFi unblocked"
    else
        success "WiFi is not blocked"
    fi
    
    # Stop any services that might interfere with the interface
    status "Preparing network interface..."
    systemctl stop NetworkManager 2>/dev/null || true
    systemctl stop wpa_supplicant 2>/dev/null || true
    ip link set ${AP_INTERFACE} down
    
    # Wait for interface to be fully down
    sleep 2
    
    # Set up interface in AP mode
    ip addr flush dev ${AP_INTERFACE} 2>/dev/null || true
    ip addr add ${IP_ADDRESS}/24 dev ${AP_INTERFACE}
    ip link set ${AP_INTERFACE} up
    
    # Wait for interface to come up
    sleep 2
    
    # Check if interface is up
    if ! ip link show ${AP_INTERFACE} | grep -q "state UP"; then
        warning "Interface ${AP_INTERFACE} is not UP. Attempting to force it up..."
        ip link set ${AP_INTERFACE} up
        sleep 2
        
        if ! ip link show ${AP_INTERFACE} | grep -q "state UP"; then
            warning "Unable to bring interface ${AP_INTERFACE} up automatically."
            warning "Interface state: $(ip link show ${AP_INTERFACE} | grep state)"
        else
            success "Interface ${AP_INTERFACE} is now UP"
        fi
    else
        success "Interface ${AP_INTERFACE} is UP"
    fi
    
    # Show current interface state
    echo "Current state of ${AP_INTERFACE}:"
    ip addr show ${AP_INTERFACE}
}

# Test hostapd configuration before starting
test_hostapd_config() {
    status "Testing hostapd configuration before starting services..."
    if ! hostapd -t /etc/hostapd/hostapd.conf; then
        warning "Hostapd configuration test failed! Troubleshooting..."
        # Show interface details
        echo "Interface details for ${AP_INTERFACE}:"
        ip link show ${AP_INTERFACE}
        iw dev ${AP_INTERFACE} info
        
        # Check if interface supports AP mode
        if ! iw list | grep -A 10 "Supported interface modes" | grep -q "AP"; then
            error "Your WiFi interface does not support AP mode. Please select a different interface."
        fi
        
        error "Cannot continue with invalid hostapd configuration."
    else
        success "Hostapd configuration is valid"
    fi
}

# Replace the current network interface setup with this:
setup_wifi_ap

# Test hostapd configuration before starting
test_hostapd_config

# Replace "status "Starting hostapd..."" and the hostapd startup code with:
start_hostapd

# At the very end of the script, before the final echo, add:
final_setup_and_verify

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}   HakPak Setup Complete!              ${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "SSID: ${YELLOW}${SSID}${NC}"
echo -e "Password: ${YELLOW}${WIFI_PASSWORD}${NC}"
echo -e "Access the web interface at ${YELLOW}http://${IP_ADDRESS}${NC}"
echo -e "Admin user: ${YELLOW}admin${NC}"
echo -e "Admin password: ${YELLOW}${ADMIN_PASSWORD}${NC}"
echo
echo -e "If you don't see the WiFi network, try rebooting:"
echo -e "${YELLOW}sudo reboot${NC}"
echo
echo -e "To check the system status after reboot, run:"
echo -e "${YELLOW}sudo systemctl status hostapd dnsmasq nginx hakpak${NC}"
echo
echo -e "To troubleshoot issues, run the health check script:"
echo -e "${YELLOW}${INSTALL_DIR}/scripts/health_check.sh${NC}"
echo
echo -e "${GREEN}========================================${NC}"

# End of script 