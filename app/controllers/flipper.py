from flask import Blueprint, render_template, request, jsonify
import subprocess
import serial
import json
import os
from app import socketio
from flipper_integration import FlipperZero, IRController, RFIDController, SubGHzController, FlipperConnectionError

bp = Blueprint('flipper', __name__, url_prefix='/flipper')

# Flipper Zero instance (will be initialized on first access)
_flipper_instance = None
MAX_RETRY_ATTEMPTS = 3

def get_flipper_instance():
    """
    Get or create Flipper Zero instance
    
    Returns:
        FlipperZero: Instance of FlipperZero class
    """
    global _flipper_instance
    
    if _flipper_instance is None:
        try:
            port = _get_flipper_port()
            _flipper_instance = FlipperZero(port=port)
            _try_connect_flipper()
        except Exception as e:
            print(f"Error initializing Flipper Zero: {e}")
    
    return _flipper_instance

def _get_flipper_port():
    """
    Get Flipper Zero port from config or use default
    
    Returns:
        str: Serial port path
    """
    config_file = '/etc/hakpak/flipper.conf'
    if os.path.exists(config_file):
        with open(config_file, 'r') as f:
            for line in f:
                if line.startswith('FLIPPER_PORT='):
                    return line.strip().split('=')[1].strip('"\'')
    
    # Default port
    return '/dev/ttyACM0'

def _try_connect_flipper():
    """Try to connect to Flipper Zero with error handling"""
    global _flipper_instance
    
    if _flipper_instance is not None:
        try:
            _flipper_instance.connect()
        except:
            # Connection might fail, we'll retry later
            pass

@bp.route('/')
def index():
    """Flipper Zero control panel"""
    return render_template('flipper/index.html')

@bp.route('/status')
def status():
    """Get Flipper Zero connection status"""
    flipper = get_flipper_instance()
    connected = flipper is not None and flipper.is_connected()
    
    response = {
        'connected': connected,
        'port': flipper.port if connected else None,
    }
    
    if connected:
        try:
            _populate_device_info(flipper, response)
        except Exception as e:
            response['error'] = str(e)
    
    return jsonify(response)

def _populate_device_info(flipper, response_dict):
    """
    Populate response dictionary with device information
    
    Args:
        flipper (FlipperZero): Flipper Zero instance
        response_dict (dict): Dictionary to populate with device info
    """
    response_dict['firmware'] = flipper.get_firmware_version()
    response_dict['battery'] = flipper.get_battery_level()
    
    # Get other device info
    device_info = flipper.get_device_info()
    for key, value in device_info.items():
        if key not in response_dict:
            response_dict[key] = value

@bp.route('/connect', methods=['POST'])
def connect():
    """Connect to Flipper Zero"""
    data = request.json or {}
    port = data.get('port', '/dev/ttyACM0')
    
    try:
        flipper = get_flipper_instance()
        _update_flipper_port_if_needed(flipper, port)
        _ensure_flipper_connected(flipper)
        
        return jsonify({
            'success': True,
            'message': f'Connected to Flipper Zero on {port}',
            'firmware': flipper.get_firmware_version()
        })
    except Exception as e:
        return jsonify({
            'success': False,
            'message': f'Failed to connect to Flipper Zero: {str(e)}'
        })

def _update_flipper_port_if_needed(flipper, port):
    """
    Update Flipper Zero port if different from current port
    
    Args:
        flipper (FlipperZero): Flipper Zero instance
        port (str): New port to use
    """
    if flipper.port != port:
        flipper.port = port

def _ensure_flipper_connected(flipper):
    """
    Ensure Flipper Zero is connected, connect if not
    
    Args:
        flipper (FlipperZero): Flipper Zero instance
    
    Raises:
        FlipperConnectionError: If connection fails
    """
    if not flipper.is_connected():
        flipper.connect()

@bp.route('/detach', methods=['POST'])
def prepare_for_detachment():
    """Prepare Flipper Zero for safe detachment"""
    flipper = get_flipper_instance()
    
    if not flipper or not flipper.is_connected():
        return jsonify({
            'success': False,
            'message': 'Flipper Zero is not connected'
        })
    
    try:
        # Notify clients that detachment is in progress
        socketio.emit('flipper_status', {'status': 'detaching'})
        
        # Disconnect from Flipper
        flipper.disconnect()
        
        # Notify clients that detachment is complete
        socketio.emit('flipper_status', {'status': 'detached'})
        
        return jsonify({
            'success': True,
            'message': 'Flipper Zero can now be safely detached'
        })
    except Exception as e:
        error_message = f'Failed to prepare for detachment: {str(e)}'
        _emit_error_status(error_message)
        
        return jsonify({
            'success': False,
            'message': error_message
        })

def _emit_error_status(error_message):
    """
    Emit error status to clients
    
    Args:
        error_message (str): Error message to emit
    """
    socketio.emit('flipper_status', {
        'status': 'error',
        'message': error_message
    })

@bp.route('/execute', methods=['POST'])
def execute_command():
    """Execute a command on Flipper Zero"""
    data = request.json
    if not data or 'command' not in data:
        return jsonify({'success': False, 'message': 'No command provided'})
    
    command = data['command']
    
    flipper = get_flipper_instance()
    if not flipper or not flipper.is_connected():
        return jsonify({'success': False, 'message': 'Flipper Zero is not connected'})
    
    try:
        # Send command to Flipper
        response = flipper.send_command(command)
        
        return jsonify({
            'success': True,
            'result': {
                'executed': command,
                'response': response
            }
        })
    except Exception as e:
        return jsonify({
            'success': False,
            'message': f'Error executing command: {str(e)}'
        })

@bp.route('/ir/list', methods=['GET'])
def list_ir_signals():
    """List available IR signals"""
    flipper = get_flipper_instance()
    if not flipper or not flipper.is_connected():
        return jsonify({'success': False, 'message': 'Flipper Zero is not connected'})
    
    try:
        ir = IRController(flipper)
        signals = ir.list_signals()
        
        return jsonify({
            'success': True,
            'signals': signals
        })
    except Exception as e:
        return jsonify({
            'success': False,
            'message': f'Error listing IR signals: {str(e)}'
        })

@bp.route('/ir/send', methods=['POST'])
def send_ir_signal():
    """Send IR signal"""
    data = request.json
    if not data or 'signal' not in data:
        return jsonify({'success': False, 'message': 'No signal name provided'})
    
    signal = data['signal']
    
    flipper = get_flipper_instance()
    if not flipper or not flipper.is_connected():
        return jsonify({'success': False, 'message': 'Flipper Zero is not connected'})
    
    try:
        ir = IRController(flipper)
        result = ir.send_signal(signal)
        
        return jsonify({
            'success': result,
            'message': f'IR signal {signal} sent successfully' if result else f'Failed to send IR signal {signal}'
        })
    except Exception as e:
        return jsonify({
            'success': False,
            'message': f'Error sending IR signal: {str(e)}'
        })

@bp.route('/ir/record', methods=['POST'])
def record_ir_signal():
    """Record IR signal"""
    data = request.json
    if not data or 'name' not in data:
        return jsonify({'success': False, 'message': 'No signal name provided'})
    
    name = data['name']
    timeout = data.get('timeout', 20)  # Default 20 seconds timeout
    
    flipper = get_flipper_instance()
    if not flipper or not flipper.is_connected():
        return jsonify({'success': False, 'message': 'Flipper Zero is not connected'})
    
    try:
        # Notify clients that recording is starting
        socketio.emit('ir_recording', {'status': 'started', 'name': name})
        
        ir = IRController(flipper)
        result = ir.record_signal(name, timeout=timeout)
        
        # Notify clients of recording result
        if result:
            socketio.emit('ir_recording', {'status': 'completed', 'name': name})
        else:
            socketio.emit('ir_recording', {'status': 'failed', 'name': name})
        
        return jsonify({
            'success': result,
            'message': f'IR signal {name} recorded successfully' if result else f'Failed to record IR signal {name}'
        })
    except Exception as e:
        socketio.emit('ir_recording', {'status': 'error', 'name': name, 'message': str(e)})
        
        return jsonify({
            'success': False,
            'message': f'Error recording IR signal: {str(e)}'
        })

@bp.route('/rfid/list', methods=['GET'])
def list_rfid_keys():
    """List available RFID keys"""
    flipper = get_flipper_instance()
    if not flipper or not flipper.is_connected():
        return jsonify({'success': False, 'message': 'Flipper Zero is not connected'})
    
    try:
        rfid = RFIDController(flipper)
        keys = rfid.list_keys()
        
        return jsonify({
            'success': True,
            'keys': keys
        })
    except Exception as e:
        return jsonify({
            'success': False,
            'message': f'Error listing RFID keys: {str(e)}'
        })

@bp.route('/rfid/read', methods=['POST'])
def read_rfid_card():
    """Read RFID card"""
    data = request.json or {}
    timeout = data.get('timeout', 30)  # Default 30 seconds timeout
    
    flipper = get_flipper_instance()
    if not flipper or not flipper.is_connected():
        return jsonify({'success': False, 'message': 'Flipper Zero is not connected'})
    
    try:
        # Notify clients that reading is starting
        socketio.emit('rfid_reading', {'status': 'started'})
        
        rfid = RFIDController(flipper)
        result = rfid.read_card(timeout=timeout)
        
        # Notify clients of reading result
        if result.get('success', False):
            socketio.emit('rfid_reading', {
                'status': 'completed',
                'card_type': result.get('card_type', 'Unknown'),
                'card_id': result.get('card_id', 'Unknown')
            })
            
            return jsonify({
                'success': True,
                'card': result
            })
        else:
            socketio.emit('rfid_reading', {
                'status': 'failed',
                'error': result.get('error', 'Failed to read card')
            })
            
            return jsonify({
                'success': False,
                'message': result.get('error', 'Failed to read card')
            })
    except Exception as e:
        socketio.emit('rfid_reading', {'status': 'error', 'message': str(e)})
        
        return jsonify({
            'success': False,
            'message': f'Error reading RFID card: {str(e)}'
        })

@bp.route('/rfid/emulate', methods=['POST'])
def emulate_rfid_card():
    """Emulate RFID card"""
    data = request.json
    if not data or 'key' not in data:
        return jsonify({'success': False, 'message': 'No key name provided'})
    
    key_name = data['key']
    
    flipper = get_flipper_instance()
    if not flipper or not flipper.is_connected():
        return jsonify({'success': False, 'message': 'Flipper Zero is not connected'})
    
    try:
        # Notify clients that emulation is starting
        socketio.emit('rfid_emulation', {'status': 'started', 'key': key_name})
        
        rfid = RFIDController(flipper)
        result = rfid.emulate_card(key_name)
        
        if result:
            # Don't immediately notify of completion as emulation is ongoing
            # The user will need to manually stop emulation
            return jsonify({
                'success': True,
                'message': f'RFID key {key_name} emulation started'
            })
        else:
            socketio.emit('rfid_emulation', {'status': 'failed', 'key': key_name})
            
            return jsonify({
                'success': False,
                'message': f'Failed to start RFID key {key_name} emulation'
            })
    except Exception as e:
        socketio.emit('rfid_emulation', {'status': 'error', 'key': key_name, 'message': str(e)})
        
        return jsonify({
            'success': False,
            'message': f'Error emulating RFID key: {str(e)}'
        })

@bp.route('/rfid/save', methods=['POST'])
def save_rfid_card():
    """Save RFID card data"""
    data = request.json
    if not data or 'name' not in data or 'card' not in data:
        return jsonify({'success': False, 'message': 'Missing required parameters'})
    
    name = data['name']
    card_data = data['card']
    
    flipper = get_flipper_instance()
    if not flipper or not flipper.is_connected():
        return jsonify({'success': False, 'message': 'Flipper Zero is not connected'})
    
    try:
        rfid = RFIDController(flipper)
        result = rfid.save_card(card_data, name)
        
        return jsonify({
            'success': result,
            'message': f'RFID card saved as {name}' if result else f'Failed to save RFID card'
        })
    except Exception as e:
        return jsonify({
            'success': False,
            'message': f'Error saving RFID card: {str(e)}'
        })

@bp.route('/rfid/delete', methods=['POST'])
def delete_rfid_key():
    """Delete RFID key"""
    data = request.json
    if not data or 'key' not in data:
        return jsonify({'success': False, 'message': 'No key name provided'})
    
    key_name = data['key']
    
    flipper = get_flipper_instance()
    if not flipper or not flipper.is_connected():
        return jsonify({'success': False, 'message': 'Flipper Zero is not connected'})
    
    try:
        rfid = RFIDController(flipper)
        result = rfid.delete_key(key_name)
        
        return jsonify({
            'success': result,
            'message': f'RFID key {key_name} deleted' if result else f'Failed to delete RFID key {key_name}'
        })
    except Exception as e:
        return jsonify({
            'success': False,
            'message': f'Error deleting RFID key: {str(e)}'
        })

@bp.route('/subghz/list')
def list_subghz_files():
    """List available SubGHz signal files"""
    flipper = get_flipper_instance()
    if not flipper or not flipper.is_connected():
        return jsonify({'success': False, 'message': 'Flipper Zero is not connected'})
    
    try:
        subghz = SubGHzController(flipper)
        files = subghz.list_files()
        
        return jsonify({
            'success': True,
            'files': files
        })
    except Exception as e:
        return jsonify({
            'success': False,
            'message': f'Error listing SubGHz files: {str(e)}'
        })

@bp.route('/subghz/transmit', methods=['POST'])
def transmit_subghz():
    """Transmit a SubGHz signal"""
    data = request.json
    if not data or 'file' not in data:
        return jsonify({'success': False, 'message': 'No file name provided'})
    
    file_name = data['file']
    
    flipper = get_flipper_instance()
    if not flipper or not flipper.is_connected():
        return jsonify({'success': False, 'message': 'Flipper Zero is not connected'})
    
    try:
        subghz = SubGHzController(flipper)
        result = subghz.transmit(file_name)
        
        return jsonify({
            'success': result,
            'message': f'SubGHz signal {file_name} transmitted successfully' if result else f'Failed to transmit SubGHz signal {file_name}'
        })
    except Exception as e:
        return jsonify({
            'success': False,
            'message': f'Error transmitting SubGHz signal: {str(e)}'
        })

@bp.route('/subghz/receive', methods=['POST'])
def receive_subghz():
    """Receive SubGHz signals"""
    data = request.json
    if not data or 'frequency' not in data:
        return jsonify({'success': False, 'message': 'No frequency provided'})
    
    frequency = data['frequency']
    timeout = data.get('timeout', 30)  # Default 30 seconds timeout
    file_name = data.get('file_name')  # Optional file name
    
    flipper = get_flipper_instance()
    if not flipper or not flipper.is_connected():
        return jsonify({'success': False, 'message': 'Flipper Zero is not connected'})
    
    try:
        # Notify clients that reception is starting
        socketio.emit('subghz_receiving', {'status': 'started', 'frequency': frequency})
        
        subghz = SubGHzController(flipper)
        result = subghz.receive(frequency, timeout=timeout, file_name=file_name)
        
        # Notify clients of reception result
        if result['success']:
            socketio.emit('subghz_receiving', {
                'status': 'completed',
                'frequency': frequency,
                'file': result['file']
            })
        else:
            socketio.emit('subghz_receiving', {
                'status': 'failed',
                'frequency': frequency,
                'error': result.get('error', 'Reception failed')
            })
        
        return jsonify(result)
    except Exception as e:
        socketio.emit('subghz_receiving', {
            'status': 'error',
            'frequency': frequency,
            'message': str(e)
        })
        
        return jsonify({
            'success': False,
            'message': f'Error receiving SubGHz signal: {str(e)}'
        })

@bp.route('/subghz/delete', methods=['POST'])
def delete_subghz_file():
    """Delete SubGHz signal file"""
    data = request.json
    if not data or 'file' not in data:
        return jsonify({'success': False, 'message': 'No file name provided'})
    
    file_name = data['file']
    
    flipper = get_flipper_instance()
    if not flipper or not flipper.is_connected():
        return jsonify({'success': False, 'message': 'Flipper Zero is not connected'})
    
    try:
        subghz = SubGHzController(flipper)
        result = subghz.delete_file(file_name)
        
        return jsonify({
            'success': result,
            'message': f'SubGHz file {file_name} deleted successfully' if result else f'Failed to delete SubGHz file {file_name}'
        })
    except Exception as e:
        return jsonify({
            'success': False,
            'message': f'Error deleting SubGHz file: {str(e)}'
        })

@bp.route('/subghz/frequencies')
def get_subghz_frequencies():
    """Get list of common SubGHz frequencies"""
    flipper = get_flipper_instance()
    if not flipper or not flipper.is_connected():
        return jsonify({'success': False, 'message': 'Flipper Zero is not connected'})
    
    try:
        subghz = SubGHzController(flipper)
        frequencies = subghz.get_common_frequencies()
        
        return jsonify({
            'success': True,
            'frequencies': frequencies
        })
    except Exception as e:
        return jsonify({
            'success': False,
            'message': f'Error getting SubGHz frequencies: {str(e)}'
        }) 