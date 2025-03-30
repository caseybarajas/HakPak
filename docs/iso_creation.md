# HakPak ISO Creation Guide

This document explains how to create a custom Kali Linux ISO with HakPak pre-installed, ready to be burned to an SD card for Raspberry Pi use.

## Requirements

To build the ISO image, you'll need:

- A Linux machine (Ubuntu, Debian, or Kali recommended)
- Root/sudo access
- At least 20GB of free disk space
- The following packages installed:
  - debootstrap
  - parted
  - kpartx
  - qemu-user-static
  - rsync
  - wget
  - xz-utils

## Building the ISO

1. Make the build script executable:
   ```bash
   chmod +x scripts/build_iso.sh
   ```

2. Run the build script as root:
   ```bash
   sudo ./scripts/build_iso.sh
   ```

3. The script will prompt you for several options:
   - Work directory (temporary space for building)
   - Output directory (where to save the final image)
   - Kali version (current, 2023.3, etc.)
   - Architecture (arm64, armhf)
   - Raspberry Pi model (rpi4, rpi3, etc.)

4. The script will download the base Kali image, modify it to include HakPak, and create a compressed image file in your output directory.

## Writing the ISO to SD Card

### Linux

```bash
xz -dc hakpak-kali-rpi4-arm64.img.xz | sudo dd of=/dev/sdX bs=4M status=progress
```
Replace `/dev/sdX` with your SD card device (e.g., `/dev/sdb`).

### Windows

1. Download and install [balenaEtcher](https://www.balena.io/etcher/)
2. Select the compressed image file (hakpak-kali-rpi4-arm64.img.xz)
3. Select your SD card
4. Click "Flash!"

### macOS

```bash
xz -dc hakpak-kali-rpi4-arm64.img.xz | sudo dd of=/dev/rdiskX bs=4m
```
Replace `/dev/rdiskX` with your SD card device (e.g., `/dev/rdisk2`).

## First Boot

When you boot your Raspberry Pi with the newly created SD card:

1. The system will automatically start and run the HakPak setup
2. After setup completes, the system will reboot
3. Connect to the WiFi network named "hakpak" with password "pentestallthethings"
4. Access the web interface at http://192.168.4.1

## Customization

The default configuration uses:
- SSID: hakpak
- Password: pentestallthethings
- IP Address: 192.168.4.1
- Web Admin Password: hakpak

If you want different default values, you can modify the `scripts/hakpak_setup.sh` file before running the build script.

## Troubleshooting

If you encounter issues:

1. Check if the WiFi adapter is detected:
   ```bash
   iw dev
   ```

2. Run the health check script:
   ```bash
   sudo /opt/hakpak/scripts/health_check.sh
   ```

3. Check service status:
   ```bash
   sudo systemctl status hostapd dnsmasq nginx hakpak
   ```

4. View logs:
   ```bash
   sudo journalctl -xeu hakpak-firstboot
   ```

## Verified Platforms

The HakPak ISO has been tested on:
- Raspberry Pi 4 Model B
- Raspberry Pi 3 Model B+

Other models may work but are not officially supported. 