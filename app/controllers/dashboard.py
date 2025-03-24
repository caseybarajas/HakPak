from flask import Blueprint, render_template, jsonify
import psutil
import os
from app import socketio

bp = Blueprint('dashboard', __name__, url_prefix='/')

@bp.route('/')
def index():
    """Main dashboard page"""
    return render_template('dashboard/index.html')

@bp.route('/system-status')
def system_status():
    """Get system status information in JSON format"""
    status = {
        'cpu_usage': psutil.cpu_percent(),
        'memory_usage': psutil.virtual_memory().percent,
        'disk_usage': psutil.disk_usage('/').percent,
        'temperature': get_cpu_temperature(),
        'uptime': get_uptime(),
        'battery': get_battery_status()
    }
    return jsonify(status)

@socketio.on('connect')
def handle_connect():
    """Handle client connection to WebSocket"""
    print('Client connected')

@socketio.on('disconnect')
def handle_disconnect():
    """Handle client disconnection from WebSocket"""
    print('Client disconnected')

# Utility functions
def get_cpu_temperature():
    """Get CPU temperature for Raspberry Pi"""
    try:
        with open('/sys/class/thermal/thermal_zone0/temp', 'r') as f:
            temp = float(f.read()) / 1000.0
        return round(temp, 1)
    except:
        return 0  # Return 0 if unable to read temperature

def get_uptime():
    """Get system uptime"""
    try:
        with open('/proc/uptime', 'r') as f:
            uptime_seconds = float(f.readline().split()[0])
        return uptime_seconds
    except:
        return 0

def get_battery_status():
    """Get battery status from power bank (placeholder)"""
    # This would be replaced with actual code to query battery status
    return {
        'percentage': 80,
        'charging': True,
        'time_remaining': '3h 45m'
    } 