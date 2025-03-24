# Raspberry Pi to Flipper Zero Connection Guide

This guide explains how to connect your Raspberry Pi to the Flipper Zero for the HakPak project.

## Connection Methods

There are two primary ways to connect the Flipper Zero to the Raspberry Pi:

1. **USB Connection** (Recommended for beginners)
2. **UART Connection** (More reliable for embedded applications)

## USB Connection

The simplest way to connect your Flipper Zero to the Raspberry Pi is via USB:

1. Use a USB-C cable to connect the Flipper Zero to one of the USB ports on the Raspberry Pi
2. The Flipper Zero will be automatically detected as a serial device at `/dev/ttyACM0`
3. No additional wiring is required

## UART Connection (GPIO Pins)

For a more permanent and embedded solution, you can connect the Flipper Zero directly to the Raspberry Pi's GPIO pins:

### Pinout Diagram

| Raspberry Pi (GPIO) | Flipper Zero       | Function |
|---------------------|-------------------|----------|
| Pin 6 (GND)         | GND (Pin 18/GND)  | Ground   |
| Pin 8 (GPIO14/TXD)  | RX (Pin 14/PB7)   | Data TX  |
| Pin 10 (GPIO15/RXD) | TX (Pin 13/PB6)   | Data RX  |
| Pin 4 (5V)          | 5V (Optional)     | Power    |

### Visual Reference

```
Raspberry Pi GPIO Header
+-----+-----+
| 1   | 2   |
| 3   | 4   | <-- 5V (Optional)
| 5   | 6   | <-- GND
| 7   | 8   | <-- TXD (Connect to Flipper RX)
| 9   | 10  | <-- RXD (Connect to Flipper TX)
+-----+-----+
```

```
Flipper Zero GPIO Header
        +--------+
TX (PB6)| 13 | 14 |RX (PB7)
     GND| 17 | 18 |GND
        +--------+
```

### Step-by-Step Wiring Instructions

1. **Ensure both devices are powered off** before making connections
2. Connect Raspberry Pi's GND (Pin 6) to Flipper Zero's GND (Pin 18)
3. Connect Raspberry Pi's TXD (Pin 8) to Flipper Zero's RX (Pin 14/PB7)
4. Connect Raspberry Pi's RXD (Pin 10) to Flipper Zero's TX (Pin 13/PB6)
5. Optionally, connect Raspberry Pi's 5V (Pin 4) to Flipper Zero's 5V pin if you want to power the Flipper from the Pi

### Enabling UART on Raspberry Pi

Before the UART connection will work, you need to enable it on the Raspberry Pi:

```bash
sudo raspi-config
```

Navigate to:
- Interface Options
- Serial Port
- Disable "Would you like a login shell to be accessible over serial?"
- Enable "Would you like the serial port hardware to be enabled?"

Reboot the Raspberry Pi:
```bash
sudo reboot
```

## Configuring Flipper Zero

On the Flipper Zero, enable UART mode:

1. Go to `Settings` → `GPIO` → `USB-UART Bridge`
2. Select the appropriate baud rate (115200 is the default for HakPak)

## Testing the Connection

After connecting and configuring both devices, you can test the connection:

```bash
# For USB connection
ls -l /dev/ttyACM*

# For UART connection
ls -l /dev/ttyS0

# Test communication (USB)
echo "device_info" > /dev/ttyACM0
cat /dev/ttyACM0

# Test communication (UART)
echo "device_info" > /dev/ttyS0
cat /dev/ttyS0
```

## Troubleshooting

- **No device detected**: Check all physical connections
- **Permission issues**: Add your user to the dialout group: `sudo usermod -a -G dialout $USER`
- **Garbled text**: Verify baud rate settings match on both devices (115200 is recommended)
- **No response**: Make sure TX/RX aren't swapped; they should cross over (Pi TX → Flipper RX and Pi RX → Flipper TX)

## Further Resources

- [Raspberry Pi GPIO Documentation](https://www.raspberrypi.org/documentation/hardware/raspberrypi/gpio/README.md)
- [Flipper Zero GPIO Pinout](https://docs.flipperzero.one/gpio)
- [HakPak Documentation](https://github.com/caseybarajas/hakpak) 