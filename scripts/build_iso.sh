#!/bin/bash

# HakPak ISO Builder Script
# This script creates a customized Kali Linux ARM image with HakPak pre-installed

set -e
BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}   HakPak ISO Builder                 ${NC}"
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

# Function to prompt for string input
prompt_string() {
    local prompt="$1"
    local default="$2"
    local value=""
    
    if [ -z "$default" ]; then
        read -p "$prompt: " value
    else
        read -p "$prompt [$default]: " value
        if [ -z "$value" ]; then
            value="$default"
        fi
    fi
    
    echo "$value"
}

# Check for required tools
status "Checking for required tools..."
REQUIRED_TOOLS="debootstrap parted kpartx qemu-user-static rsync wget xz-utils"
for tool in $REQUIRED_TOOLS; do
    if ! command -v $tool &>/dev/null; then
        warning "$tool is not installed. Installing..."
        apt update && apt install -y $tool
    fi
done
success "All required tools are installed"

# Default settings
WORK_DIR=$(prompt_string "Work directory" "/tmp/hakpak-iso-build")
OUTPUT_DIR=$(prompt_string "Output directory" "$(pwd)")
KALI_VERSION=$(prompt_string "Kali version" "current")
ARCH=$(prompt_string "Architecture" "arm64")
PI_MODEL=$(prompt_string "Raspberry Pi model (rpi4 for Pi 4)" "rpi4")

# Create work directory
mkdir -p $WORK_DIR
cd $WORK_DIR

# Download latest Kali image
status "Downloading latest Kali ARM image for Raspberry Pi..."
KALI_URL="https://kali.download/arm-images/kali-2025.1a/kali-linux-2025.1a-raspberry-pi-arm64.img.xz"
KALI_IMG="kali-linux-2025.1a-raspberry-pi-arm64.img"

if [ ! -f "${KALI_IMG}.xz" ]; then
    wget $KALI_URL -O ${KALI_IMG}.xz
fi

# Extract the image
status "Extracting Kali image..."
if [ ! -f "$KALI_IMG" ]; then
    xz -d ${KALI_IMG}.xz
fi
success "Kali image extracted"

# Set up loop device
status "Setting up loop device..."
LOOP_DEV=$(losetup -f --show $KALI_IMG)
partprobe $LOOP_DEV
success "Loop device set up at $LOOP_DEV"

# Mount partitions
status "Mounting partitions..."
mkdir -p ${WORK_DIR}/mnt
mkdir -p ${WORK_DIR}/mnt/boot
mkdir -p ${WORK_DIR}/mnt/root

# Find the partitions
BOOT_PART="${LOOP_DEV}p1"  # Boot partition is usually the first one
ROOT_PART="${LOOP_DEV}p2"  # Root partition is usually the second one

# Mount the partitions
mount $ROOT_PART ${WORK_DIR}/mnt/root
mount $BOOT_PART ${WORK_DIR}/mnt/boot
success "Partitions mounted"

# Copy HakPak files
status "Copying HakPak files to the image..."
mkdir -p ${WORK_DIR}/mnt/root/opt/hakpak
rsync -av --exclude node_modules --exclude venv --exclude .git --exclude $WORK_DIR . ${WORK_DIR}/mnt/root/opt/hakpak/
success "HakPak files copied"

# Create installation script for first boot
status "Creating first boot setup script..."
cat > ${WORK_DIR}/mnt/root/opt/hakpak/scripts/firstboot.sh << 'EOF'
#!/bin/bash

# First boot setup script for HakPak
# This will run on the first boot of the Raspberry Pi

# Update system first
apt update
apt upgrade -y

# Install dependencies
apt install -y hostapd dnsmasq nginx python3-pip python3-venv usbutils git rfkill iw wireless-tools

# Add to rc.local to run on first boot only
if [ ! -f /etc/hakpak-setup-done ]; then
    cd /opt/hakpak
    ./scripts/hakpak_setup.sh --auto
    touch /etc/hakpak-setup-done
    reboot
fi
EOF

# Make the script executable
chmod +x ${WORK_DIR}/mnt/root/opt/hakpak/scripts/firstboot.sh

# Modify hakpak_setup.sh to support auto mode (non-interactive)
status "Updating hakpak_setup.sh to support auto mode..."
sed -i 's/^# Function to prompt for yes\/no confirmation/# Check for auto mode\nAUTO_MODE=false\nif [ "$1" = "--auto" ]; then\n    AUTO_MODE=true\nfi\n\n# Function to prompt for yes\/no confirmation/' ${WORK_DIR}/mnt/root/opt/hakpak/scripts/hakpak_setup.sh
sed -i '/^confirm()/,/^}$/c\confirm() {\n    local prompt="$1"\n    local default="$2"\n    \n    if [ "$AUTO_MODE" = true ]; then\n        [ "$default" = "Y" ] && return 0 || return 1\n    fi\n    \n    if [ "$default" = "Y" ]; then\n        local options="[Y/n]"\n    else\n        local options="[y/N]"\n    fi\n    \n    read -p "$prompt $options " response\n    \n    if [ -z "$response" ]; then\n        response=$default\n    fi\n    \n    case "$response" in\n        [yY][eE][sS]|[yY]) \n            return 0\n            ;;\n        [nN][oO]|[nN])\n            return 1\n            ;;\n        *)\n            echo "Invalid response. Please answer y or n."\n            confirm "$prompt" "$default"\n            ;;\n    esac\n}' ${WORK_DIR}/mnt/root/opt/hakpak/scripts/hakpak_setup.sh
sed -i '/^prompt_string()/,/^}$/c\prompt_string() {\n    local prompt="$1"\n    local default="$2"\n    local value=""\n    \n    if [ "$AUTO_MODE" = true ]; then\n        echo "$default"\n        return\n    fi\n    \n    if [ -z "$default" ]; then\n        read -p "$prompt: " value\n    else\n        read -p "$prompt [$default]: " value\n        if [ -z "$value" ]; then\n            value="$default"\n        fi\n    fi\n    \n    echo "$value"\n}' ${WORK_DIR}/mnt/root/opt/hakpak/scripts/hakpak_setup.sh
sed -i '/^select_option()/,/^}$/c\select_option() {\n    local prompt="$1"\n    shift\n    local options=("$@")\n    \n    if [ "$AUTO_MODE" = true ]; then\n        return 0\n    fi\n    \n    echo "$prompt"\n    for i in "${!options[@]}"; do\n        echo "  $((i+1)). ${options[$i]}"\n    done\n    \n    local valid=false\n    local choice\n    until $valid; do\n        read -p "Enter selection [1-${#options[@]}]: " choice\n        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#options[@]}" ]; then\n            valid=true\n        else\n            echo "Invalid choice. Please enter a number between 1 and ${#options[@]}."\n        fi\n    done\n    \n    return $((choice-1))\n}' ${WORK_DIR}/mnt/root/opt/hakpak/scripts/hakpak_setup.sh

# Add firstboot service to run setup on first boot
status "Setting up first boot service..."
cat > ${WORK_DIR}/mnt/root/etc/systemd/system/hakpak-firstboot.service << EOF
[Unit]
Description=HakPak First Boot Setup
After=network.target

[Service]
Type=oneshot
ExecStart=/opt/hakpak/scripts/firstboot.sh
RemainAfterExit=true

[Install]
WantedBy=multi-user.target
EOF

# Enable the service
chroot ${WORK_DIR}/mnt/root systemctl enable hakpak-firstboot.service

# Create a welcome message
status "Creating welcome message..."
cat > ${WORK_DIR}/mnt/root/etc/update-motd.d/10-hakpak << 'EOF'
#!/bin/bash

# HakPak MOTD
cat << 'HAKPAK'
 _   _       _    ____       _    
| | | | __ _| | _|  _ \ __ _| | __
| |_| |/ _` | |/ / |_) / _` | |/ /
|  _  | (_| |   <|  __/ (_| |   < 
|_| |_|\__,_|_|\_\_|   \__,_|_|\_\
                                  
Portable Pentesting Platform

HAKPAK

echo "Welcome to HakPak!"
echo "To complete setup, HakPak will run its configuration script on first boot."
echo "After reboot, you can connect to the 'hakpak' WiFi network with password 'pentestallthethings'."
echo "Documentation can be found at /opt/hakpak/docs/"
echo 
EOF

chmod +x ${WORK_DIR}/mnt/root/etc/update-motd.d/10-hakpak

# Clean up
status "Cleaning up image for distribution..."
# Remove logs, temporary files, etc.
rm -rf ${WORK_DIR}/mnt/root/var/log/*
rm -rf ${WORK_DIR}/mnt/root/var/cache/apt/*
rm -rf ${WORK_DIR}/mnt/root/var/tmp/*
rm -rf ${WORK_DIR}/mnt/root/tmp/*

# Unmount and clean up
status "Unmounting partitions..."
sync
umount ${WORK_DIR}/mnt/boot
umount ${WORK_DIR}/mnt/root
losetup -d $LOOP_DEV
success "Partitions unmounted and cleaned up"

# Compress the image
status "Compressing final image..."
OUTPUT_FILE="${OUTPUT_DIR}/hakpak-kali-${PI_MODEL}-${ARCH}.img"
cp $KALI_IMG $OUTPUT_FILE
xz -z $OUTPUT_FILE
success "Final image compressed to ${OUTPUT_FILE}.xz"

# Create a checksum
status "Creating checksums..."
cd $OUTPUT_DIR
sha256sum "hakpak-kali-${PI_MODEL}-${ARCH}.img.xz" > "hakpak-kali-${PI_MODEL}-${ARCH}.img.xz.sha256"
success "Checksums created"

# Cleanup
status "Cleaning up temporary files..."
rm -rf $WORK_DIR
success "Temporary files cleaned up"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}   HakPak ISO Build Complete!         ${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "Your custom HakPak Kali image is ready at:"
echo -e "${YELLOW}${OUTPUT_FILE}.xz${NC}"
echo
echo -e "To write it to an SD card, use:"
echo -e "${YELLOW}xz -dc ${OUTPUT_FILE}.xz | sudo dd of=/dev/sdX bs=4M status=progress${NC}"
echo -e "(Replace /dev/sdX with your SD card device)"
echo
echo -e "The image includes HakPak pre-installed and will automatically"
echo -e "configure itself on first boot."
echo
echo -e "${GREEN}========================================${NC}" 