"""
RFID Controller for Flipper Zero integration

This module provides RFID functionality for the Flipper Zero integration,
allowing the reading, emulating, and managing of RFID cards.
"""

import time
import logging
from .flipper import FlipperZero, FlipperCommandError

# Setup logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("flipper_rfid")

class RFIDController:
    """Controller for RFID operations with Flipper Zero"""
    
    # Constants
    APP_NAME = "lfrfid"
    APP_START_DELAY = 1.0  # seconds
    DEFAULT_RFID_DIR = "/ext/lfrfid"
    DEFAULT_CARD_TYPE = "EM4100"
    RFID_EXTENSION = ".rfid"
    
    def __init__(self, flipper_zero, rfid_dir=None):
        """
        Initialize the RFID controller
        
        Args:
            flipper_zero (FlipperZero): An initialized and connected FlipperZero instance
            rfid_dir (str): Directory on the Flipper Zero where RFID data is stored
        """
        self.flipper = flipper_zero
        self.rfid_dir = rfid_dir or self.DEFAULT_RFID_DIR
        
    def _ensure_app_running(self):
        """
        Ensure the RFID app is running on the Flipper Zero
        
        Raises:
            FlipperCommandError: If the app fails to start
        """
        self.flipper.run_app(self.APP_NAME)
        time.sleep(self.APP_START_DELAY)  # Wait for app to start
    
    def _format_key_path(self, key_name):
        """
        Format key name with proper extension and path
        
        Args:
            key_name (str): Name of the key file
            
        Returns:
            str: Formatted key path
        """
        # Ensure key_name has .rfid extension
        if not key_name.endswith(self.RFID_EXTENSION):
            key_name += self.RFID_EXTENSION
            
        # If no path provided, prepend RFID directory
        if '/' not in key_name:
            key_name = f"{self.rfid_dir}/{key_name}"
            
        return key_name
    
    def list_keys(self):
        """
        List available RFID keys/cards
        
        Returns:
            list: List of RFID keys available on the Flipper Zero
        """
        try:
            self._ensure_app_running()
            
            # Send command to list keys
            response = self.flipper.send_command(f"storage list {self.rfid_dir}")
            
            return self._parse_key_list(response)
            
        except FlipperCommandError as e:
            logger.error(f"Error listing RFID keys: {e}")
            return []
    
    def _parse_key_list(self, response):
        """
        Parse the list of keys from the storage list response
        
        Args:
            response (str): Response from the Flipper Zero
            
        Returns:
            list: List of RFID key names
        """
        keys = []
        if isinstance(response, str):
            lines = response.strip().split('\n')
            for line in lines:
                # Extract key name (typically has .rfid extension)
                if self.RFID_EXTENSION in line:
                    key_name = line.strip()
                    if key_name.endswith(self.RFID_EXTENSION):
                        keys.append(key_name)
        
        return keys
            
    def read_card(self, timeout=30):
        """
        Read an RFID card
        
        Args:
            timeout (int): Maximum time to wait for a card in seconds
            
        Returns:
            dict: Card data including type, ID, and frequency, or None if failed
        """
        try:
            self._ensure_app_running()
            
            # Send command to read card
            response = self.flipper.send_command("rfid_read", timeout=timeout)
            
            return self._parse_read_card_response(response)
                
        except FlipperCommandError as e:
            logger.error(f"Error reading RFID card: {e}")
            return {
                "success": False,
                "error": f"Error reading RFID card: {str(e)}"
            }
        finally:
            # Exit RFID app
            self._exit_app_safely()
    
    def _parse_read_card_response(self, response):
        """
        Parse the response from a card read operation
        
        Args:
            response (str): Response from the Flipper Zero
            
        Returns:
            dict: Card data dictionary
        """
        if "captured successfully" in response:
            # Extract card data
            data = {}
            lines = response.strip().split('\n')
            for line in lines:
                if ":" in line:
                    key, value = line.split(":", 1)
                    data[key.strip()] = value.strip()
            
            return {
                "success": True,
                "card_type": data.get("Type", "Unknown"),
                "card_id": data.get("ID", "Unknown"),
                "frequency": data.get("Frequency", "Unknown"),
                "raw_data": response
            }
        else:
            return {
                "success": False,
                "error": "Failed to read card",
                "raw_data": response
            }
    
    def _exit_app_safely(self):
        """Safely exit the current app on the Flipper Zero"""
        try:
            self.flipper.exit_app()
        except Exception as e:
            logger.warning(f"Error exiting app: {e}")
    
    def emulate_card(self, key_name):
        """
        Emulate an RFID card/key
        
        Args:
            key_name (str): Name of the key to emulate (can include path or just filename)
            
        Returns:
            bool: True if emulation started successfully, False otherwise
        """
        try:
            formatted_key = self._format_key_path(key_name)
            self._ensure_app_running()
            
            # Send command to emulate the key
            response = self.flipper.send_command(f"rfid_emulate {formatted_key}")
            
            success = self._check_emulation_success(response)
            if not success:
                logger.warning(f"Failed to start emulation: {response}")
            
            return success
                
        except FlipperCommandError as e:
            logger.error(f"Error emulating RFID card: {e}")
            return False
    
    def _check_emulation_success(self, response):
        """
        Check if emulation started successfully
        
        Args:
            response (str): Response from the Flipper Zero
            
        Returns:
            bool: True if emulation started successfully
        """
        return any(keyword in response.lower() for keyword in ["starting emulation", "emulating"])
    
    def save_card(self, card_data, key_name):
        """
        Save RFID card data
        
        Args:
            card_data (dict): Card data to save
            key_name (str): Name to save the key as
            
        Returns:
            bool: True if card was saved successfully, False otherwise
        """
        try:
            formatted_key = self._format_key_path(key_name)
            self._ensure_app_running()
            
            # Format card data for saving
            card_type = card_data.get("card_type", self.DEFAULT_CARD_TYPE)
            card_id = card_data.get("card_id", "")
            
            if not card_id:
                logger.error("Cannot save card without ID")
                return False
            
            # Send command to save the card
            response = self.flipper.send_command(f"rfid_save {formatted_key} {card_type} {card_id}")
            
            success = "saved successfully" in response.lower()
            if not success:
                logger.warning(f"Failed to save card: {response}")
            
            return success
                
        except FlipperCommandError as e:
            logger.error(f"Error saving RFID card: {e}")
            return False
    
    def delete_key(self, key_name):
        """
        Delete an RFID key
        
        Args:
            key_name (str): Name of the key to delete
            
        Returns:
            bool: True if key was deleted successfully, False otherwise
        """
        try:
            formatted_key = self._format_key_path(key_name)
            self._ensure_app_running()
            
            # Send command to delete the key
            response = self.flipper.send_command(f"storage remove {formatted_key}")
            
            success = "removed" in response.lower() or "deleted" in response.lower()
            if success:
                logger.info(f"Deleted RFID key: {key_name}")
            else:
                logger.warning(f"Failed to delete RFID key: {response}")
            
            return success
                
        except FlipperCommandError as e:
            logger.error(f"Error deleting RFID key: {e}")
            return False 