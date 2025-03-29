# 🔐 HakPak: Portable Pentesting Platform (HEAVY WIP)

[![Kali Linux](https://img.shields.io/badge/Kali-268BEE?style=for-the-badge&logo=kalilinux&logoColor=white)](https://www.kali.org/)
[![Raspberry Pi](https://img.shields.io/badge/Raspberry%20Pi-C51A4A?style=for-the-badge&logo=Raspberry-Pi)](https://www.raspberrypi.org/)
[![Flipper Zero](https://img.shields.io/badge/Flipper%20Zero-FF6B00?style=for-the-badge&logo=flipper&logoColor=white)](https://flipperzero.one/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)](https://opensource.org/licenses/MIT)

## 🌟 Overview

HakPak is an all-in-one portable penetration testing platform that combines the software capabilities of a Raspberry Pi running Kali Linux with the hardware interaction features of a Flipper Zero, all in a compact, battery-powered package controllable via a web interface.

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
- microSD Card (64GB+ recommended)
- WiFi adapter (built-in or external)
- Optional: Custom 3D Printed Case (files included)
- Optional: Small USB hub
- Optional: Heat sinks/cooling solution for Pi

### Software Stack

- Kali Linux ARM for Raspberry Pi
- Flask/Python Web Application Backend
- Socket.IO for real-time communication
- Bootstrap 5 for responsive frontend
- Flipper Zero integration scripts
- Power management utilities

## 📋 Installation

### Quick Installation (Recommended)

1. Start with a fresh installation of Kali Linux on your Raspberry Pi

2. Clone the repository and run the setup script:
```bash
# Update the system
sudo apt update && sudo apt upgrade -y

# Clone this repository
git clone https://github.com/caseybarajas/hakpak.git
cd hakpak

# Run the automated setup script
sudo chmod +x scripts/hakpak_setup.sh
sudo ./scripts/hakpak_setup.sh
```

The setup script will automatically:
- Install all required dependencies
- Configure the WiFi access point
- Set up network routing
- Configure all services
- Create the web interface
- Set up Flipper Zero connection

3. After setup completes (or after a reboot), connect to the `hakpak` WiFi network:
   - Password: `pentestallthethings`
   - Access the web interface at `http://192.168.4.1`

### Manual Installation (Advanced Users)

If you prefer to install components manually:

1. Install required packages:
```bash
sudo apt update
sudo apt install hostapd dnsmasq nginx python3-pip python3-venv git usbutils rfkill iw wireless-tools
```

2. Configure network services:
```bash
# Configure hostapd
sudo nano /etc/hostapd/hostapd.conf
# Configure dnsmasq
sudo nano /etc/dnsmasq.conf
# Enable services
sudo systemctl unmask hostapd
sudo systemctl enable hostapd dnsmasq
```

3. Set up the Python environment:
```bash
python3 -m venv /opt/hakpak/venv
/opt/hakpak/venv/bin/pip install -r requirements.txt
```

4. Create and enable the HakPak service:
```bash
sudo cp config/hakpak.service /etc/systemd/system/
sudo systemctl enable hakpak
sudo systemctl start hakpak
```

See the [detailed installation guide](docs/installation.md) for complete manual installation instructions.

## 🚀 Usage

### Connecting to HakPak

1. Power on your Raspberry Pi
2. Connect to the `hakpak` WiFi network
   - Password: `pentestallthethings`
3. Open your browser and navigate to `http://192.168.4.1`
4. Log in with default credentials:
   - Username: `admin`
   - Password: `hakpak`

### Web Interface

The web interface provides easy access to all functionality:

- **Dashboard**: System status and monitoring
- **Kali Tools**: Access to common Kali Linux tools
- **Flipper Zero**: Control your Flipper Zero device
  - IR operations (transmit, record)
  - RFID operations (read, write, emulate)
  - SubGHz functionality
- **Network Tools**: WiFi/Bluetooth scanning and attack tools
- **Settings**: Configure device and connection settings

### Connecting Your Flipper Zero

Simply connect your Flipper Zero to the Raspberry Pi via USB. The system will automatically detect and configure the device. For detailed setup, see [Flipper Zero setup guide](docs/flipper_setup.md).

## 🔧 Troubleshooting

If you encounter any issues, try these troubleshooting steps:

1. **Run the health check script**:
```bash
sudo ./scripts/health_check.sh
```

2. **Check all services are running**:
```bash
sudo systemctl status hostapd dnsmasq nginx hakpak
```

3. **Restart the services**:
```bash
sudo systemctl restart hostapd dnsmasq nginx hakpak
```

4. **Verify WiFi interface**:
```bash
sudo iw dev
```

5. **If nothing else works, reboot**:
```bash
sudo reboot
```

For more detailed troubleshooting, see [troubleshooting guide](docs/troubleshooting.md).

## 🔄 Updates

To update HakPak to the latest version:

```bash
cd ~/hakpak
git pull
sudo ./scripts/hakpak_setup.sh
```

## 🛠️ Customization

### Configuration Options

Primary settings can be modified in the `config/` directory:
- `config/hakpak.conf`: Main application settings
- `/etc/hostapd/hostapd.conf`: WiFi access point settings
- `/etc/dnsmasq.conf`: DHCP and DNS settings

### Adding Custom Features

HakPak follows a modular architecture for easy extension:
- Add new controllers in `app/controllers/`
- Add new templates in `app/templates/`
- Register new blueprints in `app/__init__.py`

## 📝 License

This project is licensed under the MIT License - see the LICENSE file for details.

## ⚠️ Legal Disclaimer

HakPak is designed for legitimate security testing and educational purposes only. Users are responsible for complying with all applicable laws. Unauthorized access to computer systems and networks is illegal and unethical. Always obtain proper authorization before conducting security tests.

---

**Made with ❤️ by Casey Barajas, for security enthusiasts**

[GitHub](https://github.com/caseybarajas/hakpak)
