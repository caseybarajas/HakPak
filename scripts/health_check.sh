#!/bin/bash

# HakPak Health Check Script
# This script checks the health of your HakPak installation
# and provides troubleshooting guidance

# Colors for output
BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

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
            
            # Check if it's in AP mode
            if iw dev $iface info | grep -q "type AP"; then
                success "Interface $iface is in AP mode"
                AP_IFACE=$iface
            else
                if iw dev $iface info | grep -q "type managed"; then
                    warning "Interface $iface is in managed mode, not AP mode"
                else
                    error "Interface $iface is neither in AP nor managed mode"
                fi
            fi
        else
            warning "Interface $iface is DOWN"
        fi
    done
    
    # Check if interface has IP 192.168.4.1
    if ip addr | grep -q "192.168.4.1"; then
        success "HakPak IP address 192.168.4.1 is configured"
    else
        error "HakPak IP address 192.168.4.1 is not configured"
    fi
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
    
    # Check hostapd configuration
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
    
    # Track overall status
    ISSUES_FOUND=0
    
    # Check services
    check_service "hakpak" || ((ISSUES_FOUND++))
    check_service "nginx" || ((ISSUES_FOUND++))
    check_service "hostapd" || ((ISSUES_FOUND++))
    check_service "dnsmasq" || ((ISSUES_FOUND++))
    
    # Check configurations
    check_configs
    
    # Check network
    check_wifi_blocked
    check_network
    
    # Check system resources
    check_resources
    
    # Check Flipper Zero
    check_flipper
    
    # Print summary
    echo
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}   Health Check Summary               ${NC}"
    echo -e "${BLUE}========================================${NC}"
    
    if [ $ISSUES_FOUND -eq 0 ]; then
        echo -e "${GREEN}All systems operational! No critical issues found.${NC}"
    else
        echo -e "${YELLOW}Found $ISSUES_FOUND potential issues that need attention.${NC}"
        
        # Provide troubleshooting advice
        echo
        echo -e "${BLUE}Troubleshooting suggestions:${NC}"
        
        # Check if services are down
        if ! systemctl is-active hakpak >/dev/null 2>&1; then
            echo -e "${YELLOW}To check HakPak logs:${NC} sudo journalctl -u hakpak -n 50"
        fi
        
        if ! systemctl is-active hostapd >/dev/null 2>&1; then
            echo -e "${YELLOW}To check Hostapd logs:${NC} sudo journalctl -u hostapd -n 50"
            echo -e "${YELLOW}To test hostapd config:${NC} sudo hostapd -dd /etc/hostapd/hostapd.conf"
        fi
        
        if ! systemctl is-active dnsmasq >/dev/null 2>&1; then
            echo -e "${YELLOW}To check DNSmasq logs:${NC} sudo journalctl -u dnsmasq -n 50"
            echo -e "${YELLOW}To test if port 53 is in use:${NC} sudo lsof -i :53"
        fi
        
        # Suggest fix network script
        echo -e "${YELLOW}To attempt fixing network issues:${NC} sudo ./scripts/fix_network.sh"
        
        # Suggest reboot as last resort
        echo -e "${YELLOW}If all else fails, try rebooting:${NC} sudo reboot"
    fi
}

# Execute all checks
run_all_checks

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}   Health Check Complete               ${NC}"
echo -e "${BLUE}========================================${NC}" 