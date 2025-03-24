#!/bin/bash

# Exit on error
set -e

echo "🐬 Setting up Flipper Zero..."

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root"
    exit 1
fi

# Create Flipper Zero configuration directory
echo "Creating Flipper Zero configuration directory..."
mkdir -p /etc/hakpak/flipper

# Create default Flipper Zero configuration
echo "Creating default configuration..."
cat > /etc/hakpak/flipper.conf << EOF
# Flipper Zero Configuration
FLIPPER_PORT=/dev/flipper
FLIPPER_BAUDRATE=115200
FLIPPER_TIMEOUT=5
EOF

# Set up udev rules for Flipper Zero
echo "Setting up udev rules..."
cat > /etc/udev/rules.d/42-flipper.rules << EOF
SUBSYSTEM=="tty", ATTRS{idVendor}=="0483", ATTRS{idProduct}=="5740", SYMLINK+="flipper"
EOF

# Reload udev rules
echo "Reloading udev rules..."
udevadm control --reload-rules
udevadm trigger

# Create directories for Flipper Zero data
echo "Creating data directories..."
mkdir -p /opt/hakpak/data/flipper/{ir,rfid,subghz,nfc,ibutton}
chown -R root:root /opt/hakpak/data/flipper
chmod -R 755 /opt/hakpak/data/flipper

# Test Flipper Zero connection
echo "Testing Flipper Zero connection..."
if [ -e "/dev/flipper" ]; then
    echo "✅ Flipper Zero detected at /dev/flipper"
    echo "Testing communication..."
    
    # Try to communicate with Flipper Zero
    if python3 -c "
import serial
try:
    with serial.Serial('/dev/flipper', 115200, timeout=1) as ser:
        ser.write(b'device_info\r')
        response = ser.read(100)
        if b'Flipper' in response:
            print('Communication successful')
            exit(0)
        else:
            print('Communication failed')
            exit(1)
except Exception as e:
    print(f'Error: {e}')
    exit(1)
"; then
        echo "✅ Flipper Zero communication test successful"
    else
        echo "❌ Flipper Zero communication test failed"
        echo "Please check your connection and try again"
    fi
else
    echo "❌ Flipper Zero not detected"
    echo "Please connect your Flipper Zero and try again"
fi

echo "Flipper Zero setup complete!" 