# 🔐 HakPak: Portable Pentesting Platform

[![Kali Linux](https://img.shields.io/badge/Kali-268BEE?style=for-the-badge&logo=kalilinux&logoColor=white)](https://www.kali.org/)
[![Raspberry Pi](https://img.shields.io/badge/Raspberry%20Pi-C51A4A?style=for-the-badge&logo=Raspberry-Pi)](https://www.raspberrypi.org/)
[![Flipper Zero](https://img.shields.io/badge/Flipper%20Zero-FF6B00?style=for-the-badge&logo=flipper&logoColor=white)](https://flipperzero.one/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)](https://opensource.org/licenses/MIT)

## 🌟 Overview

hakpak is an all-in-one portable penetration testing platform that combines the software capabilities of a Raspberry Pi 4 running Kali Linux with the hardware interaction features of a Flipper Zero, all in a compact, battery-powered package controllable via a web interface.

![HakPak Device](https://placeholder-for-hakpak-image.com/hakpak.jpg)

Designed for security professionals and ethical hackers, hakpak provides a comprehensive toolkit for both wireless and physical penetration testing in a discreet, backpack-friendly form factor.

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

```bash
# Download the latest Kali Linux ARM image
wget https://kali.download/arm-images/kali-2023.1/kali-linux-2023.1-raspberry-pi-arm64.img.xz

# Flash to microSD card (replace sdX with your device)
sudo dd if=kali-linux-2023.1-raspberry-pi-arm64.img.xz of=/dev/sdX bs=4M status=progress

# Boot the Pi and update
sudo apt update && sudo apt upgrade -y

# Clone this repository
git clone https://github.com/caseybarajas/hakpak.git
cd hakpak

# Run the installation script
sudo ./scripts/install.sh
```

The installation script will:
1. Install required packages
2. Configure the WiFi access point
3. Set up the web interface
4. Configure the Flipper Zero connection
5. Enable services to start on boot

### Connecting the Flipper Zero

#### Wiring Diagram - Raspberry Pi to Flipper Zero

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

**Notes:**
- The Flipper Zero can also be connected via USB, which is the default connection method.
- For UART connection, make sure to enable UART in the Raspberry Pi configuration.

To enable UART:
```bash
sudo raspi-config
# Navigate to Interface Options > Serial Port
# Disable serial login shell, but enable serial hardware
```

After wiring, run the Flipper Zero setup script:
```bash
sudo ./scripts/setup_flipper.sh
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
  - Network tools (nmap, wireshark, netdiscover)
  - Web tools (burpsuite, sqlmap, dirb)
  - Wireless tools (aircrack-ng, wifite, kismet)
  - Exploitation tools (metasploit, hydra, john)
- **Flipper Control**: Interface with Flipper Zero functions
- **Scan Tools**: WiFi, Bluetooth, and RF scanning utilities
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

The HakPak web application is built on a modular Flask architecture:

- Controllers are located in `app/controllers/`
- Templates are in `app/templates/`
- Static files (CSS, JS) are in `app/static/`
- Configuration files are in `config/`

To add a new feature:
1. Create a new controller in `app/controllers/`
2. Add your template in `app/templates/`
3. Register your blueprint in `app/__init__.py`

## 🔧 Troubleshooting

Common issues and solutions:

- **System doesn't boot**: Check battery level and connections
- **Web interface not accessible**: Verify WiFi connection and IP address
  - Run `ifconfig` to check your network configuration
  - Try accessing via IP address (192.168.4.1) if hostname doesn't work
- **Flipper Zero not detected**: Check USB connection and run `sudo ./scripts/detect_flipper.sh`
  - If using UART, verify the wiring connections
  - Check `dmesg` output for connection issues
- **WiFi access point not working**: Run `sudo systemctl status hostapd` and `sudo systemctl status dnsmasq`

## 📁 Project Structure

```
hakpak/
├── app/                    # Main application directory
│   ├── controllers/        # Flask route controllers
│   ├── models/             # Data models
│   ├── static/             # Static assets
│   │   ├── css/            # Stylesheets
│   │   ├── js/             # JavaScript files
│   │   └── img/            # Images
│   ├── templates/          # Jinja2 templates
│   │   ├── dashboard/      # Dashboard views
│   │   ├── flipper/        # Flipper Zero views
│   │   ├── kali_tools/     # Kali tools views
│   │   ├── scan_tools/     # Scanning tools views
│   │   └── settings/       # Settings views
│   └── __init__.py         # Application factory
├── config/                 # Configuration files
│   ├── hakpak.service      # Systemd service file
│   └── nginx-hakpak        # Nginx configuration
├── docs/                   # Documentation
│   └── pinout.md           # Pinout documentation
├── flipper_integration/    # Flipper Zero integration code
├── scripts/                # Setup and utility scripts
│   ├── install.sh          # Main installation script
│   └── setup_flipper.sh    # Flipper Zero setup script
├── requirements.txt        # Python dependencies
├── wsgi.py                 # WSGI entry point
├── LICENSE                 # MIT License
└── README.md               # This file
```

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