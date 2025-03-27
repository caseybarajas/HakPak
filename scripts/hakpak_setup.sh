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
echo -e "${BLUE}   HakPak Complete Setup Script        ${NC}"
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

# Function to check if command succeeds
check_command() {
    if ! $@; then
        error "Command failed: $@"
    fi
}

# Create backup directory
BACKUP_DIR="/opt/hakpak/backups/$(date +%Y%m%d%H%M%S)"
mkdir -p $BACKUP_DIR

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

# Detect wireless interfaces
status "Detecting wireless interfaces..."
WIFI_INTERFACES=($(iw dev | grep Interface | awk '{print $2}'))

if [ ${#WIFI_INTERFACES[@]} -eq 0 ]; then
    error "No wireless interfaces found. Please check your hardware."
fi

# Select wireless interface for AP
if [ ${#WIFI_INTERFACES[@]} -gt 1 ]; then
    status "Multiple wireless interfaces found:"
    for i in "${!WIFI_INTERFACES[@]}"; do
        echo "$i: ${WIFI_INTERFACES[$i]}"
    done
    
    AP_INTERFACE=${WIFI_INTERFACES[0]}
    status "Using ${AP_INTERFACE} for Access Point mode. To use a different interface, edit hostapd.conf manually."
else
    AP_INTERFACE=${WIFI_INTERFACES[0]}
    status "Using ${AP_INTERFACE} for Access Point mode"
fi

# Identify primary network interface for internet connection
status "Identifying primary network interface..."
if ip a | grep -q "eth0"; then
    PRIMARY_IFACE="eth0"
    success "Found Ethernet interface: eth0"
else
    # Look for the interface that has an IP (likely what SSH is using)
    SSH_IFACE=$(ip -o -4 route get 8.8.8.8 2>/dev/null | awk '{print $5}')
    
    # If SSH interface is the same as AP interface, warn user
    if [[ "$SSH_IFACE" == "$AP_INTERFACE" ]]; then
        warning "You appear to be using $AP_INTERFACE for network connectivity."
        warning "Setting up the access point may disconnect your SSH session."
        warning "If disconnected, connect to the 'hakpak' WiFi network with password 'pentestallthethings'"
        warning "and access the Pi at 192.168.4.1"
    else
        PRIMARY_IFACE="$SSH_IFACE"
        success "Using interface $PRIMARY_IFACE for internet connectivity"
    fi
fi

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
ssid=hakpak
hw_mode=g
channel=6
country_code=US

# 802.11n support
ieee80211n=1
ht_capab=[HT40][SHORT-GI-20][DSSS_CCK-40]

# Security settings
auth_algs=1
wpa=2
wpa_passphrase=pentestallthethings
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

# Configure dnsmasq
status "Configuring dnsmasq..."
cat > /etc/dnsmasq.conf << EOF
# Interface to bind to
interface=${AP_INTERFACE}
bind-interfaces
except-interface=lo
no-dhcp-interface=lo

# DHCP range and lease time
dhcp-range=192.168.4.2,192.168.4.100,255.255.255.0,24h

# Default gateway and DNS servers
dhcp-option=option:router,192.168.4.1
dhcp-option=option:dns-server,192.168.4.1
dhcp-option=option:netmask,255.255.255.0

# Domain name
domain=hakpak.local
expand-hosts
local=/hakpak.local/
address=/hakpak.local/192.168.4.1

# Listen only on specific addresses
listen-address=127.0.0.1,192.168.4.1

# DNS options
domain-needed
bogus-priv
no-resolv
no-poll

# External DNS servers
server=8.8.8.8
server=8.8.4.4

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
    
    root /var/www/hakpak/public;
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
mkdir -p /var/www/hakpak/public
echo "<html><body><h1>HakPak</h1><p>If you see this page, Nginx is running but the HakPak application is not.</p></body></html>" > /var/www/hakpak/public/index.html

# Enable Nginx site
mkdir -p /etc/nginx/sites-enabled/
ln -sf /etc/nginx/sites-available/hakpak /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Configure network interfaces
status "Setting up ${AP_INTERFACE} interface..."
rfkill unblock wifi
ip addr flush dev ${AP_INTERFACE} 2>/dev/null || true
ip addr add 192.168.4.1/24 dev ${AP_INTERFACE}
ip link set ${AP_INTERFACE} up

# Set up IP forwarding and NAT if we have a primary interface
if [ ! -z "$PRIMARY_IFACE" ] && [ "$PRIMARY_IFACE" != "$AP_INTERFACE" ]; then
    status "Setting up IP forwarding and NAT for internet sharing..."
    echo 1 > /proc/sys/net/ipv4/ip_forward
    
    # Set up persistent IP forwarding
    if ! grep -q "net.ipv4.ip_forward=1" /etc/sysctl.conf; then
        echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
    fi
    
    # Set up NAT rules
    iptables -t nat -F
    iptables -t nat -A POSTROUTING -o $PRIMARY_IFACE -j MASQUERADE
    iptables -F
    iptables -A FORWARD -i $PRIMARY_IFACE -o ${AP_INTERFACE} -m state --state RELATED,ESTABLISHED -j ACCEPT
    iptables -A FORWARD -i ${AP_INTERFACE} -o $PRIMARY_IFACE -j ACCEPT
    
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
    status "No separate interface found for internet sharing."
    status "HakPak will operate in standalone mode."
fi

# Set up HakPak application
status "Setting up HakPak application..."

# Create HakPak directories
mkdir -p /opt/hakpak
mkdir -p /opt/hakpak/data
mkdir -p /opt/hakpak/logs

# Set up Python environment if it doesn't exist
if [ ! -d "/opt/hakpak/venv" ]; then
    status "Creating Python virtual environment..."
    python3 -m venv /opt/hakpak/venv
fi

# Copy application files
status "Copying application files..."
cp -r ./* /opt/hakpak/ 2>/dev/null || true

# Install Python dependencies
status "Installing Python dependencies..."
/opt/hakpak/venv/bin/pip install --upgrade pip
if [ -f "/opt/hakpak/requirements.txt" ]; then
    /opt/hakpak/venv/bin/pip install -r /opt/hakpak/requirements.txt
else
    warning "requirements.txt not found. Python dependencies may be incomplete."
    /opt/hakpak/venv/bin/pip install Flask Flask-SocketIO gunicorn eventlet pyserial RPi.GPIO gpiozero python-dotenv requests
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
ExecStart=/opt/hakpak/venv/bin/gunicorn --worker-class eventlet -w 1 --bind 127.0.0.1:5000 app:app
WorkingDirectory=/opt/hakpak
User=root
Group=root
Restart=always
RestartSec=5
Environment=PYTHONUNBUFFERED=1

[Install]
WantedBy=multi-user.target
EOF

# Set appropriate permissions
status "Setting permissions..."
chown -R root:root /opt/hakpak
chmod -R 755 /opt/hakpak
find /opt/hakpak/scripts -type f -name "*.sh" -exec chmod +x {} \;

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
dhcp-range=192.168.4.2,192.168.4.100,255.255.255.0,24h
dhcp-option=option:router,192.168.4.1
dhcp-option=option:dns-server,8.8.8.8,8.8.4.4
listen-address=127.0.0.1,192.168.4.1
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
echo -e "SSID: ${YELLOW}hakpak${NC}"
echo -e "Password: ${YELLOW}pentestallthethings${NC}"
echo -e "Access the web interface at ${YELLOW}http://192.168.4.1${NC}"
echo
echo -e "If you don't see the WiFi network, try rebooting:"
echo -e "${YELLOW}sudo reboot${NC}"
echo
echo -e "To check the system status after reboot, run:"
echo -e "${YELLOW}sudo systemctl status hostapd dnsmasq nginx hakpak${NC}"
echo
echo -e "To troubleshoot issues, run the health check script:"
echo -e "${YELLOW}sudo ./scripts/health_check.sh${NC}"
echo
echo -e "${GREEN}========================================${NC}"

# End of script 