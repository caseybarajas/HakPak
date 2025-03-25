#!/bin/bash

# Exit on error
set -e

echo "🔧 Fixing Flipper Zero detection..."

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root"
    exit 1
fi

# Reload udev rules
echo "Reloading udev rules..."
udevadm control --reload-rules
udevadm trigger

# Check for known Flipper Zero ID
echo "Looking for Flipper Zero devices..."
if lsusb | grep -i "0483:5740\|Flipper"; then
    echo "✅ Flipper Zero device found in USB devices"
else
    echo "❌ Flipper Zero not found in USB devices"
    echo "Please make sure your Flipper Zero is connected and powered on"
fi

# Check for serial devices
echo "Checking serial devices..."
if ls /dev/ttyACM* 2>/dev/null; then
    echo "Serial devices found. Trying to identify Flipper Zero..."
    
    # Try to match potential devices
    for device in /dev/ttyACM*; do
        echo "Testing $device..."
        if stty -F "$device" 115200 2>/dev/null; then
            echo "$device is accessible at 115200 baud"
            
            # Create manual symlink
            echo "Creating manual symlink for Flipper Zero..."
            ln -sf "$device" /dev/flipper
            echo "Created symlink: $device -> /dev/flipper"
            
            # Test communication
            echo "Testing communication with Flipper Zero..."
            if python3 -c "
import serial
import time
try:
    with serial.Serial('/dev/flipper', 115200, timeout=1) as ser:
        ser.write(b'device_info\r')
        time.sleep(0.5)
        response = ser.read(100)
        if b'Flipper' in response:
            print('✅ Communication successful')
            exit(0)
        else:
            print('❌ Communication failed')
            exit(1)
except Exception as e:
    print(f'❌ Error: {e}')
    exit(1)
"; then
                echo "✅ Flipper Zero detected and working at $device"
                echo "✅ Manual symlink created: $device -> /dev/flipper"
                break
            else
                echo "❌ Communication test failed on $device"
            fi
        else
            echo "❌ Could not set baud rate on $device"
        fi
    done
else
    echo "❌ No serial devices found"
fi

echo ""
echo "If Flipper Zero is still not detected, try these steps:"
echo "1. Disconnect and reconnect the Flipper Zero"
echo "2. Make sure the Flipper Zero is in USB-UART mode"
echo "3. Check if the Flipper Zero shows up in 'lsusb' output"
echo "4. Try a different USB cable"
echo ""
echo "After reconnecting, run: sudo ./scripts/setup_flipper.sh" 