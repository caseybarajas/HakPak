#!/bin/bash

# Exit on error
set -e

echo "🔐 Installing HakPak - Portable Pentesting Platform..."

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root"
    exit 1
fi

# Create necessary directories
echo "Creating directories..."
mkdir -p /etc/hakpak
mkdir -p /var/log/hakpak
mkdir -p /opt/hakpak

# Install system dependencies
echo "Installing system dependencies..."
apt-get update
apt-get install -y \
    python3 \
    python3-pip \
    python3-venv \
    nginx \
    hostapd \
    dnsmasq \
    usbutils \
    git

# Create Python virtual environment
echo "Setting up Python environment..."
python3 -m venv /opt/hakpak/venv
source /opt/hakpak/venv/bin/activate

# Install Python dependencies
echo "Installing Python dependencies..."
pip install -r requirements.txt

# Copy application files
echo "Installing HakPak application..."
cp -r app /opt/hakpak/
cp -r flipper_integration /opt/hakpak/
cp -r scripts /opt/hakpak/
cp wsgi.py /opt/hakpak/
cp config/hakpak.service /etc/systemd/system/
cp config/nginx-hakpak /etc/nginx/sites-available/hakpak

# Configure Nginx
echo "Configuring Nginx..."
ln -sf /etc/nginx/sites-available/hakpak /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Configure WiFi Access Point
echo "Configuring WiFi Access Point..."
cp config/hostapd.conf /etc/hostapd/
cp config/dnsmasq.conf /etc/
cp config/interfaces /etc/network/

# Configure hostapd to use our config file
sed -i 's|#DAEMON_CONF=""|DAEMON_CONF="/etc/hostapd/hostapd.conf"|' /etc/default/hostapd

# Set up Flipper Zero udev rules
echo "Setting up Flipper Zero udev rules..."
cat > /etc/udev/rules.d/42-flipper.rules << EOF
SUBSYSTEM=="tty", ATTRS{idVendor}=="0483", ATTRS{idProduct}=="5740", SYMLINK+="flipper"
EOF

# Create default configuration
echo "Creating default configuration..."
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
echo "Setting permissions..."
chown -R root:root /opt/hakpak
chmod -R 755 /opt/hakpak
chmod +x /opt/hakpak/scripts/*.sh

# Enable and start services
echo "Enabling services..."
systemctl daemon-reload

# Unmask and enable hostapd and dnsmasq
echo "Unmasking services..."
systemctl unmask hostapd
systemctl unmask dnsmasq
systemctl enable hakpak
systemctl enable hostapd
systemctl enable dnsmasq

# Restart networking and services
echo "Starting services..."
systemctl restart networking
systemctl restart hostapd
systemctl restart dnsmasq
systemctl restart nginx
systemctl start hakpak

echo "✅ HakPak installation complete!"
echo "Access the web interface at http://hakpak.local or http://192.168.4.1"
echo "Default WiFi SSID: hakpak"
echo "Default WiFi Password: pentestallthethings" 