#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
HakPak - Flipper Zero Integration
IR (Infrared) Controller for Flipper Zero
"""

import os
import time
import logging
from .flipper import FlipperConnectionError, FlipperCommandError, FlipperTimeoutError

# Setup logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("flipper_ir")

class IRController:
    """
    Controller class for Flipper Zero IR functionality
    """
    
    def __init__(self, flipper):
        """
        Initialize IR Controller
        
        Args:
            flipper (FlipperZero): FlipperZero instance
        """
        self.flipper = flipper
        self.signals_dir = "/ext/infrared"  # Default IR signals directory on Flipper
    
    def send_signal(self, signal_name):
        """
        Send an IR signal from Flipper Zero
        
        Args:
            signal_name (str): Name of the IR signal to send
        
        Returns:
            bool: True if signal sent successfully, False otherwise
            
        Raises:
            FlipperCommandError: If the command fails
        """
        try:
            # Start IR app if not already running
            self.flipper.run_app("IR")
            time.sleep(0.5)  # Wait for app to start
            
            # Send IR signal
            response = self.flipper.send_command(f"ir_send {signal_name}")
            logger.info(f"Sent IR signal: {signal_name}")
            
            # Check response
            if "sent" in response.lower() or "ok" in response.lower():
                return True
            else:
                logger.warning(f"Failed to send IR signal: {response}")
                return False
        except FlipperCommandError as e:
            logger.error(f"Error sending IR signal: {e}")
            raise
        except Exception as e:
            logger.error(f"Unexpected error sending IR signal: {e}")
            return False
    
    def record_signal(self, signal_name, timeout=20):
        """
        Record an IR signal with Flipper Zero
        
        Args:
            signal_name (str): Name to save the recorded signal as
            timeout (int): Recording timeout in seconds
            
        Returns:
            bool: True if signal recorded successfully, False otherwise
            
        Raises:
            FlipperCommandError: If the command fails
            FlipperTimeoutError: If recording times out
        """
        try:
            # Start IR app if not already running
            self.flipper.run_app("IR")
            time.sleep(0.5)  # Wait for app to start
            
            # Start recording
            logger.info(f"Recording IR signal as: {signal_name}")
            response = self.flipper.send_command(f"ir_record {signal_name}", timeout=timeout)
            
            # Check response
            if "recorded" in response.lower() or "saved" in response.lower() or "ok" in response.lower():
                logger.info(f"Successfully recorded IR signal: {signal_name}")
                return True
            else:
                logger.warning(f"Failed to record IR signal: {response}")
                return False
        except FlipperTimeoutError:
            logger.error(f"Timeout while recording IR signal: {signal_name}")
            # Try to cancel recording
            self.flipper.send_command("ir_record_cancel")
            raise
        except FlipperCommandError as e:
            logger.error(f"Error recording IR signal: {e}")
            raise
        except Exception as e:
            logger.error(f"Unexpected error recording IR signal: {e}")
            return False
    
    def list_signals(self):
        """
        List available IR signals on Flipper Zero
        
        Returns:
            list: List of available IR signal names
        """
        try:
            # Start IR app if not already running
            self.flipper.run_app("IR")
            time.sleep(0.5)  # Wait for app to start
            
            # List signals
            response = self.flipper.send_command("ir_list")
            
            # Parse response
            signals = []
            for line in response.split('\n'):
                line = line.strip()
                if line and not line.startswith("ir_list") and not line.lower().startswith("ok"):
                    signals.append(line)
            
            return signals
        except Exception as e:
            logger.error(f"Error listing IR signals: {e}")
            return []
    
    def delete_signal(self, signal_name):
        """
        Delete an IR signal from Flipper Zero
        
        Args:
            signal_name (str): Name of the IR signal to delete
            
        Returns:
            bool: True if signal deleted successfully, False otherwise
        """
        try:
            # Start IR app if not already running
            self.flipper.run_app("IR")
            time.sleep(0.5)  # Wait for app to start
            
            # Delete signal
            response = self.flipper.send_command(f"ir_delete {signal_name}")
            
            # Check response
            if "deleted" in response.lower() or "ok" in response.lower():
                logger.info(f"Deleted IR signal: {signal_name}")
                return True
            else:
                logger.warning(f"Failed to delete IR signal: {response}")
                return False
        except Exception as e:
            logger.error(f"Error deleting IR signal: {e}")
            return False
    
    def rename_signal(self, old_name, new_name):
        """
        Rename an IR signal on Flipper Zero
        
        Args:
            old_name (str): Current name of the IR signal
            new_name (str): New name for the IR signal
            
        Returns:
            bool: True if signal renamed successfully, False otherwise
        """
        try:
            # Start IR app if not already running
            self.flipper.run_app("IR")
            time.sleep(0.5)  # Wait for app to start
            
            # Rename signal
            response = self.flipper.send_command(f"ir_rename {old_name} {new_name}")
            
            # Check response
            if "renamed" in response.lower() or "ok" in response.lower():
                logger.info(f"Renamed IR signal from {old_name} to {new_name}")
                return True
            else:
                logger.warning(f"Failed to rename IR signal: {response}")
                return False
        except Exception as e:
            logger.error(f"Error renaming IR signal: {e}")
            return False 