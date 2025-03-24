# 🔐 HakPak: Portable Pentesting Platform

[![Kali Linux](https://img.shields.io/badge/Kali-268BEE?style=for-the-badge&logo=kalilinux&logoColor=white)](https://www.kali.org/)
[![Raspberry Pi](https://img.shields.io/badge/Raspberry%20Pi-C51A4A?style=for-the-badge&logo=Raspberry-Pi)](https://www.raspberrypi.org/)
[![Flipper Zero](https://img.shields.io/badge/Flipper%20Zero-FF6B00?style=for-the-badge&logo=flipper&logoColor=white)](https://flipperzero.one/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)](https://opensource.org/licenses/MIT)

## 🌟 Overview

hakpak is an all-in-one portable penetration testing platform that combines the software capabilities of a Raspberry Pi 4 running Kali Linux with the hardware interaction features of a Flipper Zero, all in a compact, battery-powered package controllable via a web interface.

(put image here when done)

Designed for security professionals and ethical hackers, hakpak provides a comprehensive toolkit for both wireless and physical penetration testing in a discreet, backpack-friendly form factor.

## ✨ Features

- **All-in-One Solution**: Combines Kali Linux capabilities with Flipper Zero's hardware hacking features
- **Web-Based Control Interface**: Operate all tools through a unified browser interface
- **Detachable Flipper Zero**: Quick-release mechanism for IR operations
- **Wireless Capabilities**: Built-in WiFi, Bluetooth, and RF scanning/transmission
- **Compact Design**: Easily fits in a backpack or laptop bag
- **Modular Architecture**: Expandable with additional sensors and hardware

## 🧰 Components

### Required Hardware

- Raspberry Pi 4 (4GB or 8GB RAM recommended)
- Flipper Zero
- 10,000-20,000mAh Power Bank
- Custom 3D Printed Case (files included)
- microSD Card (64GB+ recommended)
- Small USB hub (optional)
- Heat sinks/cooling solution for Pi

### Software Stack

- Kali Linux ARM for Raspberry Pi
- Custom Web Interface (Flask/Python backend)
- Flipper Zero integration scripts
- Websocket implementation for real-time control
- Power management utilities

## 📋 Installation

### Preparing the Raspberry Pi

```bash
# Download the latest Kali Linux ARM image
wget https://kali.download/arm-images/kali-2023.1/kali-linux-2023.1-raspberry-pi-arm64.img.xz

# Flash to microSD card (replace sdX with your device)
sudo dd if=kali-linux-2023.1-raspberry-pi-arm64.img.xz of=/dev/sdX bs=4M status=progress

# Boot the Pi and update
sudo apt update && sudo apt upgrade -y

# Install required packages
sudo apt install -y git python3-pip flask nginx

# Clone this repository
git clone https://github.com/caseybarajas/hakpak.git
cd hakpak

# Install Python dependencies
pip3 install -r requirements.txt
```

### Setting up the Web Interface

```bash
# Configure web service to start on boot
sudo cp config/hakpak.service /etc/systemd/system/
sudo systemctl enable hakpak.service
sudo systemctl start hakpak.service

# Configure Nginx as reverse proxy
sudo cp config/nginx-hakpak /etc/nginx/sites-available/
sudo ln -s /etc/nginx/sites-available/nginx-hakpak /etc/nginx/sites-enabled/
sudo systemctl restart nginx
```

### Connecting the Flipper Zero

1. Connect Flipper Zero to the Raspberry Pi via USB (or serial preferred)
2. Install qFlipper CLI on the Pi:
   ```bash
   cd /opt
   git clone https://github.com/flipperdevices/qFlipper.git
   cd qFlipper
   ./build_cli.sh
   ```
3. Run the setup script to configure the Flipper:
   ```bash
   cd ~/hakpak
   sudo ./setup_flipper.sh
   ```

## 🚀 Usage

### Starting the System

1. Power on the system by connecting the battery pack
2. Wait approximately 60 seconds for boot sequence
3. Connect to the hakpak WiFi network (default SSID: `hakpak`)
   - Default password: `pentestallthethings`
4. Access the web interface at `http://hakpak.local` or `http://192.168.4.1`

### Web Interface

The web interface provides access to all functionality:

- **Dashboard**: System status, battery levels, active connections
- **Kali Tools**: Access to common Kali Linux pentesting tools
- **Flipper Control**: Interface with Flipper Zero functions
- **Scan Tools**: WiFi, Bluetooth, and RF scanning utilities
- **Logs**: System and operation logs
- **Settings**: Configure network, services, and system settings

### Detaching the Flipper Zero

1. Navigate to the "Flipper Control" section in the web interface
2. Click "Prepare for Detachment"
3. Wait for the confirmation message
4. Detach the Flipper Zero
5. Perform IR operations as needed
6. Reattach when finished

## 🛠️ Customization

### Hardware Expansion

The system can be expanded with additional hardware:

- GPS module for geolocation
- Additional antennas for extended range
- SDR (Software Defined Radio) for advanced RF capabilities
- External storage for increased capacity

### Software Customization

- Custom tool modules can be added to `/opt/hakpak/modules/`
- New Flipper Zero integrations can be developed using the API
- The web interface is built on Bootstrap and can be themed

## 🔧 Troubleshooting

Common issues and solutions:

- **System doesn't boot**: Check battery level and connections
- **Web interface not accessible**: Verify WiFi connection and IP address
- **Flipper Zero not detected**: Check USB connection and run `sudo ./scripts/detect_flipper.sh`

## 🔮 Future Development

- [ ] Integration with additional hardware (WiFi Pineapple, etc.)
- [ ] Enhanced power management for longer battery life
- [ ] Mobile app interface (iOS/Android)
- [ ] Mesh networking capabilities
- [ ] AI-assisted attack vector suggestions
- [ ] Automated reporting system

## 📝 License

This project is licensed under the MIT License - see the LICENSE file for details.

## ⚠️ Legal Disclaimer

hakpak is designed for legitimate security testing and educational purposes only. Users are responsible for complying with all applicable laws. Unauthorized access to computer systems and networks is illegal and unethical. Always obtain proper authorization before conducting security tests.

---

**Made with ❤️ by Casey Barajas, for security enthusiasts**

[GitHub](https://github.com/caseybarajas/hakpak)