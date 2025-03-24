"""
SubGHz Controller for Flipper Zero integration

This module provides SubGHz functionality for the Flipper Zero integration,
allowing transmission and reception of SubGHz signals.
"""

import time
import json
from .flipper import FlipperZero, FlipperCommandError

class SubGHzController:
    """Controller for SubGHz operations with Flipper Zero"""
    
    def __init__(self, flipper_zero, subghz_dir="/ext/subghz"):
        """
        Initialize the SubGHz controller
        
        Args:
            flipper_zero (FlipperZero): An initialized and connected FlipperZero instance
            subghz_dir (str): Directory on the Flipper Zero where SubGHz data is stored
        """
        self.flipper = flipper_zero
        self.subghz_dir = subghz_dir
        
    def list_files(self):
        """
        List available SubGHz signal files
        
        Returns:
            list: List of SubGHz signal files available on the Flipper Zero
        """
        try:
            # Send command to list files
            response = self.flipper.send_command("storage list {}".format(self.subghz_dir))
            
            # Parse response to extract file names
            files = []
            if isinstance(response, str):
                lines = response.strip().split('\n')
                for line in lines:
                    # Extract file name (typically has .sub extension)
                    if '.sub' in line:
                        file_name = line.strip()
                        if file_name.endswith('.sub'):
                            files.append(file_name)
            
            return files
            
        except FlipperCommandError as e:
            print(f"Error listing SubGHz files: {e}")
            return []
    
    def transmit(self, file_name):
        """
        Transmit a SubGHz signal
        
        Args:
            file_name (str): Name of the signal file to transmit (can include path or just filename)
            
        Returns:
            bool: True if transmission started successfully, False otherwise
        """
        try:
            # Ensure file_name has .sub extension
            if not file_name.endswith('.sub'):
                file_name += '.sub'
                
            # If no path provided, prepend SubGHz directory
            if '/' not in file_name:
                file_name = f"{self.subghz_dir}/{file_name}"
                
            # Start SubGHz app
            self.flipper.run_app("subghz")
            time.sleep(1)  # Wait for app to start
            
            # Send command to transmit the signal
            response = self.flipper.send_command(f"subghz_tx {file_name}")
            
            # Check for success message
            if "transmission started" in response.lower() or "transmitting" in response.lower():
                return True
            else:
                print(f"Failed to start transmission: {response}")
                return False
                
        except FlipperCommandError as e:
            print(f"Error transmitting SubGHz signal: {e}")
            return False
        finally:
            # Exit SubGHz app
            self.flipper.exit_app()
    
    def receive(self, frequency, timeout=30, file_name=None):
        """
        Receive SubGHz signals
        
        Args:
            frequency (str): Frequency to listen on (e.g., "433.92")
            timeout (int): Maximum time to listen in seconds
            file_name (str, optional): Name to save the captured signal, if any
            
        Returns:
            dict: Status and captured signals data
        """
        try:
            # Start SubGHz app
            self.flipper.run_app("subghz")
            time.sleep(1)  # Wait for app to start
            
            # Generate file name if not provided
            if file_name is None:
                timestamp = int(time.time())
                file_name = f"captured_{timestamp}.sub"
                
            # Ensure file_name has .sub extension
            if not file_name.endswith('.sub'):
                file_name += '.sub'
                
            # If no path provided, prepend SubGHz directory
            if '/' not in file_name:
                file_name = f"{self.subghz_dir}/{file_name}"
            
            # Send command to start receiving
            response = self.flipper.send_command(f"subghz_rx {frequency} {file_name}", timeout=timeout)
            
            # Check for capture success
            if "captured" in response.lower() or "received" in response.lower():
                return {
                    "success": True,
                    "frequency": frequency,
                    "file": file_name,
                    "raw_data": response
                }
            else:
                return {
                    "success": False,
                    "error": "No signal captured",
                    "raw_data": response
                }
                
        except FlipperCommandError as e:
            return {
                "success": False,
                "error": f"Error receiving SubGHz signal: {str(e)}"
            }
        finally:
            # Exit SubGHz app
            self.flipper.exit_app()
    
    def delete_file(self, file_name):
        """
        Delete a SubGHz signal file
        
        Args:
            file_name (str): Name of the file to delete
            
        Returns:
            bool: True if file was deleted successfully, False otherwise
        """
        try:
            # Ensure file_name has .sub extension
            if not file_name.endswith('.sub'):
                file_name += '.sub'
                
            # If no path provided, prepend SubGHz directory
            if '/' not in file_name:
                file_name = f"{self.subghz_dir}/{file_name}"
                
            # Send command to delete the file
            response = self.flipper.send_command(f"storage remove {file_name}")
            
            # Check for success message
            if "removed" in response.lower() or "deleted" in response.lower():
                return True
            else:
                print(f"Failed to delete file: {response}")
                return False
                
        except FlipperCommandError as e:
            print(f"Error deleting SubGHz file: {e}")
            return False
    
    def get_common_frequencies(self):
        """
        Get list of common SubGHz frequencies
        
        Returns:
            list: List of common frequencies
        """
        # Common frequencies for various applications and regions
        return [
            {"value": "300.00", "label": "300.00 MHz - Garage doors (US)"},
            {"value": "315.00", "label": "315.00 MHz - Automotive (US)"},
            {"value": "390.00", "label": "390.00 MHz - Automotive (US)"},
            {"value": "433.92", "label": "433.92 MHz - Common (EU/Asia/Australia)"},
            {"value": "434.42", "label": "434.42 MHz - Automotive (EU)"},
            {"value": "434.77", "label": "434.77 MHz - Automotive (EU)"},
            {"value": "868.35", "label": "868.35 MHz - Common (EU)"},
            {"value": "915.00", "label": "915.00 MHz - ISM band (US)"},
            {"value": "925.00", "label": "925.00 MHz - Doorbells (US)"}
        ] 