#!/bin/bash

# Exit on error
set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}🔧 Fixing HakPak Network Issues...${NC}"

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Please run as root${NC}"
    exit 1
fi

# Stop all network services
echo -e "${YELLOW}Stopping services...${NC}"
systemctl stop dnsmasq || true
systemctl stop hostapd || true

# Check for and kill any conflicting processes
echo -e "${YELLOW}Checking for conflicting processes...${NC}"
if pgrep dnsmasq; then
    echo -e "${YELLOW}Killing existing dnsmasq processes...${NC}"
    pkill dnsmasq || true
    sleep 1
fi

# Configure network interface
echo -e "${YELLOW}Configuring wlan0 interface...${NC}"
ip addr flush dev wlan0
ip addr add 192.168.4.1/24 dev wlan0
ip link set wlan0 up
echo -e "${GREEN}Interface wlan0 configured with IP 192.168.4.1${NC}"

# Enable IP forwarding
echo -e "${YELLOW}Enabling IP forwarding...${NC}"
echo 1 > /proc/sys/net/ipv4/ip_forward

# Set up iptables rules
echo -e "${YELLOW}Setting up iptables rules...${NC}"
iptables -t nat -F POSTROUTING
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
iptables -F FORWARD
iptables -A FORWARD -i eth0 -o wlan0 -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i wlan0 -o eth0 -j ACCEPT

# Start hostapd first
echo -e "${YELLOW}Starting hostapd...${NC}"
systemctl start hostapd
sleep 2  # Give hostapd time to initialize

# Check if hostapd is running
if systemctl is-active --quiet hostapd; then
    echo -e "${GREEN}✓ hostapd is running${NC}"
else
    echo -e "${RED}✗ hostapd failed to start${NC}"
    systemctl status hostapd
    exit 1
fi

# Start dnsmasq
echo -e "${YELLOW}Starting dnsmasq...${NC}"
systemctl start dnsmasq

# Check if dnsmasq is running
if systemctl is-active --quiet dnsmasq; then
    echo -e "${GREEN}✓ dnsmasq is running${NC}"
else
    echo -e "${RED}✗ dnsmasq failed to start${NC}"
    systemctl status dnsmasq
    
    # Try to diagnose the issue
    echo -e "${YELLOW}Attempting to diagnose dnsmasq issues...${NC}"
    journalctl -u dnsmasq -n 20
    
    echo -e "${YELLOW}Checking if another service is using port 53...${NC}"
    netstat -tulpn | grep ":53 "
    
    echo -e "${YELLOW}Trying to start dnsmasq manually...${NC}"
    dnsmasq --test
    
    exit 1
fi

# Start other services
echo -e "${YELLOW}Starting nginx...${NC}"
systemctl start nginx

echo -e "${YELLOW}Starting hakpak...${NC}"
systemctl start hakpak

echo -e "${GREEN}✅ Network services are now running!${NC}"
echo -e "${GREEN}SSID: hakpak${NC}"
echo -e "${GREEN}Password: pentestallthethings${NC}"
echo -e "${GREEN}Access the web interface at http://192.168.4.1${NC}"

# Check if AP is visible
echo -e "${YELLOW}Checking if AP is visible...${NC}"
if iw dev wlan0 info | grep -q "type AP"; then
    echo -e "${GREEN}✓ WiFi AP is running on wlan0${NC}"
else
    echo -e "${RED}✗ WiFi AP is not running on wlan0${NC}"
    iw dev wlan0 info
fi 