#!/bin/bash

# Exit on error
set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}🔧 Setting up HakPak WiFi Access Point...${NC}"

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Please run as root${NC}"
    exit 1
fi

# Function to handle errors
handle_error() {
    echo -e "${RED}Error occurred at line $1${NC}"
    exit 1
}

# Set trap for error handling
trap 'handle_error $LINENO' ERR

# Install required packages if not already installed
echo -e "${YELLOW}Installing required packages...${NC}"
apt-get update
apt-get install -y hostapd dnsmasq rfkill iw wireless-tools

# Check WiFi adapter
echo -e "${YELLOW}Checking WiFi adapter...${NC}"
if ! iw dev | grep -q Interface; then
    echo -e "${RED}No WiFi interfaces found. Please check your hardware.${NC}"
    exit 1
fi

# Get the WiFi interface name
WIFI_INTERFACE=$(iw dev | grep Interface | head -1 | awk '{print $2}')
echo -e "${GREEN}Found WiFi interface: ${WIFI_INTERFACE}${NC}"

# Check if the interface supports AP mode
echo -e "${YELLOW}Checking if ${WIFI_INTERFACE} supports AP mode...${NC}"
if ! iw list | grep -q "AP"; then
    echo -e "${RED}Your WiFi adapter does not support AP mode. Please use a compatible adapter.${NC}"
    exit 1
fi

# Ensure WiFi is not blocked
echo -e "${YELLOW}Ensuring WiFi is unblocked...${NC}"
rfkill unblock wifi

# Stop services if running
echo -e "${YELLOW}Stopping services...${NC}"
systemctl stop hostapd || true
systemctl stop dnsmasq || true

# Backup existing configuration
echo -e "${YELLOW}Backing up existing configuration...${NC}"
if [ -f /etc/network/interfaces ]; then
    cp /etc/network/interfaces /etc/network/interfaces.backup.$(date +%Y%m%d%H%M%S)
    echo -e "${GREEN}Network interfaces backed up${NC}"
fi

if [ -f /etc/hostapd/hostapd.conf ]; then
    cp /etc/hostapd/hostapd.conf /etc/hostapd/hostapd.conf.backup.$(date +%Y%m%d%H%M%S)
    echo -e "${GREEN}Hostapd configuration backed up${NC}"
fi

if [ -f /etc/dnsmasq.conf ]; then
    cp /etc/dnsmasq.conf /etc/dnsmasq.conf.backup.$(date +%Y%m%d%H%M%S)
    echo -e "${GREEN}Dnsmasq configuration backed up${NC}"
fi

# Create hostapd configuration
echo -e "${YELLOW}Creating hostapd configuration...${NC}"
cat > /etc/hostapd/hostapd.conf << EOF
# Basic configuration
interface=${WIFI_INTERFACE}
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
ieee80211w=1
group_mgmt_cipher=AES-128-CMAC

# Reduce interference
noscan=1
EOF

# Configure hostapd to use our config file
echo -e "${YELLOW}Configuring hostapd defaults...${NC}"
sed -i 's|#DAEMON_CONF=""|DAEMON_CONF="/etc/hostapd/hostapd.conf"|' /etc/default/hostapd

# Create dnsmasq configuration
echo -e "${YELLOW}Creating dnsmasq configuration...${NC}"
cat > /etc/dnsmasq.conf << EOF
# Interface to bind to
interface=${WIFI_INTERFACE}
bind-interfaces

# DHCP range and lease time
dhcp-range=192.168.4.2,192.168.4.100,255.255.255.0,24h

# Default gateway and DNS servers
dhcp-option=option:router,192.168.4.1
dhcp-option=option:dns-server,192.168.4.1
dhcp-option=option:netmask,255.255.255.0

# External DNS servers
server=8.8.8.8
server=8.8.4.4

# Domain name
domain=hakpak.local
expand-hosts
local=/hakpak.local/
address=/hakpak.local/192.168.4.1

# Logging
log-queries
log-dhcp
log-facility=/var/log/dnsmasq.log

# Listen on specific addresses
listen-address=127.0.0.1,192.168.4.1

# Cache size
cache-size=1000

# DNS options
domain-needed
bogus-priv
no-resolv
no-poll

# DHCP options
dhcp-authoritative
dhcp-leasefile=/var/lib/misc/dnsmasq.leases

# Speed up DHCP by sending replies immediately
dhcp-rapid-commit
EOF

# Create network interfaces configuration
echo -e "${YELLOW}Creating network interfaces configuration...${NC}"
cat > /etc/network/interfaces << EOF
# The loopback network interface
auto lo
iface lo inet loopback

# The primary network interface (wired)
allow-hotplug eth0
iface eth0 inet dhcp

# HakPak WiFi Access Point
allow-hotplug ${WIFI_INTERFACE}
iface ${WIFI_INTERFACE} inet static
    address 192.168.4.1
    netmask 255.255.255.0
    network 192.168.4.0
    broadcast 192.168.4.255
    
    # Enable IP forwarding from wlan0 to eth0
    post-up echo 1 > /proc/sys/net/ipv4/ip_forward
    
    # NAT configuration
    post-up iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
    post-up iptables -A FORWARD -i eth0 -o ${WIFI_INTERFACE} -m state --state RELATED,ESTABLISHED -j ACCEPT
    post-up iptables -A FORWARD -i ${WIFI_INTERFACE} -o eth0 -j ACCEPT
    
    # Cleanup when interface goes down
    post-down echo 0 > /proc/sys/net/ipv4/ip_forward
    post-down iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE
    post-down iptables -D FORWARD -i eth0 -o ${WIFI_INTERFACE} -m state --state RELATED,ESTABLISHED -j ACCEPT
    post-down iptables -D FORWARD -i ${WIFI_INTERFACE} -o eth0 -j ACCEPT
    
    # Ensure interface stays up even if connection fails
    post-up ip link set dev ${WIFI_INTERFACE} up
EOF

# Test hostapd configuration
echo -e "${YELLOW}Testing hostapd configuration...${NC}"
if hostapd -t /etc/hostapd/hostapd.conf; then
    echo -e "${GREEN}Hostapd configuration is valid${NC}"
else
    echo -e "${RED}Hostapd configuration is invalid. Please check /etc/hostapd/hostapd.conf${NC}"
    exit 1
fi

# Enable services
echo -e "${YELLOW}Enabling services...${NC}"
systemctl unmask hostapd 2>/dev/null || true
systemctl unmask dnsmasq 2>/dev/null || true
systemctl enable hostapd
systemctl enable dnsmasq

# Configure the interface immediately without rebooting
echo -e "${YELLOW}Configuring the interface...${NC}"
ip addr flush dev ${WIFI_INTERFACE}
ip addr add 192.168.4.1/24 dev ${WIFI_INTERFACE}
ip link set ${WIFI_INTERFACE} up

# Start services
echo -e "${YELLOW}Starting services...${NC}"
systemctl restart hostapd
systemctl restart dnsmasq

# Verify services are running
echo -e "${YELLOW}Verifying services...${NC}"
if systemctl is-active --quiet hostapd; then
    echo -e "${GREEN}Hostapd is running${NC}"
else
    echo -e "${RED}Hostapd failed to start${NC}"
    systemctl status hostapd
fi

if systemctl is-active --quiet dnsmasq; then
    echo -e "${GREEN}Dnsmasq is running${NC}"
else
    echo -e "${RED}Dnsmasq failed to start${NC}"
    systemctl status dnsmasq
fi

# Check if the AP is visible
echo -e "${YELLOW}Checking if AP is visible...${NC}"
if iw dev ${WIFI_INTERFACE} info | grep -q "type AP"; then
    echo -e "${GREEN}AP is set up correctly on ${WIFI_INTERFACE}${NC}"
else
    echo -e "${RED}AP setup failed on ${WIFI_INTERFACE}${NC}"
    iw dev ${WIFI_INTERFACE} info
fi

echo -e "${GREEN}✅ WiFi Access Point setup complete!${NC}"
echo -e "${GREEN}SSID: hakpak${NC}"
echo -e "${GREEN}Password: pentestallthethings${NC}"
echo -e "${GREEN}IP Address: 192.168.4.1${NC}"
echo -e "${YELLOW}Note: It may take a few seconds for the access point to become visible.${NC}"
echo -e "${YELLOW}If you're still having issues, try rebooting the system:${NC}"
echo -e "${YELLOW}sudo reboot${NC}" 