#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=======================================${NC}"
echo -e "${BLUE}    HakPak System Health Check        ${NC}"
echo -e "${BLUE}=======================================${NC}"

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Please run as root${NC}"
    exit 1
fi

# Function to print section headers
print_section() {
    echo -e "\n${BLUE}==== $1 ====${NC}"
}

# Function to check services
check_service() {
    service_name=$1
    echo -n "- $service_name service: "
    
    if systemctl is-active --quiet $service_name; then
        echo -e "${GREEN}RUNNING${NC}"
        return 0
    else
        echo -e "${RED}NOT RUNNING${NC}"
        return 1
    fi
}

# Function to check if a file exists
check_file() {
    file_path=$1
    description=$2
    echo -n "- $description: "
    
    if [ -f "$file_path" ]; then
        echo -e "${GREEN}EXISTS${NC}"
        return 0
    else
        echo -e "${RED}MISSING${NC}"
        return 1
    fi
}

# Function to check if a directory exists
check_directory() {
    dir_path=$1
    description=$2
    echo -n "- $description: "
    
    if [ -d "$dir_path" ]; then
        echo -e "${GREEN}EXISTS${NC}"
        return 0
    else
        echo -e "${RED}MISSING${NC}"
        return 1
    fi
}

# Check system resources
print_section "System Resources"
echo "- CPU usage: $(top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4}')%"
echo "- Memory usage: $(free -m | awk '/Mem/{printf "%.2f%%", $3*100/$2}')"
echo "- Disk usage: $(df -h / | awk '/\//{print $5}')"
echo "- Uptime: $(uptime -p)"

# Check services
print_section "Services"
check_service "hakpak" || systemctl status hakpak | head -n 10
check_service "nginx"
check_service "hostapd"
check_service "dnsmasq"

# Check configuration files
print_section "Configuration Files"
check_file "/etc/hostapd/hostapd.conf" "Hostapd configuration"
check_file "/etc/dnsmasq.conf" "Dnsmasq configuration"
check_file "/etc/network/interfaces" "Network interfaces configuration"
check_file "/etc/hakpak/config.json" "HakPak configuration"

# Check directories
print_section "Directories"
check_directory "/opt/hakpak" "HakPak installation directory"
check_directory "/opt/hakpak/app" "HakPak application directory"
check_directory "/opt/hakpak/flipper_integration" "Flipper integration directory"
check_directory "/var/log/hakpak" "HakPak log directory"

# Check network interfaces
print_section "Network Interfaces"
echo "- Available interfaces:"
ip -br addr show | grep -v "lo" || echo -e "${RED}No interfaces found${NC}"

# Check WiFi status
print_section "WiFi Status"
if command -v iw &> /dev/null; then
    if iw dev | grep -q Interface; then
        WIFI_INTERFACE=$(iw dev | grep Interface | head -1 | awk '{print $2}')
        echo -e "- WiFi interface: ${GREEN}$WIFI_INTERFACE${NC}"
        
        # Check if in AP mode
        if iw dev $WIFI_INTERFACE info | grep -q "type AP"; then
            echo -e "- AP mode: ${GREEN}ENABLED${NC}"
            echo -n "- SSID: "
            grep -q "^ssid=" /etc/hostapd/hostapd.conf && \
            echo -e "${GREEN}$(grep "^ssid=" /etc/hostapd/hostapd.conf | cut -d'=' -f2)${NC}" || \
            echo -e "${RED}Not configured${NC}"
        else
            echo -e "- AP mode: ${RED}DISABLED${NC}"
        fi
        
        # Check if WiFi is blocked
        if rfkill list wifi | grep -q "Soft blocked: yes"; then
            echo -e "- WiFi blocked: ${RED}YES${NC}"
            echo "  Run 'sudo rfkill unblock wifi' to unblock"
        else
            echo -e "- WiFi blocked: ${GREEN}NO${NC}"
        fi
    else
        echo -e "${RED}No WiFi interfaces found${NC}"
    fi
else
    echo -e "${RED}iw tool not installed. Install with: sudo apt-get install iw${NC}"
fi

# Check Flipper Zero connection
print_section "Flipper Zero"
if [ -c "/dev/flipper" ]; then
    echo -e "- Flipper Zero device: ${GREEN}CONNECTED${NC}"
else
    echo -e "- Flipper Zero device: ${RED}NOT CONNECTED${NC}"
    echo "  Check connection and run 'sudo scripts/setup_flipper.sh'"
fi

# Check Python environment
print_section "Python Environment"
if [ -d "/opt/hakpak/venv" ]; then
    echo -e "- Python virtual environment: ${GREEN}EXISTS${NC}"
    echo -n "- Flask installed: "
    if /opt/hakpak/venv/bin/pip list | grep -q Flask; then
        echo -e "${GREEN}YES${NC}"
    else
        echo -e "${RED}NO${NC}"
    fi
else
    echo -e "- Python virtual environment: ${RED}MISSING${NC}"
    echo "  Run installation script to create Python environment"
fi

# Check logs for errors
print_section "Logs"
echo "- Last 5 HakPak errors:"
if [ -f "/var/log/hakpak/error.log" ]; then
    grep "ERROR\|Error\|error" /var/log/hakpak/error.log | tail -n5 || echo "  No errors found"
else
    echo -e "${YELLOW}  Log file doesn't exist yet${NC}"
fi

echo "- Last 5 hostapd errors:"
journalctl -u hostapd --no-pager | grep "fail\|error" | tail -n5 || echo "  No errors found"

echo "- Last 5 dnsmasq errors:"
journalctl -u dnsmasq --no-pager | grep "fail\|error" | tail -n5 || echo "  No errors found"

# Print summary
print_section "Summary"
if check_service "hakpak" > /dev/null && check_service "nginx" > /dev/null && \
   check_service "hostapd" > /dev/null && check_service "dnsmasq" > /dev/null; then
    echo -e "${GREEN}All services are running!${NC}"
    echo "- HakPak is accessible at: http://hakpak.local or http://192.168.4.1"
    echo ""
    echo "- WiFi SSID: hakpak"
    echo "- WiFi Password: pentestallthethings"
else
    echo -e "${RED}Some services are not running.${NC}"
    echo "Run the following command to view detailed service status:"
    echo "sudo systemctl status hakpak nginx hostapd dnsmasq"
    echo ""
    echo "You can try the following to fix issues:"
    echo "1. Restart services: sudo systemctl restart hakpak nginx hostapd dnsmasq"
    echo "2. Run the WiFi setup script: sudo scripts/setup_wifi.sh"
    echo "3. Reboot the system: sudo reboot"
fi

echo -e "\n${BLUE}=======================================${NC}" 