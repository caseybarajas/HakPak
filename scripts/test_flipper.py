#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
HakPak - Flipper Zero Test Script
Test connectivity and basic functionality of the Flipper Zero integration
"""

import os
import sys
import time
import argparse
import logging

# Add the parent directory to the path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

# Import Flipper integration
from flipper_integration import FlipperZero, IRController, FlipperConnectionError

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger("test_flipper")

def main():
    """
    Main function to test Flipper Zero connectivity and features
    """
    # Parse command line arguments
    parser = argparse.ArgumentParser(description='Test Flipper Zero connectivity')
    parser.add_argument('--port', default='/dev/ttyACM0', help='Serial port for Flipper Zero')
    parser.add_argument('--baudrate', type=int, default=115200, help='Baud rate')
    parser.add_argument('--test-ir', action='store_true', help='Test IR functionality')
    args = parser.parse_args()

    # Create Flipper Zero instance
    flipper = FlipperZero(port=args.port, baudrate=args.baudrate)
    
    # Test connection
    try:
        logger.info(f"Connecting to Flipper Zero on {args.port}...")
        flipper.connect()
        logger.info("Successfully connected to Flipper Zero!")
        
        # Get device info
        logger.info("Getting device information...")
        firmware = flipper.get_firmware_version()
        logger.info(f"Firmware version: {firmware}")
        
        try:
            battery = flipper.get_battery_level()
            logger.info(f"Battery level: {battery}%")
        except Exception as e:
            logger.warning(f"Couldn't get battery level: {e}")
        
        # Test IR functionality if requested
        if args.test_ir:
            logger.info("Testing IR functionality...")
            ir = IRController(flipper)
            
            # List available IR signals
            logger.info("Listing available IR signals...")
            signals = ir.list_signals()
            
            if signals:
                logger.info(f"Found {len(signals)} IR signals:")
                for signal in signals:
                    logger.info(f"  - {signal}")
                
                # Optionally test sending a signal
                if len(signals) > 0 and input("Send the first IR signal? (y/n): ").lower() == 'y':
                    signal_name = signals[0]
                    logger.info(f"Sending IR signal: {signal_name}")
                    ir.send_signal(signal_name)
            else:
                logger.info("No IR signals found.")
                
                # Optionally record a new signal
                if input("Record a new IR signal? (y/n): ").lower() == 'y':
                    signal_name = input("Enter name for the new signal: ")
                    logger.info(f"Point a remote control at the Flipper Zero and press a button...")
                    try:
                        ir.record_signal(signal_name)
                        logger.info(f"Signal '{signal_name}' recorded successfully!")
                    except Exception as e:
                        logger.error(f"Failed to record signal: {e}")
        
        # Disconnect
        logger.info("Disconnecting from Flipper Zero...")
        flipper.disconnect()
        logger.info("Disconnected.")
        
    except FlipperConnectionError as e:
        logger.error(f"Failed to connect to Flipper Zero: {e}")
        sys.exit(1)
    except Exception as e:
        logger.error(f"Unexpected error: {e}")
        if flipper.is_connected():
            flipper.disconnect()
        sys.exit(1)

if __name__ == "__main__":
    main() 