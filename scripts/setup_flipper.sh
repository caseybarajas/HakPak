#!/bin/bash

# HakPak Flipper Zero Setup Script
# This script detects and configures the Flipper Zero for use with HakPak

# Colors for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}===== HakPak Flipper Zero Setup =====${NC}"
echo -e "This script will detect and configure your Flipper Zero for use with HakPak"
echo ""

# Function to check if Flipper Zero is connected
check_flipper() {
    echo -e "${YELLOW}Checking for Flipper Zero...${NC}"
    
    # First, check for USB connection via lsusb
    if lsusb | grep -i "flipper" > /dev/null; then
        echo -e "${GREEN}Flipper Zero detected via USB${NC}"
        return 0
    fi
    
    # Next, check for serial port
    if ls /dev/ttyACM* 2>/dev/null | grep -q .; then
        echo -e "${YELLOW}Potential Flipper Zero port found. Checking...${NC}"
        
        # Try to communicate with the device
        # This is a basic test and would need to be expanded for actual implementation
        for port in /dev/ttyACM*; do
            echo -e "${YELLOW}Testing port ${port}...${NC}"
            if stty -F "$port" 115200 && echo "device_info" > "$port"; then
                echo -e "${GREEN}Flipper Zero confirmed on ${port}${NC}"
                return 0
            fi
        done
    fi
    
    echo -e "${RED}Flipper Zero not detected${NC}"
    return 1
}

# Function to configure Flipper Zero for use with HakPak
configure_flipper() {
    echo -e "${YELLOW}Configuring Flipper Zero...${NC}"
    
    # Find the Flipper Zero port
    FLIPPER_PORT=$(ls /dev/ttyACM* 2>/dev/null | head -n 1)
    
    if [ -z "$FLIPPER_PORT" ]; then
        echo -e "${RED}Flipper Zero port not found${NC}"
        return 1
    fi
    
    echo -e "${YELLOW}Using port: ${FLIPPER_PORT}${NC}"
    
    # Create configuration file for HakPak
    echo -e "${YELLOW}Creating configuration file...${NC}"
    mkdir -p /etc/hakpak
    cat > /etc/hakpak/flipper.conf << EOF
# HakPak Flipper Zero Configuration
FLIPPER_PORT="${FLIPPER_PORT}"
FLIPPER_BAUD=115200
FLIPPER_ENABLED=true
EOF
    
    # Set permissions
    chmod 644 /etc/hakpak/flipper.conf
    
    echo -e "${GREEN}Configuration file created: /etc/hakpak/flipper.conf${NC}"
    
    return 0
}

# Function to install qFlipper CLI if not already installed
install_qflipper_cli() {
    echo -e "${YELLOW}Checking for qFlipper CLI...${NC}"
    
    if command -v qFlipper &> /dev/null; then
        echo -e "${GREEN}qFlipper CLI already installed${NC}"
        return 0
    fi
    
    echo -e "${YELLOW}Installing qFlipper CLI dependencies...${NC}"
    apt-get update
    apt-get install -y git cmake build-essential libusb-1.0-0-dev libqt5core5a libqt5serialport5-dev
    
    echo -e "${YELLOW}Cloning qFlipper repository...${NC}"
    cd /opt
    if [ ! -d "/opt/qFlipper" ]; then
        git clone https://github.com/flipperdevices/qFlipper.git
    else
        echo -e "${YELLOW}qFlipper directory already exists, updating...${NC}"
        cd qFlipper
        git pull
        cd ..
    fi
    
    echo -e "${YELLOW}Building qFlipper CLI...${NC}"
    cd qFlipper
    ./build_cli.sh
    
    if [ -f "/opt/qFlipper/build-cli/qFlipperCli" ]; then
        echo -e "${GREEN}qFlipper CLI built successfully${NC}"
        ln -sf /opt/qFlipper/build-cli/qFlipperCli /usr/local/bin/qFlipper
        echo -e "${GREEN}qFlipper CLI linked to /usr/local/bin/qFlipper${NC}"
        return 0
    else
        echo -e "${RED}qFlipper CLI build failed${NC}"
        return 1
    fi
}

# Main script flow
echo -e "${YELLOW}Starting setup...${NC}"

# Check for root privileges
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}This script must be run as root${NC}"
    exit 1
fi

# Check for Flipper Zero
if check_flipper; then
    # Configure Flipper Zero
    if configure_flipper; then
        echo -e "${GREEN}Flipper Zero configured successfully${NC}"
    else
        echo -e "${RED}Failed to configure Flipper Zero${NC}"
        exit 1
    fi
else
    echo -e "${YELLOW}Flipper Zero not detected. Please connect your Flipper Zero and try again.${NC}"
    exit 1
fi

# Install qFlipper CLI
if install_qflipper_cli; then
    echo -e "${GREEN}qFlipper CLI installed successfully${NC}"
else
    echo -e "${RED}Failed to install qFlipper CLI${NC}"
    exit 1
fi

echo -e "${GREEN}===== Setup Complete =====${NC}"
echo -e "Flipper Zero is now configured for use with HakPak"
echo -e "Configuration file: /etc/hakpak/flipper.conf"
echo -e "You can now use the HakPak web interface to control your Flipper Zero"
exit 0 