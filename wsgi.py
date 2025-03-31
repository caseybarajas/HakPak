#!/usr/bin/env python3
"""
HakPak - WSGI Entry Point
"""

import os
import sys
import logging
from app import create_app, socketio

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(),
        logging.FileHandler(os.path.join(os.path.dirname(__file__), 'hakpak.log'))
    ]
)
logger = logging.getLogger("hakpak")

# Add application directory to Python path
sys.path.insert(0, os.path.abspath(os.path.dirname(__file__)))

def get_config_from_env():
    """
    Get configuration from environment variables with defaults
    
    Returns:
        dict: Configuration dictionary
    """
    return {
        "host": os.environ.get("HAKPAK_HOST", "0.0.0.0"),
        "port": int(os.environ.get("HAKPAK_PORT", "5000")),
        "debug": os.environ.get("HAKPAK_DEBUG", "false").lower() == "true",
        "ssl_context": None  # Set to 'adhoc' or (cert_path, key_path) tuple for HTTPS
    }

def create_wsgi_app():
    """
    Create the WSGI application with proper error handling
    
    Returns:
        Flask app: Configured Flask application
    """
    try:
        # Create Flask application instance
        app = create_app()
        logger.info("HakPak application initialized successfully")
        return app
    except Exception as e:
        logger.error(f"Failed to initialize application: {e}")
        # Re-raise the exception for the WSGI server to handle
        raise

# Create application for WSGI servers (gunicorn, uwsgi, etc.)
application = create_wsgi_app()

if __name__ == '__main__':
    try:
        # Get configuration
        config = get_config_from_env()
        
        # Log startup information
        logger.info(f"Starting HakPak on {config['host']}:{config['port']} (debug={config['debug']})")
        
        # Run the application with Socket.IO support
        socketio.run(
            application, 
            host=config["host"], 
            port=config["port"], 
            debug=config["debug"],
            ssl_context=config["ssl_context"]
        )
    except Exception as e:
        logger.error(f"Failed to start HakPak: {e}")
        sys.exit(1) 