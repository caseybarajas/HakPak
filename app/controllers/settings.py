from flask import Blueprint, render_template, request, jsonify, redirect, url_for
import os
import subprocess
import json
import shutil

bp = Blueprint('settings', __name__, url_prefix='/settings')

CONFIG_DIR = '/etc/hakpak'
CONFIG_FILE = os.path.join(CONFIG_DIR, 'config.json')

# Default configuration
DEFAULT_CONFIG = {
    'wifi': {
        'ssid': 'hakpak',
        'password': 'pentestallthethings',
        'channel': 6,
        'interface': 'wlan0',
        'hidden': False
    },
    'system': {
        'hostname': 'hakpak',
        'auto_start': True,
        'auto_update': False,
        'terminal_access': True
    },
    'security': {
        'web_login_required': True,
        'username': 'admin',
        'password': 'hakpak',
        'api_key_required': True,
        'api_key': '12345abcde'
    },
    'flipper': {
        'enabled': True,
        'port': '/dev/ttyACM0',
        'baud': 115200,
        'auto_connect': True
    }
}

@bp.route('/')
def index():
    """Settings main page"""
    config = get_config()
    return render_template('settings/index.html', config=config)

@bp.route('/wifi')
def wifi_settings():
    """WiFi settings page"""
    config = get_config()
    return render_template('settings/wifi.html', config=config['wifi'])

@bp.route('/system')
def system_settings():
    """System settings page"""
    config = get_config()
    return render_template('settings/system.html', config=config['system'])

@bp.route('/security')
def security_settings():
    """Security settings page"""
    config = get_config()
    return render_template('settings/security.html', config=config['security'])

@bp.route('/flipper')
def flipper_settings():
    """Flipper Zero settings page"""
    config = get_config()
    return render_template('settings/flipper.html', config=config['flipper'])

@bp.route('/update', methods=['POST'])
def update_settings():
    """Update settings"""
    data = request.json
    if not data or 'section' not in data or 'settings' not in data:
        return jsonify({'success': False, 'message': 'Invalid request'})
    
    section = data['section']
    settings = data['settings']
    
    # Get current config
    config = get_config()
    
    # Update config
    if section in config:
        config[section].update(settings)
    else:
        return jsonify({'success': False, 'message': f"Invalid section: {section}"})
    
    # Save config
    if save_config(config):
        # Apply changes if necessary
        apply_success = apply_changes(section, settings)
        if apply_success:
            return jsonify({'success': True, 'message': 'Settings updated successfully'})
        else:
            return jsonify({'success': True, 'message': 'Settings saved but not applied'})
    else:
        return jsonify({'success': False, 'message': 'Failed to save settings'})

@bp.route('/backup', methods=['GET'])
def backup_config():
    """Backup configuration"""
    config = get_config()
    
    # Create backup filename
    backup_file = f"hakpak_config_backup.json"
    
    # Return as downloadable file
    return jsonify(config), 200, {
        'Content-Type': 'application/json',
        'Content-Disposition': f'attachment; filename={backup_file}'
    }

@bp.route('/restore', methods=['POST'])
def restore_config():
    """Restore configuration from backup"""
    if 'backup_file' not in request.files:
        return jsonify({'success': False, 'message': 'No backup file provided'})
    
    backup_file = request.files['backup_file']
    
    try:
        # Load backup config
        backup_config = json.loads(backup_file.read())
        
        # Validate backup config
        if not validate_config(backup_config):
            return jsonify({'success': False, 'message': 'Invalid backup file'})
        
        # Save backup config
        if save_config(backup_config):
            return jsonify({'success': True, 'message': 'Configuration restored successfully'})
        else:
            return jsonify({'success': False, 'message': 'Failed to restore configuration'})
    except Exception as e:
        return jsonify({'success': False, 'message': f"Error restoring configuration: {str(e)}"})

@bp.route('/reset', methods=['POST'])
def reset_config():
    """Reset configuration to default"""
    if save_config(DEFAULT_CONFIG):
        return jsonify({'success': True, 'message': 'Configuration reset to default'})
    else:
        return jsonify({'success': False, 'message': 'Failed to reset configuration'})

# Utility functions
def get_config():
    """Get configuration"""
    # Create config dir if it doesn't exist
    os.makedirs(CONFIG_DIR, exist_ok=True)
    
    # Create config file if it doesn't exist
    if not os.path.exists(CONFIG_FILE):
        save_config(DEFAULT_CONFIG)
        return DEFAULT_CONFIG
    
    # Load config file
    try:
        with open(CONFIG_FILE, 'r') as f:
            config = json.load(f)
        
        # Ensure all required keys exist
        for section, settings in DEFAULT_CONFIG.items():
            if section not in config:
                config[section] = settings
            else:
                for key, value in settings.items():
                    if key not in config[section]:
                        config[section][key] = value
        
        return config
    except Exception as e:
        print(f"Error loading config: {str(e)}")
        return DEFAULT_CONFIG

def save_config(config):
    """Save configuration"""
    try:
        # Create config dir if it doesn't exist
        os.makedirs(CONFIG_DIR, exist_ok=True)
        
        # Save config file
        with open(CONFIG_FILE, 'w') as f:
            json.dump(config, f, indent=4)
        
        return True
    except Exception as e:
        print(f"Error saving config: {str(e)}")
        return False

def validate_config(config):
    """Validate configuration"""
    # Check if config has all required sections
    for section in DEFAULT_CONFIG.keys():
        if section not in config:
            return False
    
    return True

def apply_changes(section, settings):
    """Apply configuration changes"""
    # Apply changes based on section
    if section == 'wifi':
        # Update WiFi settings
        return update_wifi_settings(settings)
    elif section == 'system':
        # Update system settings
        return update_system_settings(settings)
    elif section == 'security':
        # Update security settings
        return update_security_settings(settings)
    elif section == 'flipper':
        # Update Flipper Zero settings
        return update_flipper_settings(settings)
    
    return False

def update_wifi_settings(settings):
    """Update WiFi settings"""
    try:
        # Update hostapd configuration
        hostapd_conf = '/etc/hostapd/hostapd.conf'
        
        # Create backup
        shutil.copy(hostapd_conf, f"{hostapd_conf}.bak")
        
        # Read current config
        with open(hostapd_conf, 'r') as f:
            lines = f.readlines()
        
        # Update config
        new_lines = []
        for line in lines:
            if line.startswith('ssid=') and 'ssid' in settings:
                new_lines.append(f"ssid={settings['ssid']}\n")
            elif line.startswith('wpa_passphrase=') and 'password' in settings:
                new_lines.append(f"wpa_passphrase={settings['password']}\n")
            elif line.startswith('channel=') and 'channel' in settings:
                new_lines.append(f"channel={settings['channel']}\n")
            elif line.startswith('interface=') and 'interface' in settings:
                new_lines.append(f"interface={settings['interface']}\n")
            elif line.startswith('ignore_broadcast_ssid=') and 'hidden' in settings:
                new_lines.append(f"ignore_broadcast_ssid={'1' if settings['hidden'] else '0'}\n")
            else:
                new_lines.append(line)
        
        # Write new config
        with open(hostapd_conf, 'w') as f:
            f.writelines(new_lines)
        
        # Restart hostapd
        subprocess.run(['systemctl', 'restart', 'hostapd'])
        
        return True
    except Exception as e:
        print(f"Error updating WiFi settings: {str(e)}")
        return False

def update_system_settings(settings):
    """Update system settings"""
    try:
        # Update hostname if changed
        if 'hostname' in settings:
            # Set hostname
            subprocess.run(['hostnamectl', 'set-hostname', settings['hostname']])
        
        # Update auto-start if changed
        if 'auto_start' in settings:
            if settings['auto_start']:
                # Enable service
                subprocess.run(['systemctl', 'enable', 'hakpak.service'])
            else:
                # Disable service
                subprocess.run(['systemctl', 'disable', 'hakpak.service'])
        
        return True
    except Exception as e:
        print(f"Error updating system settings: {str(e)}")
        return False

def update_security_settings(settings):
    """Update security settings"""
    # This would be implemented based on the authentication system used
    return True

def update_flipper_settings(settings):
    """Update Flipper Zero settings"""
    try:
        # Update flipper configuration
        flipper_conf = '/etc/hakpak/flipper.conf'
        
        # Create config dir if it doesn't exist
        os.makedirs(os.path.dirname(flipper_conf), exist_ok=True)
        
        # Create config
        with open(flipper_conf, 'w') as f:
            f.write('# HakPak Flipper Zero Configuration\n')
            for key, value in settings.items():
                if key == 'port':
                    f.write(f"FLIPPER_PORT=\"{value}\"\n")
                elif key == 'baud':
                    f.write(f"FLIPPER_BAUD={value}\n")
                elif key == 'enabled':
                    f.write(f"FLIPPER_ENABLED={'true' if value else 'false'}\n")
        
        return True
    except Exception as e:
        print(f"Error updating Flipper Zero settings: {str(e)}")
        return False 