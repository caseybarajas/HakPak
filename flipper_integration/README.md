# Flipper Zero Integration for HakPak

This directory contains the Python implementation for integrating the Flipper Zero with the HakPak platform.

## Overview

The Flipper Zero integration allows the HakPak to communicate with and control a Flipper Zero device, providing access to its RF, IR, NFC, and other capabilities through a user-friendly web interface.

## Connection Guide

### Physical Connection

The Flipper Zero can be connected to the Raspberry Pi via USB or UART:

#### USB Connection (Recommended)

Simply connect the Flipper Zero to one of the USB ports on the Raspberry Pi using a USB-C cable. The device will appear as a serial device at `/dev/ttyACM0` or similar.

#### UART Connection

For a direct UART connection, connect the following pins:

| Raspberry Pi Pin | Flipper Zero Pin |
| ---------------- | ---------------- |
| GND (Pin 6)      | GND              |
| TX (GPIO14/Pin 8)| RX               |
| RX (GPIO15/Pin 10)| TX              |
| 3.3V (Pin 1)*    | 3.3V*            |

*Note: Power connection is optional if the Flipper Zero is powered by its battery.

**Pinout Diagram:**

```
Raspberry Pi:                   Flipper Zero:
┌───────────────┐               ┌───────────────┐
│ ○ ○ ○ ○ ○ ○ ○ │               │               │
│ ○ ○ ○ ○ ○ ○ ○ │               │  ┌─────────┐  │
│  1         13 │               │  │ ○ ○ ○ ○ ○│  │
│ ○┼─ 3.3V      │               │  │ 5V G T R 3│  │
│ ○ ○ ○ ○ ○ ○ ○ │               │  └─────────┘  │
│ ○ ○ ○┼─ GND   │               │               │
│       Pin 6   │               │               │
│ ○ ○┼─ TX      │               │               │
│     Pin 8     │               │      ║  ║     │
│ ○ ○┼─ RX      │               │      ║  ║     │
│     Pin 10    │               │      ║  ║     │
│ ○ ○ ○ ○ ○ ○ ○ │               │      ╚══╝     │
│ ○ ○ ○ ○ ○ ○ ○ │               └───────────────┘
└───────────────┘                  USB-C Port
```

### Software Configuration

1. Install required Python packages:
   ```
   pip install pyserial
   ```

2. Configure the connection in `/etc/hakpak/flipper.conf`:
   ```
   FLIPPER_PORT="/dev/ttyACM0"  # Change if using a different port
   FLIPPER_BAUD=115200
   ```

## Communication Protocol

The integration communicates with the Flipper Zero using text-based commands over a serial connection (USB or UART). The communication follows a simple request-response protocol.

### Command Structure

Commands sent to the Flipper Zero follow this format:
```
command [arguments...]
```

The response is typically returned as text, and may include JSON-formatted data for more complex responses.

### Available Commands

The Flipper Zero can accept a variety of commands:

- `device_info` - Get device information including firmware version
- `gpio_get [pin]` - Get the state of a GPIO pin
- `gpio_set [pin] [value]` - Set a GPIO pin
- `ir_send [file_path]` - Send an IR signal
- `ir_record [file_path]` - Record an IR signal
- `ir_list` - List available IR signals
- `subghz_tx [file_path]` - Transmit a SubGHz signal
- `subghz_rx [frequency]` - Receive SubGHz signals
- `nfc_read` - Scan for NFC cards
- `nfc_emulate [file_path]` - Emulate an NFC card
- `rfid_read` - Scan for RFID cards
- `rfid_emulate [file_path]` - Emulate an RFID card
- `app_start [app_name]` - Start an app on the Flipper
- `app_exit` - Exit the current app
- `restart` - Restart the Flipper Zero

## Integration Classes

The integration is structured with the following Python classes:

### FlipperZero

The main class for communicating with the Flipper Zero device:

- Manages the serial connection
- Sends commands and receives responses
- Handles errors and timeouts

### IRController

Specializes in IR functionality:

- Sending and recording IR signals
- Managing IR signal files
- Listing available IR signals

### RFIDController

Handles RFID operations:

- Reading RFID tags
- Emulating RFID tags
- Saving and loading RFID data

### SubGHzController

Manages SubGHz operations:

- Transmitting SubGHz signals
- Receiving and analyzing SubGHz signals
- Managing saved SubGHz captures

## Implementation Details

The implementation is built on top of the pyserial library and provides a high-level interface for interacting with the Flipper Zero. Error handling is robust, with specific exception types for different error conditions.

## Error Handling

The integration includes comprehensive error handling:

- `FlipperConnectionError` - Raised when connection cannot be established
- `FlipperTimeoutError` - Raised when a command times out
- `FlipperCommandError` - Raised when a command fails to execute
- `FlipperNotConnectedError` - Raised when attempting to use a disconnected device

## Future Improvements

Planned enhancements for the integration:

- Implement NFC controller for NFC operations
- Add Bluetooth connectivity option
- Support for custom app execution
- Integration with HakPak's logging system
- Automated tests and script generation 