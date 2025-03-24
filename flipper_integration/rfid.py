"""
RFID Controller for Flipper Zero integration

This module provides RFID functionality for the Flipper Zero integration,
allowing the reading, emulating, and managing of RFID cards.
"""

import time
import json
from .flipper import FlipperZero, FlipperCommandError

class RFIDController:
    """Controller for RFID operations with Flipper Zero"""
    
    def __init__(self, flipper_zero, rfid_dir="/ext/lfrfid"):
        """
        Initialize the RFID controller
        
        Args:
            flipper_zero (FlipperZero): An initialized and connected FlipperZero instance
            rfid_dir (str): Directory on the Flipper Zero where RFID data is stored
        """
        self.flipper = flipper_zero
        self.rfid_dir = rfid_dir
        
    def list_keys(self):
        """
        List available RFID keys/cards
        
        Returns:
            list: List of RFID keys available on the Flipper Zero
        """
        try:
            # Start RFID app
            self.flipper.run_app("lfrfid")
            time.sleep(1)  # Wait for app to start
            
            # Send command to list keys
            response = self.flipper.send_command("storage list {}".format(self.rfid_dir))
            
            # Parse response to extract key names
            keys = []
            if isinstance(response, str):
                lines = response.strip().split('\n')
                for line in lines:
                    # Extract key name (typically has .rfid extension)
                    if '.rfid' in line:
                        key_name = line.strip()
                        if key_name.endswith('.rfid'):
                            keys.append(key_name)
            
            return keys
            
        except FlipperCommandError as e:
            print(f"Error listing RFID keys: {e}")
            return []
            
    def read_card(self, timeout=30):
        """
        Read an RFID card
        
        Args:
            timeout (int): Maximum time to wait for a card in seconds
            
        Returns:
            dict: Card data including type, ID, and frequency, or None if failed
        """
        try:
            # Start RFID app
            self.flipper.run_app("lfrfid")
            time.sleep(1)  # Wait for app to start
            
            # Send command to read card
            response = self.flipper.send_command("rfid_read", timeout=timeout)
            
            # Parse response
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
                
        except FlipperCommandError as e:
            return {
                "success": False,
                "error": f"Error reading RFID card: {str(e)}"
            }
        finally:
            # Exit RFID app
            self.flipper.exit_app()
    
    def emulate_card(self, key_name):
        """
        Emulate an RFID card/key
        
        Args:
            key_name (str): Name of the key to emulate (can include path or just filename)
            
        Returns:
            bool: True if emulation started successfully, False otherwise
        """
        try:
            # Ensure key_name has .rfid extension
            if not key_name.endswith('.rfid'):
                key_name += '.rfid'
                
            # If no path provided, prepend RFID directory
            if '/' not in key_name:
                key_name = f"{self.rfid_dir}/{key_name}"
                
            # Start RFID app
            self.flipper.run_app("lfrfid")
            time.sleep(1)  # Wait for app to start
            
            # Send command to emulate the key
            response = self.flipper.send_command(f"rfid_emulate {key_name}")
            
            # Check for success message
            if "starting emulation" in response.lower() or "emulating" in response.lower():
                return True
            else:
                print(f"Failed to start emulation: {response}")
                return False
                
        except FlipperCommandError as e:
            print(f"Error emulating RFID card: {e}")
            return False
    
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
            # Ensure key_name has .rfid extension
            if not key_name.endswith('.rfid'):
                key_name += '.rfid'
                
            # If no path provided, prepend RFID directory
            if '/' not in key_name:
                key_name = f"{self.rfid_dir}/{key_name}"
                
            # Format card data for saving
            card_type = card_data.get("card_type", "EM4100")
            card_id = card_data.get("card_id", "")
            
            # Send command to save the card
            response = self.flipper.send_command(f"rfid_save {key_name} {card_type} {card_id}")
            
            # Check for success message
            if "saved successfully" in response.lower():
                return True
            else:
                print(f"Failed to save card: {response}")
                return False
                
        except FlipperCommandError as e:
            print(f"Error saving RFID card: {e}")
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
            # Ensure key_name has .rfid extension
            if not key_name.endswith('.rfid'):
                key_name += '.rfid'
                
            # If no path provided, prepend RFID directory
            if '/' not in key_name:
                key_name = f"{self.rfid_dir}/{key_name}"
                
            # Send command to delete the key
            response = self.flipper.send_command(f"storage remove {key_name}")
            
            # Check for success message
            if "removed" in response.lower() or "deleted" in response.lower():
                return True
            else:
                print(f"Failed to delete key: {response}")
                return False
                
        except FlipperCommandError as e:
            print(f"Error deleting RFID key: {e}")
            return False 