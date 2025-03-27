#!/bin/bash

# HakPak Complete Setup Script
# This script sets up HakPak with proper networking configuration
# allowing SSH connection to remain active while setting up the AP

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

# Check for required packages
status "Checking required packages..."
PACKAGES="hostapd dnsmasq nginx python3-pip usbutils git rfkill iw wireless-tools"
for pkg in $PACKAGES; do
    if ! dpkg -s $pkg >/dev/null 2>&1; then
        warning "$pkg not installed. Installing..."
        apt update
        apt install -y $pkg
    fi
done
success "All required packages are installed"

# Check if NetworkManager is running and controlling wlan0
status "Checking network configuration..."
if systemctl is-active NetworkManager >/dev/null 2>&1; then
    warning "NetworkManager is active and might control your wireless interfaces"
    
    # Create NetworkManager config to ignore wlan0
    status "Configuring NetworkManager to ignore wlan0 for HakPak..."
    mkdir -p /etc/NetworkManager/conf.d/
    cat > /etc/NetworkManager/conf.d/hakpak.conf << EOF
[keyfile]
unmanaged-devices=interface-name:wlan0
EOF
    check_command systemctl restart NetworkManager
    success "NetworkManager configured to ignore wlan0"
fi

# Identify primary network interface
status "Identifying primary network interface..."
if ip a | grep -q "eth0"; then
    PRIMARY_IFACE="eth0"
    success "Found Ethernet interface: eth0"
else
    # Look for the interface that has an IP (likely what SSH is using)
    SSH_IFACE=$(ip -o -4 route get 8.8.8.8 | awk '{print $5}')
    if [[ "$SSH_IFACE" == "wlan0" ]]; then
        warning "You appear to be using wlan0 for SSH. This will be reconfigured for AP mode."
        warning "This script will likely DISCONNECT your SSH session."
        read -p "Continue? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            error "Aborted by user. Please connect via Ethernet and try again."
        fi
        PRIMARY_IFACE=""
    else
        PRIMARY_IFACE="$SSH_IFACE"
        success "Using interface $PRIMARY_IFACE for internet connectivity"
    fi
fi

# Configure wlan0 for AP mode
status "Configuring wlan0 for Access Point mode..."

# Stop services that might interfere
status "Stopping network services..."
systemctl stop hostapd dnsmasq 2>/dev/null || true

# Check for processes using port 53
status "Checking for processes using port 53..."
PORT_53_PROCESS=$(lsof -i :53 | grep LISTEN | awk '{print $1}' | uniq)
if [ ! -z "$PORT_53_PROCESS" ]; then
    warning "Found $PORT_53_PROCESS using port 53. Attempting to stop..."
    if [ "$PORT_53_PROCESS" = "systemd-r" ]; then
        # Handle systemd-resolved specifically
        systemctl stop systemd-resolved
        
        # Update resolv.conf to use another DNS
        cat > /etc/resolv.conf << EOF
nameserver 8.8.8.8
nameserver 8.8.4.4
EOF
    fi
fi

# Configure hostapd
status "Configuring hostapd..."
cat > /etc/hostapd/hostapd.conf << EOF
# Basic configuration
interface=wlan0
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

success "Hostapd configured"

# Configure dnsmasq
status "Configuring dnsmasq..."
cat > /etc/dnsmasq.conf << EOF
# Interface to bind to
interface=wlan0
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
EOF

success "Dnsmasq configured"

# Configure network
status "Configuring network interfaces..."

# Add Nginx config for HakPak
status "Configuring Nginx..."
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

# Enable Nginx site
ln -sf /etc/nginx/sites-available/hakpak /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Configure network interfaces
status "Setting up wlan0 interface..."
rfkill unblock wifi
ip addr flush dev wlan0 2>/dev/null || true
ip addr add 192.168.4.1/24 dev wlan0
ip link set wlan0 up

# Set up IP forwarding and NAT if we have a primary interface
if [ ! -z "$PRIMARY_IFACE" ]; then
    status "Setting up IP forwarding and NAT..."
    echo 1 > /proc/sys/net/ipv4/ip_forward
    
    # Set up persistent IP forwarding
    if ! grep -q "net.ipv4.ip_forward=1" /etc/sysctl.conf; then
        echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
    fi
    
    # Set up NAT rules
    iptables -t nat -F
    iptables -t nat -A POSTROUTING -o $PRIMARY_IFACE -j MASQUERADE
    iptables -F
    iptables -A FORWARD -i $PRIMARY_IFACE -o wlan0 -m state --state RELATED,ESTABLISHED -j ACCEPT
    iptables -A FORWARD -i wlan0 -o $PRIMARY_IFACE -j ACCEPT
    
    # Make iptables rules persistent
    if command -v iptables-save >/dev/null 2>&1; then
        status "Making iptables rules persistent..."
        iptables-save > /etc/iptables.rules
        
        # Create a service to restore iptables rules
        cat > /etc/systemd/system/iptables-restore.service << EOF
[Unit]
Description=Restore iptables rules
After=network.target

[Service]
Type=oneshot
ExecStart=/sbin/iptables-restore /etc/iptables.rules
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
        systemctl enable iptables-restore.service
    fi
    
    success "IP forwarding and NAT configured"
else
    warning "No primary interface found for internet forwarding. HakPak will operate in standalone mode."
fi

# Start services in the correct order
status "Starting network services..."

# Test hostapd configuration
status "Testing hostapd configuration..."
if ! hostapd -t /etc/hostapd/hostapd.conf; then
    error "Hostapd configuration is invalid!"
fi

# Start hostapd
status "Starting hostapd..."
systemctl unmask hostapd
systemctl enable hostapd
systemctl restart hostapd
sleep 3

# Check if hostapd is running
if ! systemctl is-active hostapd >/dev/null 2>&1; then
    error "Failed to start hostapd. Check logs with: journalctl -xeu hostapd"
fi
success "Hostapd started successfully"

# Start dnsmasq
status "Starting dnsmasq..."
systemctl enable dnsmasq
systemctl restart dnsmasq
sleep 2

# Check if dnsmasq is running
if ! systemctl is-active dnsmasq >/dev/null 2>&1; then
    error "Failed to start dnsmasq. Check logs with: journalctl -xeu dnsmasq"
fi
success "Dnsmasq started successfully"

# Start nginx
status "Starting nginx..."
systemctl enable nginx
systemctl restart nginx

# Check if nginx is running
if ! systemctl is-active nginx >/dev/null 2>&1; then
    error "Failed to start nginx. Check logs with: journalctl -xeu nginx"
fi
success "Nginx started successfully"

# Set up HakPak service
status "Setting up HakPak service..."
cat > /etc/systemd/system/hakpak.service << EOF
[Unit]
Description=HakPak Web Service
After=network.target
Requires=hostapd.service dnsmasq.service

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

systemctl daemon-reload
systemctl enable hakpak
systemctl restart hakpak

# Check if hakpak is running
if ! systemctl is-active hakpak >/dev/null 2>&1; then
    error "Failed to start hakpak. Check logs with: journalctl -xeu hakpak"
fi
success "HakPak service started successfully"

# Verify AP mode
status "Verifying AP mode..."
if iw dev wlan0 info | grep -q "type AP"; then
    success "WiFi AP is running on wlan0"
else
    warning "WiFi AP is not correctly configured. Current state:"
    iw dev wlan0 info
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
echo -e "To check the system status, run:"
echo -e "${YELLOW}sudo systemctl status hostapd dnsmasq nginx hakpak${NC}"
echo
echo -e "${GREEN}========================================${NC}"

# End of script 