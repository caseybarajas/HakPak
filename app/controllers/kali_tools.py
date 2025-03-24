from flask import Blueprint, render_template, request, jsonify
import subprocess
import os
import json

bp = Blueprint('kali_tools', __name__, url_prefix='/kali')

# Dictionary of common Kali tools with descriptions
COMMON_TOOLS = {
    'network': [
        {
            'name': 'nmap',
            'description': 'Network discovery and security auditing tool',
            'category': 'Network Scanning',
            'command': 'nmap'
        },
        {
            'name': 'wireshark',
            'description': 'Network protocol analyzer',
            'category': 'Network Scanning',
            'command': 'wireshark'
        },
        {
            'name': 'netdiscover',
            'description': 'Active/passive ARP reconnaissance tool',
            'category': 'Network Scanning',
            'command': 'netdiscover'
        }
    ],
    'web': [
        {
            'name': 'burpsuite',
            'description': 'Web vulnerability scanner and proxy',
            'category': 'Web Application',
            'command': 'burpsuite'
        },
        {
            'name': 'sqlmap',
            'description': 'Automatic SQL injection tool',
            'category': 'Web Application',
            'command': 'sqlmap'
        },
        {
            'name': 'dirb',
            'description': 'Web content scanner',
            'category': 'Web Application',
            'command': 'dirb'
        }
    ],
    'wireless': [
        {
            'name': 'aircrack-ng',
            'description': 'WiFi network security suite',
            'category': 'Wireless',
            'command': 'aircrack-ng'
        },
        {
            'name': 'wifite',
            'description': 'Automated wireless attack tool',
            'category': 'Wireless',
            'command': 'wifite'
        },
        {
            'name': 'kismet',
            'description': 'Wireless network detector and sniffer',
            'category': 'Wireless',
            'command': 'kismet'
        }
    ],
    'exploitation': [
        {
            'name': 'metasploit',
            'description': 'Penetration testing framework',
            'category': 'Exploitation',
            'command': 'msfconsole'
        },
        {
            'name': 'hydra',
            'description': 'Password cracking tool',
            'category': 'Exploitation',
            'command': 'hydra'
        },
        {
            'name': 'john',
            'description': 'Password cracker',
            'category': 'Exploitation',
            'command': 'john'
        }
    ]
}

@bp.route('/')
def index():
    """Kali tools main page"""
    return render_template('kali_tools/index.html', tools=COMMON_TOOLS)

@bp.route('/network')
def network_tools():
    """Network tools page"""
    return render_template('kali_tools/network.html', tools=COMMON_TOOLS['network'])

@bp.route('/web')
def web_tools():
    """Web tools page"""
    return render_template('kali_tools/web.html', tools=COMMON_TOOLS['web'])

@bp.route('/wireless')
def wireless_tools():
    """Wireless tools page"""
    return render_template('kali_tools/wireless.html', tools=COMMON_TOOLS['wireless'])

@bp.route('/exploitation')
def exploitation_tools():
    """Exploitation tools page"""
    return render_template('kali_tools/exploitation.html', tools=COMMON_TOOLS['exploitation'])

@bp.route('/run', methods=['POST'])
def run_tool():
    """Run a Kali tool"""
    data = request.json
    if not data or 'command' not in data:
        return jsonify({'success': False, 'message': 'No command provided'})
    
    command = data['command']
    args = data.get('args', '')
    
    # Check if we have a terminal session ID
    session_id = data.get('session_id', None)
    
    # For security, we could implement a whitelist of allowed commands
    # and validate the command before executing
    
    # Execute the command and capture the output
    try:
        if session_id:
            # If we have a session ID, we're running in an existing terminal
            # This would be handled by a terminal management service
            pass
        else:
            # Simple command execution
            full_command = f"{command} {args}"
            process = subprocess.Popen(
                full_command,
                shell=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True
            )
            stdout, stderr = process.communicate(timeout=30)
            
            return jsonify({
                'success': True,
                'command': full_command,
                'output': stdout,
                'error': stderr,
                'exit_code': process.returncode
            })
    except subprocess.TimeoutExpired:
        return jsonify({
            'success': False,
            'message': 'Command timed out',
            'command': f"{command} {args}"
        })
    except Exception as e:
        return jsonify({
            'success': False,
            'message': f"Error executing command: {str(e)}",
            'command': f"{command} {args}"
        })

@bp.route('/check_installation', methods=['POST'])
def check_installation():
    """Check if a tool is installed"""
    data = request.json
    if not data or 'tool' not in data:
        return jsonify({'success': False, 'message': 'No tool specified'})
    
    tool = data['tool']
    
    # Check if the tool is installed
    try:
        process = subprocess.run(
            f"which {tool}",
            shell=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True
        )
        
        if process.returncode == 0:
            return jsonify({
                'success': True,
                'installed': True,
                'path': process.stdout.strip()
            })
        else:
            return jsonify({
                'success': True,
                'installed': False
            })
    except Exception as e:
        return jsonify({
            'success': False,
            'message': f"Error checking installation: {str(e)}"
        }) 