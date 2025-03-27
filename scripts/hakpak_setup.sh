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

# Detect wireless interfaces
status "Scanning for wireless interfaces..."
WIFI_INTERFACES=($(iw dev | grep Interface | awk '{print $2}'))

if [ ${#WIFI_INTERFACES[@]} -eq 0 ]; then
    error "No wireless interfaces found. Please check your hardware."
fi

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
status "Gathering system information..."

# Available wireless interfaces
if [ ${#WIFI_INTERFACES[@]} -gt 1 ]; then
    echo "Multiple wireless interfaces detected:"
    for i in "${!WIFI_INTERFACES[@]}"; do
        echo "  $((i+1))). ${WIFI_INTERFACES[$i]}"
    done
    
    # Select wireless interface for AP
    select_option "Which wireless interface should be used for the access point?" "${WIFI_INTERFACES[@]}"
    AP_INTERFACE_INDEX=$?
    AP_INTERFACE=${WIFI_INTERFACES[$AP_INTERFACE_INDEX]}
else
    AP_INTERFACE=${WIFI_INTERFACES[0]}
    echo "Using ${AP_INTERFACE} for Access Point mode (only interface available)"
fi

# Identify primary network interface for internet connection
if ip a | grep -q "eth0"; then
    DEFAULT_INTERNET_IFACE="eth0"
    echo "Ethernet interface (eth0) detected"
else
    # Look for the interface that has an IP (likely what SSH is using)
    SSH_IFACE=$(ip -o -4 route get 8.8.8.8 2>/dev/null | awk '{print $5}')
    if [ -n "$SSH_IFACE" ] && [ "$SSH_IFACE" != "$AP_INTERFACE" ]; then
        DEFAULT_INTERNET_IFACE="$SSH_IFACE"
        echo "Network interface $SSH_IFACE detected"
    else
        DEFAULT_INTERNET_IFACE=""
    fi
fi

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

# Prompt for channel
echo "Available WiFi channels: 1, 6, 11 (recommended for 2.4GHz)"
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
if confirm "Enable internet sharing/routing to connected devices?" "Y"; then
    ENABLE_INTERNET_SHARING=true
    
    if [ -n "$DEFAULT_INTERNET_IFACE" ]; then
        echo "Internet connection interface detected: $DEFAULT_INTERNET_IFACE"
        INTERNET_IFACE="$DEFAULT_INTERNET_IFACE"
    else
        INTERNET_IFACE=$(prompt_string "Interface for internet connection" "")
        if [ -z "$INTERNET_IFACE" ]; then
            warning "No internet interface specified. Internet sharing will be disabled."
            ENABLE_INTERNET_SHARING=false
        fi
    fi
else
    ENABLE_INTERNET_SHARING=false
fi

# Prompt for custom DNS servers
if confirm "Use custom DNS servers?" "N"; then
    USE_CUSTOM_DNS=true
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
    echo -e "Custom DNS: ${RED}Disabled${NC} (Using default)"
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
rfkill unblock wifi
ip addr flush dev ${AP_INTERFACE} 2>/dev/null || true
ip addr add ${IP_ADDRESS}/24 dev ${AP_INTERFACE}
ip link set ${AP_INTERFACE} up

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
status "Starting hostapd..."
systemctl restart hostapd
sleep 5  # Give hostapd time to initialize properly

# Check if hostapd is running
if ! systemctl is-active hostapd >/dev/null 2>&1; then
    warning "Hostapd failed to start. Checking the configuration..."
    hostapd -dd /etc/hostapd/hostapd.conf &
    HOSTAPD_PID=$!
    sleep 3
    kill $HOSTAPD_PID 2>/dev/null || true
    systemctl restart hostapd
    sleep 2
    
    if ! systemctl is-active hostapd >/dev/null 2>&1; then
        warning "Hostapd still not running. Check logs with: journalctl -xeu hostapd"
    else
        success "Hostapd started successfully on second attempt"
    fi
else
    success "Hostapd started successfully"
fi

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