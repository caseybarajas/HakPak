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
    
    # Constants
    APP_NAME = "IR"
    APP_START_DELAY = 0.5  # seconds
    SIGNALS_DIR = "/ext/infrared"
    
    def __init__(self, flipper):
        """
        Initialize IR Controller
        
        Args:
            flipper (FlipperZero): FlipperZero instance
        """
        self.flipper = flipper
    
    def _ensure_ir_app_running(self):
        """
        Ensure the IR app is running on the Flipper Zero
        
        Raises:
            FlipperCommandError: If the app fails to start
        """
        self.flipper.run_app(self.APP_NAME)
        time.sleep(self.APP_START_DELAY)  # Wait for app to start
    
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
            self._ensure_ir_app_running()
            
            # Send IR signal
            response = self.flipper.send_command(f"ir_send {signal_name}")
            logger.info(f"Sent IR signal: {signal_name}")
            
            return self._check_success(response, ["sent", "ok"])
        except FlipperCommandError as e:
            logger.error(f"Error sending IR signal: {e}")
            raise
        except Exception as e:
            logger.error(f"Unexpected error sending IR signal: {e}")
            return False
    
    def _check_success(self, response, success_keywords):
        """
        Check if a response indicates success based on keywords
        
        Args:
            response (str): Response string from Flipper Zero
            success_keywords (list): List of keywords indicating success
            
        Returns:
            bool: True if any success keyword is in the response, False otherwise
        """
        response_lower = response.lower()
        for keyword in success_keywords:
            if keyword in response_lower:
                return True
        
        logger.warning(f"Command failed with response: {response}")
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
            self._ensure_ir_app_running()
            
            # Start recording
            logger.info(f"Recording IR signal as: {signal_name}")
            response = self.flipper.send_command(f"ir_record {signal_name}", timeout=timeout)
            
            return self._check_success(response, ["recorded", "saved", "ok"])
        except FlipperTimeoutError:
            self._handle_recording_timeout(signal_name)
            raise
        except FlipperCommandError as e:
            logger.error(f"Error recording IR signal: {e}")
            raise
        except Exception as e:
            logger.error(f"Unexpected error recording IR signal: {e}")
            return False
    
    def _handle_recording_timeout(self, signal_name):
        """
        Handle a timeout during recording by attempting to cancel
        
        Args:
            signal_name (str): Name of the signal being recorded
        """
        logger.error(f"Timeout while recording IR signal: {signal_name}")
        try:
            # Try to cancel recording
            self.flipper.send_command("ir_record_cancel")
        except Exception as e:
            logger.error(f"Error cancelling recording: {e}")
    
    def list_signals(self):
        """
        List available IR signals on Flipper Zero
        
        Returns:
            list: List of available IR signal names
        """
        try:
            self._ensure_ir_app_running()
            
            # List signals
            response = self.flipper.send_command("ir_list")
            
            return self._parse_signal_list(response)
        except Exception as e:
            logger.error(f"Error listing IR signals: {e}")
            return []
    
    def _parse_signal_list(self, response):
        """
        Parse the list of signals from the response
        
        Args:
            response (str): Response string from Flipper Zero
            
        Returns:
            list: List of signal names
        """
        signals = []
        for line in response.split('\n'):
            line = line.strip()
            if line and not line.startswith("ir_list") and not line.lower().startswith("ok"):
                signals.append(line)
        
        return signals
    
    def delete_signal(self, signal_name):
        """
        Delete an IR signal from Flipper Zero
        
        Args:
            signal_name (str): Name of the IR signal to delete
            
        Returns:
            bool: True if signal deleted successfully, False otherwise
        """
        try:
            self._ensure_ir_app_running()
            
            # Delete signal
            response = self.flipper.send_command(f"ir_delete {signal_name}")
            
            success = self._check_success(response, ["deleted", "ok"])
            if success:
                logger.info(f"Deleted IR signal: {signal_name}")
            
            return success
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
            self._ensure_ir_app_running()
            
            # Rename signal
            response = self.flipper.send_command(f"ir_rename {old_name} {new_name}")
            
            success = self._check_success(response, ["renamed", "ok"])
            if success:
                logger.info(f"Renamed IR signal from {old_name} to {new_name}")
            
            return success
        except Exception as e:
            logger.error(f"Error renaming IR signal: {e}")
            return False 