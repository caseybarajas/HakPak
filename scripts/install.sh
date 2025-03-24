#!/bin/bash

# HakPak Installation Script
# This script sets up the HakPak Portable Pentesting Platform

# Colors for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Installation directory
INSTALL_DIR="/opt/hakpak"

echo -e "${GREEN}===== HakPak Installation =====${NC}"
echo -e "This script will install the HakPak Portable Pentesting Platform"
echo ""

# Check for root privileges
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}This script must be run as root${NC}"
    exit 1
fi

# Function to install required packages
install_dependencies() {
    echo -e "${YELLOW}Installing required packages...${NC}"
    
    apt-get update
    apt-get install -y \
        python3 \
        python3-pip \
        git \
        nginx \
        hostapd \
        dnsmasq \
        bluez \
        kali-tools-wireless \
        kali-tools-bluetooth \
        kali-tools-web \
        kali-tools-sniffing-spoofing \
        python3-dev \
        python3-setuptools \
        libffi-dev \
        libssl-dev
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to install packages${NC}"
        return 1
    fi
    
    echo -e "${GREEN}Packages installed successfully${NC}"
    return 0
}

# Function to install Python requirements
install_python_requirements() {
    echo -e "${YELLOW}Installing Python requirements...${NC}"
    
    pip3 install -r "${INSTALL_DIR}/requirements.txt"
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to install Python requirements${NC}"
        return 1
    fi
    
    echo -e "${GREEN}Python requirements installed successfully${NC}"
    return 0
}

# Function to install HakPak
install_hakpak() {
    echo -e "${YELLOW}Installing HakPak to ${INSTALL_DIR}...${NC}"
    
    # Create installation directory if it doesn't exist
    mkdir -p "${INSTALL_DIR}"
    
    # Check if this script is running from the HakPak directory
    if [ -f "wsgi.py" ] && [ -d "app" ]; then
        echo -e "${YELLOW}Installing from current directory...${NC}"
        
        # Copy files to installation directory
        cp -r app config scripts flipper_integration requirements.txt wsgi.py "${INSTALL_DIR}/"
        
        if [ $? -ne 0 ]; then
            echo -e "${RED}Failed to copy files${NC}"
            return 1
        fi
    else
        echo -e "${YELLOW}Cloning from GitHub...${NC}"
        
        # Clone repository
        git clone https://github.com/caseybarajas/hakpak.git "${INSTALL_DIR}"
        
        if [ $? -ne 0 ]; then
            echo -e "${RED}Failed to clone repository${NC}"
            return 1
        fi
    fi
    
    # Set permissions
    chown -R kali:kali "${INSTALL_DIR}"
    chmod -R 755 "${INSTALL_DIR}"
    chmod +x "${INSTALL_DIR}/scripts"/*.sh
    
    echo -e "${GREEN}HakPak installed to ${INSTALL_DIR}${NC}"
    return 0
}

# Function to configure services
configure_services() {
    echo -e "${YELLOW}Configuring services...${NC}"
    
    # Install systemd service
    cp "${INSTALL_DIR}/config/hakpak.service" /etc/systemd/system/
    
    # Enable service
    systemctl daemon-reload
    systemctl enable hakpak.service
    
    # Configure Nginx
    cp "${INSTALL_DIR}/config/nginx-hakpak" /etc/nginx/sites-available/
    ln -sf /etc/nginx/sites-available/nginx-hakpak /etc/nginx/sites-enabled/
    
    # Remove default site if it exists
    if [ -f "/etc/nginx/sites-enabled/default" ]; then
        rm /etc/nginx/sites-enabled/default
    fi
    
    # Restart Nginx
    systemctl restart nginx
    
    # Configure hostapd for access point
    echo -e "${YELLOW}Configuring WiFi access point...${NC}"
    
    cat > /etc/hostapd/hostapd.conf << EOF
interface=wlan0
driver=nl80211
ssid=hakpak
hw_mode=g
channel=6
wmm_enabled=0
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
wpa=2
wpa_passphrase=pentestallthethings
wpa_key_mgmt=WPA-PSK
wpa_pairwise=TKIP
rsn_pairwise=CCMP
EOF
    
    # Configure hostapd to use config file
    sed -i 's|#DAEMON_CONF=""|DAEMON_CONF="/etc/hostapd/hostapd.conf"|' /etc/default/hostapd
    
    # Configure dnsmasq for DHCP
    cat > /etc/dnsmasq.conf << EOF
interface=wlan0
dhcp-range=192.168.4.2,192.168.4.20,255.255.255.0,24h
dhcp-option=3,192.168.4.1
dhcp-option=6,192.168.4.1
server=8.8.8.8
log-queries
log-dhcp
listen-address=127.0.0.1
EOF
    
    # Configure networking
    cat >> /etc/network/interfaces << EOF

# HakPak Access Point
allow-hotplug wlan0
iface wlan0 inet static
    address 192.168.4.1
    netmask 255.255.255.0
EOF
    
    echo -e "${GREEN}Services configured successfully${NC}"
    return 0
}

# Main installation process
echo -e "${YELLOW}Starting installation...${NC}"

# Install dependencies
if install_dependencies; then
    echo -e "${GREEN}Dependencies installed successfully${NC}"
else
    echo -e "${RED}Failed to install dependencies${NC}"
    exit 1
fi

# Install HakPak
if install_hakpak; then
    echo -e "${GREEN}HakPak installed successfully${NC}"
else
    echo -e "${RED}Failed to install HakPak${NC}"
    exit 1
fi

# Install Python requirements
if install_python_requirements; then
    echo -e "${GREEN}Python requirements installed successfully${NC}"
else
    echo -e "${RED}Failed to install Python requirements${NC}"
    exit 1
fi

# Configure services
if configure_services; then
    echo -e "${GREEN}Services configured successfully${NC}"
else
    echo -e "${RED}Failed to configure services${NC}"
    exit 1
fi

# Setup Flipper Zero if available
echo -e "${YELLOW}Setting up Flipper Zero...${NC}"
if "${INSTALL_DIR}/scripts/setup_flipper.sh"; then
    echo -e "${GREEN}Flipper Zero setup complete${NC}"
else
    echo -e "${YELLOW}Flipper Zero setup skipped or failed${NC}"
    echo -e "${YELLOW}You can run the Flipper Zero setup later with: sudo ${INSTALL_DIR}/scripts/setup_flipper.sh${NC}"
fi

echo -e "${GREEN}===== Installation Complete =====${NC}"
echo -e "HakPak has been installed to ${INSTALL_DIR}"
echo -e "The web interface should be accessible at http://hakpak.local or http://192.168.4.1"
echo -e "To start the service, run: sudo systemctl start hakpak.service"
echo -e "To check the status, run: sudo systemctl status hakpak.service"

# Ask to reboot
echo ""
read -p "A reboot is recommended to complete the installation. Reboot now? (y/n) " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Rebooting...${NC}"
    reboot
fi

exit 0 