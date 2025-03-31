"""
SubGHz Controller for Flipper Zero integration

This module provides SubGHz functionality for the Flipper Zero integration,
allowing transmission and reception of SubGHz signals.
"""

import time
import logging
from .flipper import FlipperZero, FlipperCommandError

# Setup logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("flipper_subghz")

class SubGHzController:
    """Controller for SubGHz operations with Flipper Zero"""
    
    # Constants
    APP_NAME = "subghz"
    APP_START_DELAY = 1.0  # seconds
    DEFAULT_SUBGHZ_DIR = "/ext/subghz"
    SUBGHZ_EXTENSION = ".sub"
    
    def __init__(self, flipper_zero, subghz_dir=None):
        """
        Initialize the SubGHz controller
        
        Args:
            flipper_zero (FlipperZero): An initialized and connected FlipperZero instance
            subghz_dir (str): Directory on the Flipper Zero where SubGHz data is stored
        """
        self.flipper = flipper_zero
        self.subghz_dir = subghz_dir or self.DEFAULT_SUBGHZ_DIR
    
    def _ensure_app_running(self):
        """
        Ensure the SubGHz app is running on the Flipper Zero
        
        Raises:
            FlipperCommandError: If the app fails to start
        """
        self.flipper.run_app(self.APP_NAME)
        time.sleep(self.APP_START_DELAY)  # Wait for app to start
    
    def _format_file_path(self, file_name):
        """
        Format file name with proper extension and path
        
        Args:
            file_name (str): Name of the signal file
            
        Returns:
            str: Formatted file path
        """
        # Ensure file_name has .sub extension
        if not file_name.endswith(self.SUBGHZ_EXTENSION):
            file_name += self.SUBGHZ_EXTENSION
            
        # If no path provided, prepend SubGHz directory
        if '/' not in file_name:
            file_name = f"{self.subghz_dir}/{file_name}"
            
        return file_name
    
    def _exit_app_safely(self):
        """Safely exit the current app on the Flipper Zero"""
        try:
            self.flipper.exit_app()
        except Exception as e:
            logger.warning(f"Error exiting app: {e}")
        
    def list_files(self):
        """
        List available SubGHz signal files
        
        Returns:
            list: List of SubGHz signal files available on the Flipper Zero
        """
        try:
            # Send command to list files
            response = self.flipper.send_command(f"storage list {self.subghz_dir}")
            
            return self._parse_file_list(response)
            
        except FlipperCommandError as e:
            logger.error(f"Error listing SubGHz files: {e}")
            return []
    
    def _parse_file_list(self, response):
        """
        Parse the list of files from the storage list response
        
        Args:
            response (str): Response from the Flipper Zero
            
        Returns:
            list: List of SubGHz file names
        """
        files = []
        if isinstance(response, str):
            lines = response.strip().split('\n')
            for line in lines:
                # Extract file name (typically has .sub extension)
                if self.SUBGHZ_EXTENSION in line:
                    file_name = line.strip()
                    if file_name.endswith(self.SUBGHZ_EXTENSION):
                        files.append(file_name)
        
        return files
    
    def transmit(self, file_name):
        """
        Transmit a SubGHz signal
        
        Args:
            file_name (str): Name of the signal file to transmit (can include path or just filename)
            
        Returns:
            bool: True if transmission started successfully, False otherwise
        """
        try:
            formatted_file = self._format_file_path(file_name)
            self._ensure_app_running()
            
            # Send command to transmit the signal
            response = self.flipper.send_command(f"subghz_tx {formatted_file}")
            
            success = self._check_transmission_success(response)
            if not success:
                logger.warning(f"Failed to start transmission: {response}")
            
            return success
                
        except FlipperCommandError as e:
            logger.error(f"Error transmitting SubGHz signal: {e}")
            return False
        finally:
            self._exit_app_safely()
    
    def _check_transmission_success(self, response):
        """
        Check if transmission started successfully
        
        Args:
            response (str): Response from the Flipper Zero
            
        Returns:
            bool: True if transmission started successfully
        """
        return any(keyword in response.lower() for keyword in ["transmission started", "transmitting"])
    
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
            self._ensure_app_running()
            
            # Generate file name if not provided
            if file_name is None:
                file_name = self._generate_capture_filename()
            
            formatted_file = self._format_file_path(file_name)
            
            # Send command to start receiving
            response = self.flipper.send_command(f"subghz_rx {frequency} {formatted_file}", timeout=timeout)
            
            return self._parse_receive_response(response, frequency, formatted_file)
                
        except FlipperCommandError as e:
            logger.error(f"Error receiving SubGHz signal: {e}")
            return {
                "success": False,
                "error": f"Error receiving SubGHz signal: {str(e)}"
            }
        finally:
            self._exit_app_safely()
    
    def _generate_capture_filename(self):
        """
        Generate a filename for a captured signal based on timestamp
        
        Returns:
            str: Generated filename
        """
        timestamp = int(time.time())
        return f"captured_{timestamp}"
    
    def _parse_receive_response(self, response, frequency, file_name):
        """
        Parse the response from a receive operation
        
        Args:
            response (str): Response from the Flipper Zero
            frequency (str): Frequency that was used
            file_name (str): File name that was used
            
        Returns:
            dict: Parsed response data
        """
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
    
    def delete_file(self, file_name):
        """
        Delete a SubGHz signal file
        
        Args:
            file_name (str): Name of the file to delete
            
        Returns:
            bool: True if file was deleted successfully, False otherwise
        """
        try:
            formatted_file = self._format_file_path(file_name)
            
            # Send command to delete the file
            response = self.flipper.send_command(f"storage remove {formatted_file}")
            
            success = self._check_deletion_success(response)
            if success:
                logger.info(f"Deleted SubGHz file: {file_name}")
            else:
                logger.warning(f"Failed to delete file: {response}")
            
            return success
                
        except FlipperCommandError as e:
            logger.error(f"Error deleting SubGHz file: {e}")
            return False
    
    def _check_deletion_success(self, response):
        """
        Check if deletion was successful
        
        Args:
            response (str): Response from the Flipper Zero
            
        Returns:
            bool: True if deletion was successful
        """
        return any(keyword in response.lower() for keyword in ["removed", "deleted"])
    
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
        ] 