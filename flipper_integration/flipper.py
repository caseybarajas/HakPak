#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
HakPak - Flipper Zero Integration
Main integration class for communicating with the Flipper Zero
"""

import time
import serial
import logging
from threading import Lock

# Setup logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("flipper_zero")

class FlipperConnectionError(Exception):
    """Exception raised when connection to Flipper Zero fails"""
    pass

class FlipperTimeoutError(Exception):
    """Exception raised when a command times out"""
    pass

class FlipperCommandError(Exception):
    """Exception raised when a command fails to execute"""
    pass

class FlipperZero:
    """
    Main class for communicating with Flipper Zero
    """
    
    def __init__(self, port='/dev/ttyACM0', baudrate=115200, timeout=1):
        """
        Initialize Flipper Zero connection
        
        Args:
            port (str): Serial port path
            baudrate (int): Baud rate (default: 115200)
            timeout (int): Serial communication timeout in seconds
        """
        self.port = port
        self.baudrate = baudrate
        self.timeout = timeout
        self.serial = None
        self.lock = Lock()
        self.connected = False
        self.last_response = None
        self.last_error = None
    
    def connect(self):
        """
        Establish connection to Flipper Zero
        
        Returns:
            bool: True if connection successful, False otherwise
        
        Raises:
            FlipperConnectionError: If connection fails
        """
        try:
            with self.lock:
                self.serial = serial.Serial(
                    port=self.port,
                    baudrate=self.baudrate,
                    timeout=self.timeout,
                    bytesize=serial.EIGHTBITS,
                    parity=serial.PARITY_NONE,
                    stopbits=serial.STOPBITS_ONE
                )
                
                # Flush any pending data
                self.serial.reset_input_buffer()
                self.serial.reset_output_buffer()
                
                # Try to get device info as a test
                response = self.send_command("device_info")
                if response:
                    self.connected = True
                    logger.info(f"Connected to Flipper Zero on {self.port}")
                    return True
                else:
                    self.connected = False
                    raise FlipperConnectionError("Failed to get device info")
        except serial.SerialException as e:
            self.connected = False
            self.last_error = str(e)
            logger.error(f"Failed to connect to Flipper Zero: {e}")
            raise FlipperConnectionError(f"Could not connect to port {self.port}: {e}")
    
    def disconnect(self):
        """
        Close connection to Flipper Zero
        
        Returns:
            bool: True if disconnection successful, False otherwise
        """
        try:
            with self.lock:
                if self.serial and self.serial.is_open:
                    self.serial.close()
                self.connected = False
                logger.info("Disconnected from Flipper Zero")
            return True
        except Exception as e:
            self.last_error = str(e)
            logger.error(f"Error disconnecting from Flipper Zero: {e}")
            return False
    
    def is_connected(self):
        """
        Check if connected to Flipper Zero
        
        Returns:
            bool: True if connected, False otherwise
        """
        return self.connected and self.serial and self.serial.is_open
    
    def send_command(self, command, timeout=5):
        """
        Send command to Flipper Zero and wait for response
        
        Args:
            command (str): Command to send
            timeout (int): Command timeout in seconds
        
        Returns:
            str: Response from Flipper Zero
        
        Raises:
            FlipperConnectionError: If not connected
            FlipperTimeoutError: If command times out
            FlipperCommandError: If command execution fails
        """
        if not self.is_connected():
            raise FlipperConnectionError("Not connected to Flipper Zero")
        
        try:
            with self.lock:
                # Prepare command
                cmd = f"{command}\r\n".encode()
                
                # Send command
                self.serial.write(cmd)
                self.serial.flush()
                
                # Wait for response with timeout
                start_time = time.time()
                response = ""
                
                while time.time() - start_time < timeout:
                    if self.serial.in_waiting:
                        chunk = self.serial.readline().decode('utf-8', errors='ignore').strip()
                        response += chunk + "\n"
                        
                        # Check if response is complete
                        if chunk.lower().startswith("ok") or chunk.lower().startswith("error"):
                            break
                    
                    time.sleep(0.1)
                
                if not response and time.time() - start_time >= timeout:
                    raise FlipperTimeoutError(f"Command '{command}' timed out")
                
                self.last_response = response.strip()
                
                # Check for error response
                if "error" in response.lower():
                    raise FlipperCommandError(f"Command '{command}' failed: {response}")
                
                return self.last_response
        except serial.SerialException as e:
            self.connected = False
            self.last_error = str(e)
            logger.error(f"Serial communication error: {e}")
            raise FlipperConnectionError(f"Serial communication error: {e}")
    
    def get_firmware_version(self):
        """
        Get Flipper Zero firmware version
        
        Returns:
            str: Firmware version
        """
        response = self.send_command("device_info")
        for line in response.split("\n"):
            if "firmware:" in line.lower():
                return line.split(":", 1)[1].strip()
        return "Unknown"
    
    def get_battery_level(self):
        """
        Get Flipper Zero battery level
        
        Returns:
            int: Battery percentage (0-100)
        """
        response = self.send_command("power info")
        for line in response.split("\n"):
            if "charge:" in line.lower():
                value = line.split(":", 1)[1].strip()
                if "%" in value:
                    return int(value.replace("%", ""))
                return int(value)
        return 0
    
    def get_device_info(self):
        """
        Get comprehensive device information
        
        Returns:
            dict: Device info including firmware, hardware, battery, etc.
        """
        response = self.send_command("device_info")
        info = {}
        
        for line in response.split("\n"):
            if ":" in line:
                key, value = line.split(":", 1)
                info[key.strip().lower()] = value.strip()
        
        # Get battery info
        try:
            battery_response = self.send_command("power info")
            for line in battery_response.split("\n"):
                if ":" in line:
                    key, value = line.split(":", 1)
                    info[f"battery_{key.strip().lower()}"] = value.strip()
        except:
            pass
            
        return info
    
    def run_app(self, app_name):
        """
        Start an app on Flipper Zero
        
        Args:
            app_name (str): Name of the app to run
            
        Returns:
            bool: True if app started successfully
        """
        try:
            self.send_command(f"app_start {app_name}")
            return True
        except:
            return False
            
    def exit_app(self):
        """
        Exit current app on Flipper Zero
        
        Returns:
            bool: True if app exited successfully
        """
        try:
            self.send_command("app_exit")
            return True
        except:
            return False
    
    def restart(self):
        """
        Restart Flipper Zero
        
        Returns:
            bool: True if restart command sent successfully
        """
        try:
            self.send_command("restart")
            self.connected = False
            return True
        except:
            return False 