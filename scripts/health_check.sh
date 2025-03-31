#!/bin/bash

# HakPak Health Check Script
# This script checks the health of your HakPak installation
# and provides troubleshooting guidance

# Clear the screen for a cleaner look
clear

# Colors for output
BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Default configuration location
CONFIG_FILE="/opt/hakpak/config/hakpak.conf"
NETWORK_MODE="AP"  # Default to AP mode unless config indicates otherwise

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Please run as root (sudo)${NC}"
  exit 1
fi

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}   HakPak Health Check               ${NC}"
echo -e "${BLUE}========================================${NC}"

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
}

# Function to display warning message
warning() {
    echo -e "${YELLOW}[!] $1${NC}"
}

# Detect network mode from configuration
detect_network_mode() {
    status "Determining network mode..."
    
    if [ -f "$CONFIG_FILE" ]; then
        if grep -q "network_mode = CLIENT" "$CONFIG_FILE"; then
            NETWORK_MODE="CLIENT"
            success "Detected Client network mode"
        else
            NETWORK_MODE="AP"
            success "Detected Access Point (AP) network mode"
        fi
    else
        warning "Configuration file not found at $CONFIG_FILE. Assuming AP mode."
        NETWORK_MODE="AP"
    fi
    
    # Extract network interface from config
    if grep -q "ap_interface" "$CONFIG_FILE"; then
        NETWORK_INTERFACE=$(grep "ap_interface" "$CONFIG_FILE" | cut -d'=' -f2 | xargs)
        success "Network interface: $NETWORK_INTERFACE"
    else
        warning "Could not determine network interface from config, will use default"
        NETWORK_INTERFACE="wlan0"
    fi
}

# Check if service is running
check_service() {
    status "Checking $1 service..."
    if systemctl is-active $1 >/dev/null 2>&1; then
        success "$1 is running"
        return 0
    else
        error "$1 is not running"
        return 1
    fi
}

# Check if directory exists
check_directory() {
    if [ -d "$1" ]; then
        success "Directory $1 exists"
        return 0
    else
        error "Directory $1 does not exist"
        return 1
    fi
}

# Check if file exists
check_file() {
    if [ -f "$1" ]; then
        success "File $1 exists"
        return 0
    else
        error "File $1 does not exist"
        return 1
    fi
}

# Check system resources
check_resources() {
    status "Checking system resources..."
    
    # Check CPU load
    CPU_LOAD=$(cat /proc/loadavg | awk '{print $1}')
    CPU_CORES=$(nproc)
    CPU_LOAD_PER_CORE=$(echo "$CPU_LOAD / $CPU_CORES" | bc -l)
    
    if (( $(echo "$CPU_LOAD_PER_CORE > 0.8" | bc -l) )); then
        warning "High CPU load: $CPU_LOAD (per core: $CPU_LOAD_PER_CORE)"
    else
        success "CPU load normal: $CPU_LOAD (per core: $CPU_LOAD_PER_CORE)"
    fi
    
    # Check memory usage
    MEM_TOTAL=$(free -m | grep Mem | awk '{print $2}')
    MEM_USED=$(free -m | grep Mem | awk '{print $3}')
    MEM_PERCENT=$(echo "scale=2; $MEM_USED * 100 / $MEM_TOTAL" | bc)
    
    if (( $(echo "$MEM_PERCENT > 90" | bc -l) )); then
        warning "High memory usage: ${MEM_PERCENT}% ($MEM_USED/$MEM_TOTAL MB)"
    else
        success "Memory usage normal: ${MEM_PERCENT}% ($MEM_USED/$MEM_TOTAL MB)"
    fi
    
    # Check disk space
    DISK_TOTAL=$(df -h / | awk 'NR==2 {print $2}')
    DISK_USED=$(df -h / | awk 'NR==2 {print $3}')
    DISK_PERCENT=$(df -h / | awk 'NR==2 {print $5}' | tr -d '%')
    
    if [ "$DISK_PERCENT" -gt 90 ]; then
        warning "Low disk space: ${DISK_PERCENT}% ($DISK_USED/$DISK_TOTAL)"
    else
        success "Disk space normal: ${DISK_PERCENT}% ($DISK_USED/$DISK_TOTAL)"
    fi
    
    # Check temperature if possible
    if [ -f /sys/class/thermal/thermal_zone0/temp ]; then
        TEMP=$(cat /sys/class/thermal/thermal_zone0/temp)
        TEMP=$(echo "scale=1; $TEMP/1000" | bc)
        
        if (( $(echo "$TEMP > 75" | bc -l) )); then
            warning "High CPU temperature: ${TEMP}°C"
        else
            success "CPU temperature normal: ${TEMP}°C"
        fi
    fi
}

# Check network interfaces
check_network() {
    status "Checking network interfaces..."
    
    # Find WiFi interfaces
    WIFI_INTERFACES=($(iw dev | grep Interface | awk '{print $2}'))
    
    if [ ${#WIFI_INTERFACES[@]} -eq 0 ]; then
        error "No wireless interfaces found"
        return 1
    fi
    
    for iface in "${WIFI_INTERFACES[@]}"; do
        if ip addr show $iface | grep -q "state UP"; then
            success "Interface $iface is UP"
            
            if [ "$NETWORK_MODE" = "AP" ]; then
                # Check if it's in AP mode
                if iw dev $iface info | grep -q "type AP"; then
                    success "Interface $iface is in AP mode"
                    AP_IFACE=$iface
                else
                    if iw dev $iface info | grep -q "type managed"; then
                        warning "Interface $iface is in managed mode, not AP mode"
                    else
                        error "Interface $iface is in an unexpected mode"
                    fi
                fi
                
                # Check if interface has expected IP (192.168.4.x in AP mode)
                if ip addr show $iface | grep -q "192.168.4"; then
                    success "HakPak IP address is configured on interface $iface"
                else
                    error "Expected IP address (192.168.4.x) not found on interface $iface"
                fi
            else
                # Client mode checks
                if iw dev $iface info | grep -q "type managed"; then
                    success "Interface $iface is in managed mode (client mode)"
                    
                    # Check if connected to WiFi
                    if iw dev $iface link | grep -q "Connected to"; then
                        CONNECTED_SSID=$(iw dev $iface link | grep "SSID" | awk '{print $2}')
                        success "Connected to WiFi network: $CONNECTED_SSID"
                    else
                        error "Not connected to any WiFi network"
                    fi
                    
                    # Check if interface has an IP
                    if ip addr show $iface | grep -q "inet "; then
                        CLIENT_IP=$(ip addr show $iface | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n 1)
                        success "Interface has IP address: $CLIENT_IP"
                    else
                        error "No IP address assigned to interface $iface"
                    fi
                else
                    error "Interface $iface is not in managed mode (client mode)"
                fi
            fi
        else
            warning "Interface $iface is DOWN"
        fi
    done
}

# Check if WiFi is blocked
check_wifi_blocked() {
    status "Checking if WiFi is blocked..."
    if rfkill list wifi | grep -q "blocked: yes"; then
        error "WiFi is blocked. Run 'sudo rfkill unblock wifi' to unblock it"
        return 1
    else
        success "WiFi is not blocked"
        return 0
    fi
}

# Check Flipper Zero connection
check_flipper() {
    status "Checking Flipper Zero connection..."
    
    # Check if Flipper Zero is connected via USB
    if lsusb | grep -q "0483:5740"; then
        success "Flipper Zero is connected via USB"
        
        # Check if flipper device exists
        if [ -e /dev/flipper ] || [ -e /dev/ttyACM0 ]; then
            success "Flipper Zero device file exists"
        else
            warning "Flipper Zero device file not found. Check udev rules"
        fi
        
        return 0
    else
        warning "Flipper Zero not detected via USB"
        return 1
    fi
}

# Check configuration files
check_configs() {
    status "Checking configuration files..."
    
    # Check hakpak configuration
    check_file "$CONFIG_FILE"
    
    if [ "$NETWORK_MODE" = "AP" ]; then
        # AP mode configuration files
        check_file "/etc/hostapd/hostapd.conf"
        if [ -f "/etc/hostapd/hostapd.conf" ]; then
            if grep -q "interface=" /etc/hostapd/hostapd.conf; then
                AP_IFACE=$(grep "interface=" /etc/hostapd/hostapd.conf | cut -d'=' -f2)
                success "Hostapd configured to use interface: $AP_IFACE"
            else
                error "Hostapd config missing interface definition"
            fi
        fi
        
        # Check dnsmasq configuration
        check_file "/etc/dnsmasq.conf"
        if [ -f "/etc/dnsmasq.conf" ]; then
            if grep -q "dhcp-range=" /etc/dnsmasq.conf; then
                success "DNSmasq has DHCP range configured"
            else
                error "DNSmasq config missing DHCP range"
            fi
        fi
    else
        # Client mode configuration files
        check_file "/etc/wpa_supplicant/wpa_supplicant-${NETWORK_INTERFACE}.conf"
        if [ -f "/etc/wpa_supplicant/wpa_supplicant-${NETWORK_INTERFACE}.conf" ]; then
            if grep -q "ssid=" /etc/wpa_supplicant/wpa_supplicant-${NETWORK_INTERFACE}.conf; then
                success "WPA Supplicant has SSID configured"
            else
                error "WPA Supplicant config missing SSID"
            fi
        fi
        
        # Check wpa_supplicant service
        if systemctl is-active wpa_supplicant@${NETWORK_INTERFACE} >/dev/null 2>&1; then
            success "WPA Supplicant service is running"
        else
            error "WPA Supplicant service is not running"
        fi
    fi
    
    # Check hakpak service
    check_file "/etc/systemd/system/hakpak.service"
    
    # Check Python environment
    check_directory "/opt/hakpak/venv"
    
    # Check Nginx configuration
    check_file "/etc/nginx/sites-enabled/hakpak"
}

# Run all checks and collect results
run_all_checks() {
    status "Beginning comprehensive health check..."
    
    # First detect network mode
    detect_network_mode
    
    # Track overall status
    ISSUES_FOUND=0
    
    # Check common services
    check_service "hakpak" || ((ISSUES_FOUND++))
    check_service "nginx" || ((ISSUES_FOUND++))
    
    # Check mode-specific services
    if [ "$NETWORK_MODE" = "AP" ]; then
        check_service "hostapd" || ((ISSUES_FOUND++))
        check_service "dnsmasq" || ((ISSUES_FOUND++))
    else
        check_service "wpa_supplicant@${NETWORK_INTERFACE}" || ((ISSUES_FOUND++))
        check_service "dhcpcd" || ((ISSUES_FOUND++))
    fi
    
    # Check configurations
    check_configs || ((ISSUES_FOUND++))
    
    # Check system resources
    check_resources || ((ISSUES_FOUND++))
    
    # Check WiFi
    check_wifi_blocked || ((ISSUES_FOUND++))
    
    # Check network
    check_network || ((ISSUES_FOUND++))
    
    # Check Flipper Zero
    check_flipper || ((ISSUES_FOUND++))
    
    # Print summary
    echo
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}   Health Check Summary              ${NC}"
    echo -e "${BLUE}========================================${NC}"
    
    if [ $ISSUES_FOUND -eq 0 ]; then
        echo -e "${GREEN}No issues found. HakPak is healthy!${NC}"
    else
        echo -e "${YELLOW}Found $ISSUES_FOUND potential issues that need attention.${NC}"
    fi
    
    # Print troubleshooting tips based on network mode
    echo
    echo -e "${BLUE}Troubleshooting Tips:${NC}"
    if [ "$NETWORK_MODE" = "AP" ]; then
        echo -e "1. If WiFi network is not visible:"
        echo -e "   - Run: ${YELLOW}sudo systemctl restart hostapd${NC}"
        echo -e "   - Check hostapd logs: ${YELLOW}sudo journalctl -u hostapd${NC}"
        echo -e "2. If WiFi connected but no internet:"
        echo -e "   - Check internet sharing: ${YELLOW}sudo systemctl restart dnsmasq${NC}"
        echo -e "   - Verify IP forwarding: ${YELLOW}cat /proc/sys/net/ipv4/ip_forward${NC} (should be 1)"
    else
        echo -e "1. If not connecting to WiFi:"
        echo -e "   - Restart WPA supplicant: ${YELLOW}sudo systemctl restart wpa_supplicant@${NETWORK_INTERFACE}${NC}"
        echo -e "   - Check WPA logs: ${YELLOW}sudo journalctl -u wpa_supplicant@${NETWORK_INTERFACE}${NC}"
        echo -e "2. If WiFi connected but no IP address:"
        echo -e "   - Restart DHCP client: ${YELLOW}sudo systemctl restart dhcpcd${NC}"
        echo -e "   - Check DHCP logs: ${YELLOW}sudo journalctl -u dhcpcd${NC}"
    fi
    
    echo -e "3. If web interface is not accessible:"
    echo -e "   - Restart web services: ${YELLOW}sudo systemctl restart nginx hakpak${NC}"
    echo -e "   - Check logs: ${YELLOW}sudo journalctl -u nginx -u hakpak${NC}"
    echo
    echo -e "4. To reboot the system: ${YELLOW}sudo reboot${NC}"
    
    # Return the number of issues found
    return $ISSUES_FOUND
}

# Main execution
run_all_checks
exit $?

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}   Health Check Complete               ${NC}"
echo -e "${BLUE}========================================${NC}" 