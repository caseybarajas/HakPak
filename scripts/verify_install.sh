#!/bin/bash

# Exit on error
set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "🔍 Verifying HakPak installation..."

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Please run as root${NC}"
    exit 1
fi

# Check directory structure
echo -e "${YELLOW}Checking directory structure...${NC}"
if [ -d "/opt/hakpak" ] && [ -d "/etc/hakpak" ]; then
    echo -e "${GREEN}✓ Directory structure is correct${NC}"
else
    echo -e "${RED}✗ Directory structure is incorrect${NC}"
fi

# Check if config files exist
echo -e "${YELLOW}Checking configuration files...${NC}"
if [ -f "/etc/hakpak/config.json" ] && [ -f "/etc/hostapd/hostapd.conf" ]; then
    echo -e "${GREEN}✓ Configuration files exist${NC}"
else
    echo -e "${RED}✗ Configuration files are missing${NC}"
fi

# Check if services are running
echo -e "${YELLOW}Checking services...${NC}"
if systemctl is-active --quiet hakpak; then
    echo -e "${GREEN}✓ HakPak service is running${NC}"
else
    echo -e "${RED}✗ HakPak service is not running${NC}"
fi

if systemctl is-active --quiet nginx; then
    echo -e "${GREEN}✓ Nginx service is running${NC}"
else
    echo -e "${RED}✗ Nginx service is not running${NC}"
fi

# Check hostapd and dnsmasq status with special handling for masked services
if systemctl is-enabled --quiet hostapd 2>/dev/null; then
    echo -e "${GREEN}✓ hostapd service is enabled${NC}"
elif systemctl is-masked --quiet hostapd; then
    echo -e "${RED}✗ hostapd service is masked${NC}"
else
    echo -e "${RED}✗ hostapd service is not enabled${NC}"
fi

if systemctl is-enabled --quiet dnsmasq 2>/dev/null; then
    echo -e "${GREEN}✓ dnsmasq service is enabled${NC}"
elif systemctl is-masked --quiet dnsmasq; then
    echo -e "${RED}✗ dnsmasq service is masked${NC}"
else
    echo -e "${RED}✗ dnsmasq service is not enabled${NC}"
fi

# Check if Python venv exists and has required packages
echo -e "${YELLOW}Checking Python environment...${NC}"
if [ -d "/opt/hakpak/venv" ]; then
    echo -e "${GREEN}✓ Python virtual environment exists${NC}"
    
    if /opt/hakpak/venv/bin/pip freeze | grep -q Flask; then
        echo -e "${GREEN}✓ Flask is installed${NC}"
    else
        echo -e "${RED}✗ Flask is not installed${NC}"
    fi
    
    if /opt/hakpak/venv/bin/pip freeze | grep -q pyserial; then
        echo -e "${GREEN}✓ pyserial is installed${NC}"
    else
        echo -e "${RED}✗ pyserial is not installed${NC}"
    fi
else
    echo -e "${RED}✗ Python virtual environment is missing${NC}"
fi

# Check for network interface configuration
echo -e "${YELLOW}Checking network configuration...${NC}"
if grep -q "hakpak" /etc/hostapd/hostapd.conf; then
    echo -e "${GREEN}✓ hostapd configuration contains SSID${NC}"
else
    echo -e "${RED}✗ hostapd configuration does not contain SSID${NC}"
fi

# Check for Flipper Zero
echo -e "${YELLOW}Checking for Flipper Zero...${NC}"
if [ -f "/etc/udev/rules.d/42-flipper.rules" ]; then
    echo -e "${GREEN}✓ Flipper Zero udev rules are installed${NC}"
else
    echo -e "${RED}✗ Flipper Zero udev rules are missing${NC}"
fi

if [ -e "/dev/flipper" ]; then
    echo -e "${GREEN}✓ Flipper Zero device node exists${NC}"
else
    echo -e "${YELLOW}⚠ Flipper Zero is not currently connected${NC}"
fi

# Summary
echo ""
echo "====== HakPak Verification Summary ======"
if systemctl is-active --quiet hakpak && systemctl is-active --quiet nginx; then
    echo -e "${GREEN}HakPak core services are running.${NC}"
    echo "You should be able to access the web interface at: http://hakpak.local or http://192.168.4.1"
else
    echo -e "${RED}Some HakPak services are not running.${NC}"
    echo "Please run: sudo systemctl status hakpak to check for errors."
fi

echo ""
echo "To restart all HakPak services, run:"
echo "sudo systemctl restart hakpak nginx hostapd dnsmasq"
echo ""
echo "To view HakPak logs, run:"
echo "sudo journalctl -u hakpak -f" 