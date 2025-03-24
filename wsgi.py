#!/usr/bin/env python3
"""
HakPak - WSGI Entry Point
"""

import os
import sys
from app import create_app, socketio

# Add application directory to Python path
sys.path.insert(0, os.path.abspath(os.path.dirname(__file__)))

# Create Flask application instance
app = create_app()

if __name__ == '__main__':
    # Run the application with Socket.IO support
    socketio.run(app, host='0.0.0.0', port=5000, debug=False) 