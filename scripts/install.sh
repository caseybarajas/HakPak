#!/bin/bash

# Exit on error
set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}🔐 Installing HakPak - Portable Pentesting Platform...${NC}"

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

# Create necessary directories
echo -e "${YELLOW}Creating directories...${NC}"
mkdir -p /etc/hakpak
mkdir -p /var/log/hakpak
mkdir -p /opt/hakpak
mkdir -p /opt/hakpak/data/flipper/{ir,rfid,subghz,nfc,ibutton}

# Backup existing configuration if any
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

# Install system dependencies
echo -e "${YELLOW}Installing system dependencies...${NC}"
apt-get update
apt-get install -y \
    python3 \
    python3-pip \
    python3-venv \
    nginx \
    hostapd \
    dnsmasq \
    usbutils \
    git \
    rfkill \
    iw \
    wireless-tools

# Check WiFi adapter
echo -e "${YELLOW}Checking WiFi adapter...${NC}"
if ! iw dev | grep -q Interface; then
    echo -e "${RED}No WiFi interfaces found. Please check your hardware.${NC}"
    echo -e "${YELLOW}Continuing installation without WiFi configuration...${NC}"
    SKIP_WIFI=true
else
    WIFI_INTERFACE=$(iw dev | grep Interface | head -1 | awk '{print $2}')
    echo -e "${GREEN}Found WiFi interface: ${WIFI_INTERFACE}${NC}"
    
    # Unblock WiFi if blocked
    echo -e "${YELLOW}Ensuring WiFi is unblocked...${NC}"
    rfkill unblock wifi
    
    SKIP_WIFI=false
fi

# Create Python virtual environment
echo -e "${YELLOW}Setting up Python environment...${NC}"
python3 -m venv /opt/hakpak/venv
source /opt/hakpak/venv/bin/activate

# Install Python dependencies
echo -e "${YELLOW}Installing Python dependencies...${NC}"
pip install --upgrade pip
pip install -r requirements.txt

# Copy application files
echo -e "${YELLOW}Installing HakPak application...${NC}"
mkdir -p /opt/hakpak/app
mkdir -p /opt/hakpak/config
mkdir -p /opt/hakpak/scripts
mkdir -p /opt/hakpak/flipper_integration

cp -r app/* /opt/hakpak/app/
cp -r flipper_integration/* /opt/hakpak/flipper_integration/
cp -r scripts/* /opt/hakpak/scripts/
cp wsgi.py /opt/hakpak/
cp config/hakpak.service /etc/systemd/system/
cp config/nginx-hakpak /etc/nginx/sites-available/hakpak

# Configure Nginx
echo -e "${YELLOW}Configuring Nginx...${NC}"
ln -sf /etc/nginx/sites-available/hakpak /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Configure WiFi Access Point if not skipped
if [ "$SKIP_WIFI" = false ]; then
    echo -e "${YELLOW}Configuring WiFi Access Point...${NC}"
    
    # Update hostapd configuration with detected interface
    sed "s/interface=wlan0/interface=${WIFI_INTERFACE}/g" config/hostapd.conf > /etc/hostapd/hostapd.conf
    
    # Update dnsmasq configuration with detected interface
    sed "s/interface=wlan0/interface=${WIFI_INTERFACE}/g" config/dnsmasq.conf > /etc/dnsmasq.conf
    
    # Update network interfaces configuration
    sed "s/wlan0/${WIFI_INTERFACE}/g" config/interfaces > /etc/network/interfaces
    
    # Configure hostapd to use our config file
    echo -e "${YELLOW}Configuring hostapd defaults...${NC}"
    sed -i 's|#DAEMON_CONF=""|DAEMON_CONF="/etc/hostapd/hostapd.conf"|' /etc/default/hostapd
    
    # Test hostapd configuration
    echo -e "${YELLOW}Testing hostapd configuration...${NC}"
    if hostapd -t /etc/hostapd/hostapd.conf; then
        echo -e "${GREEN}Hostapd configuration is valid${NC}"
    else
        echo -e "${RED}Hostapd configuration is invalid. Please check /etc/hostapd/hostapd.conf${NC}"
        # Don't exit, continue with installation
    fi
else
    echo -e "${YELLOW}Skipping WiFi Access Point configuration due to missing WiFi adapter${NC}"
fi

# Set up Flipper Zero udev rules
echo -e "${YELLOW}Setting up Flipper Zero udev rules...${NC}"
cat > /etc/udev/rules.d/42-flipper.rules << EOF
SUBSYSTEM=="tty", ATTRS{idVendor}=="0483", ATTRS{idProduct}=="5740", SYMLINK+="flipper"
EOF

# Reload udev rules
echo -e "${YELLOW}Reloading udev rules...${NC}"
udevadm control --reload-rules
udevadm trigger

# Create default configuration
echo -e "${YELLOW}Creating default configuration...${NC}"
cat > /etc/hakpak/config.json << EOF
{
    "wifi": {
        "ssid": "hakpak",
        "password": "pentestallthethings",
        "channel": 6
    },
    "flipper": {
        "port": "/dev/flipper",
        "baudrate": 115200
    },
    "web": {
        "host": "0.0.0.0",
        "port": 5000
    }
}
EOF

# Set permissions
echo -e "${YELLOW}Setting permissions...${NC}"
chown -R root:root /opt/hakpak
chmod -R 755 /opt/hakpak
chmod +x /opt/hakpak/scripts/*.sh

# Enable and start services
echo -e "${YELLOW}Enabling services...${NC}"
systemctl daemon-reload

# Unmask and enable services
echo -e "${YELLOW}Unmasking services...${NC}"
systemctl unmask hostapd 2>/dev/null || true
systemctl unmask dnsmasq 2>/dev/null || true
systemctl enable hakpak
systemctl enable nginx

if [ "$SKIP_WIFI" = false ]; then
    systemctl enable hostapd
    systemctl enable dnsmasq
fi

# Starting services one by one with proper logging
echo -e "${YELLOW}Starting services...${NC}"

# Start nginx first
echo -e "${YELLOW}Starting nginx...${NC}"
if systemctl start nginx; then
    echo -e "${GREEN}Nginx started successfully${NC}"
else
    echo -e "${RED}Failed to start nginx${NC}"
    systemctl status nginx
fi

# Start hakpak service
echo -e "${YELLOW}Starting hakpak...${NC}"
if systemctl start hakpak; then
    echo -e "${GREEN}HakPak service started successfully${NC}"
else
    echo -e "${RED}Failed to start HakPak service${NC}"
    systemctl status hakpak
fi

if [ "$SKIP_WIFI" = false ]; then
    # Start hostapd and dnsmasq services separately
    echo -e "${YELLOW}Starting hostapd...${NC}"
    if systemctl start hostapd; then
        echo -e "${GREEN}Hostapd started successfully${NC}"
    else
        echo -e "${RED}Failed to start hostapd${NC}"
        systemctl status hostapd
    fi
    
    echo -e "${YELLOW}Starting dnsmasq...${NC}"
    if systemctl start dnsmasq; then
        echo -e "${GREEN}Dnsmasq started successfully${NC}"
    else
        echo -e "${RED}Failed to start dnsmasq${NC}"
        systemctl status dnsmasq
    fi
fi

echo -e "${GREEN}✅ HakPak installation complete!${NC}"

if [ "$SKIP_WIFI" = false ]; then
    echo -e "${GREEN}Access the web interface at http://hakpak.local or http://192.168.4.1${NC}"
    echo -e "${GREEN}Default WiFi SSID: hakpak${NC}"
    echo -e "${GREEN}Default WiFi Password: pentestallthethings${NC}"
else
    echo -e "${YELLOW}No WiFi configuration was performed due to missing WiFi adapter.${NC}"
    echo -e "${YELLOW}You can access the web interface at http://localhost:5000 or via the device IP address.${NC}"
fi

echo ""
echo -e "${YELLOW}It is recommended to reboot your system to ensure all services are properly started:${NC}"
echo -e "${YELLOW}sudo reboot${NC}" 