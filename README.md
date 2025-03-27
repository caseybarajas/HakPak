# 🔐 HakPak: Portable Pentesting Platform (HEAVY WIP)

[![Kali Linux](https://img.shields.io/badge/Kali-268BEE?style=for-the-badge&logo=kalilinux&logoColor=white)](https://www.kali.org/)
[![Raspberry Pi](https://img.shields.io/badge/Raspberry%20Pi-C51A4A?style=for-the-badge&logo=Raspberry-Pi)](https://www.raspberrypi.org/)
[![Flipper Zero](https://img.shields.io/badge/Flipper%20Zero-FF6B00?style=for-the-badge&logo=flipper&logoColor=white)](https://flipperzero.one/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)](https://opensource.org/licenses/MIT)

## 🌟 Overview

HakPak is an all-in-one portable penetration testing platform that combines the software capabilities of a Raspberry Pi 4 running Kali Linux with the hardware interaction features of a Flipper Zero, all in a compact, battery-powered package controllable via a web interface.

![HakPak Device](https://placeholder-for-hakpak-image.com/hakpak.jpg)

Designed for security professionals and ethical hackers, HakPak provides a comprehensive toolkit for both wireless and physical penetration testing in a discreet, backpack-friendly form factor.

## ✨ Features

- **All-in-One Solution**: Combines Kali Linux capabilities with Flipper Zero's hardware hacking features
- **Web-Based Control Interface**: Operate all tools through a unified browser interface
- **Detachable Flipper Zero**: Quick-release mechanism for IR operations
- **Wireless Capabilities**: Built-in WiFi, Bluetooth, and RF scanning/transmission
- **Compact Design**: Easily fits in a backpack or laptop bag
- **Modular Architecture**: Expandable with additional sensors and hardware
- **Real-time System Monitoring**: View battery, CPU, memory, and temperature stats
- **Integrated Tool Management**: Launch and control common Kali tools directly from the web interface

## 🧰 Components

### Required Hardware

- Raspberry Pi 4 (4GB or 8GB RAM recommended)
- Flipper Zero
- 10,000-20,000mAh Power Bank
- Custom 3D Printed Case (files included)
- microSD Card (64GB+ recommended)
- Small USB hub (optional)
- Heat sinks/cooling solution for Pi
- **Jumper wires** for GPIO connection (optional, if using UART instead of USB)

### Software Stack

- Kali Linux ARM for Raspberry Pi
- Flask/Python Web Application Backend
- Socket.IO for real-time communication
- Bootstrap 5 for responsive frontend
- Flipper Zero integration scripts
- Power management utilities

## 📋 Installation

### Preparing the Raspberry Pi

1. Download and flash the latest Kali Linux ARM image to your microSD card:
```bash
# Download the latest Kali Linux ARM image
wget https://kali.download/arm-images/kali-2023.1/kali-linux-2023.1-raspberry-pi-arm64.img.xz

# Flash to microSD card (replace sdX with your device)
sudo dd if=kali-linux-2023.1-raspberry-pi-arm64.img.xz of=/dev/sdX bs=4M status=progress
```

2. Boot your Raspberry Pi with the flashed SD card and perform initial setup:
```bash
# Update the system
sudo apt update && sudo apt upgrade -y

# Clone this repository
git clone https://github.com/caseybarajas/hakpak.git
cd hakpak
```

3. Run the installation script:
```bash
# Make the installation script executable
sudo chmod +x scripts/install.sh

# Run the installation script
sudo ./scripts/install.sh
```

The installation script will:
1. Install required packages
2. Configure the WiFi access point
3. Set up the web interface
4. Configure the Flipper Zero connection
5. Enable services to start on boot

### Troubleshooting Installation

If you encounter issues during installation, use the verification script to diagnose problems:

```bash
sudo chmod +x scripts/verify_install.sh
sudo ./scripts/verify_install.sh
```

Common issues and solutions:

1. **Masked services**: If hostapd or dnsmasq are masked, unmask them manually:
```bash
sudo systemctl unmask hostapd
sudo systemctl unmask dnsmasq
sudo systemctl enable hostapd
sudo systemctl enable dnsmasq
```

2. **Service failures**: Check service logs for detailed error messages:
```bash
sudo journalctl -u hakpak -f
sudo journalctl -u hostapd -f
```

### Connecting the Flipper Zero

The Flipper Zero can be connected either via USB or UART:

#### USB Connection (Recommended)

1. Connect your Flipper Zero to the Raspberry Pi using a USB cable
2. Run the Flipper Zero setup script:
```bash
sudo chmod +x scripts/setup_flipper.sh
sudo ./scripts/setup_flipper.sh
```

3. If the Flipper Zero is not automatically detected, use the fix script:
```bash
sudo chmod +x scripts/fix_flipper_detection.sh
sudo ./scripts/fix_flipper_detection.sh
```

#### UART Connection (Alternative)

For UART connection, follow this wiring diagram:

| Raspberry Pi (GPIO) | Flipper Zero    | Function |
|---------------------|-----------------|----------|
| Pin 6 (GND)         | GND Pin (18)    | Ground   |
| Pin 8 (GPIO14/TXD)  | RX Pin (14/PB7) | Data TX  |
| Pin 10 (GPIO15/RXD) | TX Pin (13/PB6) | Data RX  |
| Pin 4 (5V)          | 5V Pin (Optional)| Power    |

For a visual connection diagram, see the [detailed pinout documentation](docs/pinout.md).

ASCII Connection Diagram:
```
Raspberry Pi   Flipper Zero    
--------------+--------------
GPIO 8 (TXD) -|-> Pin 14 (RX)
GPIO 10 (RXD) <-|- Pin 13 (TX)
Pin 6 (GND) ----|-- Pin 18 (GND)
Pin 4 (5V) -----|-- 5V (Optional)
```

To enable UART:
```bash
sudo raspi-config
# Navigate to Interface Options > Serial Port
# Disable serial login shell, but enable serial hardware
```

## 🚀 Usage

### Starting the System

1. Power on the system by connecting the battery pack
2. Wait approximately 60 seconds for boot sequence
3. Connect to the HakPak WiFi network (default SSID: `hakpak`)
   - Default password: `pentestallthethings`
4. Access the web interface at `http://hakpak.local` or `http://192.168.4.1`

### Web Interface

The web interface provides access to all functionality:

- **Dashboard**: System status, battery levels, active connections
- **Kali Tools**: Access to common Kali Linux pentesting tools
- **Flipper Control**: Interface with Flipper Zero functions
  - IR control (transmit and record signals)
  - RFID operations (read, write, clone)
  - SubGHz functions (receive and transmit on various frequencies)
- **Scan Tools**: WiFi, Bluetooth, and RF scanning utilities
- **Settings**: Configure network, services, and system settings

### Flipper Zero Integration Features

- **IR Control**: Send and record infrared signals for TVs, ACs, and other IR devices
- **RFID/NFC**: Read, write and emulate RFID cards and tags
- **SubGHz**: Capture and replay Sub-GHz signals from various devices
- **GPIO Control**: Interface with external hardware via GPIO pins
- **iButton**: Read and emulate iButton/1-Wire devices

## 🔧 Troubleshooting

Common issues and solutions:

- **System doesn't boot**: Check battery level and connections
- **Web interface not accessible**: Verify WiFi connection and IP address
  - Run `ifconfig` to check your network configuration
  - Try accessing via IP address (192.168.4.1) if hostname doesn't work
- **Flipper Zero not detected**: Check USB connection and run `sudo ./scripts/fix_flipper_detection.sh`
  - If using UART, verify the wiring connections
  - Check `dmesg` output for connection issues
- **WiFi access point not working**: Run `sudo systemctl status hostapd` and `sudo systemctl status dnsmasq`
  - If services are masked, run `sudo systemctl unmask hostapd` and `sudo systemctl unmask dnsmasq`
  - If services fail to start, check configuration files in `/etc/hostapd/` and `/etc/`

## 🛠️ Customization

### Hardware Expansion

The system can be expanded with additional hardware:

- GPS module for geolocation
- Additional antennas for extended range
- SDR (Software Defined Radio) for advanced RF capabilities
- External storage for increased capacity

### Software Customization

The HakPak web application is built on a modular Flask architecture:

- Controllers are located in `app/controllers/`
- Templates are in `app/templates/`
- Static files (CSS, JS) are in `app/static/`
- Configuration files are in `config/`

To add a new feature:
1. Create a new controller in `app/controllers/`
2. Add your template in `app/templates/`
3. Register your blueprint in `app/__init__.py`

## 📝 License

This project is licensed under the MIT License - see the LICENSE file for details.

## ⚠️ Legal Disclaimer

HakPak is designed for legitimate security testing and educational purposes only. Users are responsible for complying with all applicable laws. Unauthorized access to computer systems and networks is illegal and unethical. Always obtain proper authorization before conducting security tests.

---

**Made with ❤️ by Casey Barajas, for security enthusiasts**

[GitHub](https://github.com/caseybarajas/hakpak)
