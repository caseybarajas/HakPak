/**
 * HakPak - Flipper Zero Integration JavaScript
 * 
 * This file contains frontend logic for the Flipper Zero integration
 */

class FlipperController {
    constructor() {
        // Socket.io connection
        this.socket = io();
        
        // Connection status and device info
        this.isConnected = false;
        this.deviceInfo = {};
        
        // DOM elements cache
        this.elements = {
            connectionStatus: document.getElementById('connection-status'),
            deviceInfo: document.getElementById('device-info'),
            firmwareVersion: document.getElementById('firmware-version'),
            batteryLevel: document.getElementById('battery-level'),
            serialPort: document.getElementById('serial-port'),
            btnConnect: document.getElementById('btn-connect'),
            btnDisconnect: document.getElementById('btn-disconnect'),
            irSignalsList: document.getElementById('ir-signals-list'),
            irSignalsLoading: document.getElementById('ir-signals-loading'),
            irSignalsEmpty: document.getElementById('ir-signals-empty'),
            btnRefreshSignals: document.getElementById('btn-refresh-signals'),
            recordIrForm: document.getElementById('record-ir-form'),
            irSignalName: document.getElementById('ir-signal-name'),
            btnRecordIr: document.getElementById('btn-record-ir'),
            recordingStatus: document.getElementById('recording-status'),
            commandForm: document.getElementById('command-form'),
            commandInput: document.getElementById('command-input'),
            commandResponse: document.getElementById('command-response'),
            quickCommands: document.querySelectorAll('.quick-command'),
            subghzSignalsList: document.getElementById('subghz-signals-list'),
            subghzSignalsLoading: document.getElementById('subghz-signals-loading'),
            subghzSignalsEmpty: document.getElementById('subghz-signals-empty'),
            btnRefreshSubghz: document.getElementById('btn-refresh-subghz'),
            receiveSubghzForm: document.getElementById('receive-subghz-form'),
            subghzFrequency: document.getElementById('subghz-frequency'),
            subghzFileName: document.getElementById('subghz-file-name'),
            subghzTimeout: document.getElementById('subghz-timeout'),
            btnReceiveSubghz: document.getElementById('btn-receive-subghz'),
            receivingStatus: document.getElementById('receiving-status'),
            receivingFrequency: document.getElementById('receiving-frequency')
        };
        
        // Initialize
        this.initialize();
    }
    
    initialize() {
        // Check connection status on page load
        this.checkConnectionStatus();
        
        // Set up event listeners
        this.setupEventListeners();
        
        // Set up socket listeners
        this.setupSocketListeners();
        
        // Load SubGHz frequencies
        this.loadSubghzFrequencies();
    }
    
    setupEventListeners() {
        // Connect button
        this.elements.btnConnect.addEventListener('click', () => this.connect());
        
        // Disconnect button
        this.elements.btnDisconnect.addEventListener('click', () => this.disconnect());
        
        // Refresh IR signals
        this.elements.btnRefreshSignals.addEventListener('click', () => this.loadIrSignals());
        
        // Record IR signal
        this.elements.recordIrForm.addEventListener('submit', (e) => this.recordIrSignal(e));
        
        // Send command
        this.elements.commandForm.addEventListener('submit', (e) => this.sendCommandForm(e));
        
        // Quick commands
        this.elements.quickCommands.forEach(button => {
            button.addEventListener('click', () => {
                const command = button.getAttribute('data-command');
                this.sendCommand(command);
            });
        });
        
        // Refresh SubGHz signals
        this.elements.btnRefreshSubghz.addEventListener('click', () => this.loadSubghzSignals());
        
        // Receive SubGHz signal
        this.elements.receiveSubghzForm.addEventListener('submit', (e) => this.receiveSubghzSignal(e));
    }
    
    setupSocketListeners() {
        // Flipper status updates
        this.socket.on('flipper_status', (data) => {
            if (data.status === 'detached') {
                this.updateConnectionStatus(false);
            } else if (data.status === 'error') {
                this.showAlert(this.elements.connectionStatus, 'danger', 
                    `<i class="bi bi-exclamation-triangle-fill"></i> ${data.message}`);
            }
        });
        
        // IR recording status
        this.socket.on('ir_recording', (data) => {
            if (data.status === 'completed') {
                this.elements.recordingStatus.classList.add('d-none');
                this.elements.btnRecordIr.disabled = false;
                this.elements.irSignalName.value = '';
                this.loadIrSignals();
                alert(`Successfully recorded IR signal: ${data.name}`);
            } else if (data.status === 'failed' || data.status === 'error') {
                this.elements.recordingStatus.classList.add('d-none');
                this.elements.btnRecordIr.disabled = false;
                alert(`Failed to record IR signal: ${data.message || 'Recording timeout or error'}`);
            }
        });
        
        // SubGHz receiving status
        this.socket.on('subghz_receiving', (data) => {
            if (data.status === 'completed') {
                this.elements.receivingStatus.classList.add('d-none');
                this.elements.btnReceiveSubghz.disabled = false;
                this.loadSubghzSignals();
                alert(`Successfully captured SubGHz signal on ${data.frequency} MHz`);
            } else if (data.status === 'failed' || data.status === 'error') {
                this.elements.receivingStatus.classList.add('d-none');
                this.elements.btnReceiveSubghz.disabled = false;
                alert(`Failed to capture SubGHz signal: ${data.message || data.error || 'Reception failed'}`);
            }
        });
    }
    
    // Check Flipper Zero connection status
    checkConnectionStatus() {
        fetch('/flipper/status')
            .then(response => response.json())
            .then(data => {
                this.updateConnectionStatus(data.connected);
                if (data.connected) {
                    this.updateDeviceInfo(data);
                    this.loadIrSignals();
                }
            })
            .catch(error => {
                console.error('Error checking Flipper Zero status:', error);
            });
    }
    
    // Update connection status UI
    updateConnectionStatus(connected) {
        this.isConnected = connected;
        
        if (connected) {
            this.elements.connectionStatus.className = 'alert alert-success mb-3';
            this.elements.connectionStatus.innerHTML = '<i class="bi bi-check-circle-fill"></i> Flipper Zero connected';
            this.elements.deviceInfo.classList.remove('d-none');
            this.elements.btnConnect.disabled = true;
            this.elements.btnDisconnect.disabled = false;
        } else {
            this.elements.connectionStatus.className = 'alert alert-warning mb-3';
            this.elements.connectionStatus.innerHTML = '<i class="bi bi-exclamation-triangle-fill"></i> Flipper Zero not connected';
            this.elements.deviceInfo.classList.add('d-none');
            this.elements.btnConnect.disabled = false;
            this.elements.btnDisconnect.disabled = true;
            
            // Hide IR signals
            this.elements.irSignalsList.classList.add('d-none');
            this.elements.irSignalsEmpty.classList.add('d-none');
            this.elements.irSignalsLoading.classList.remove('d-none');
        }
    }
    
    // Update device info UI
    updateDeviceInfo(data) {
        this.deviceInfo = data;
        this.elements.firmwareVersion.textContent = data.firmware || 'Unknown';
        this.elements.batteryLevel.textContent = data.battery || 'Unknown';
        this.elements.serialPort.textContent = data.port || 'Unknown';
    }
    
    // Connect to Flipper Zero
    connect() {
        fetch('/flipper/connect', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({})
        })
        .then(response => response.json())
        .then(data => {
            if (data.success) {
                this.updateConnectionStatus(true);
                this.loadIrSignals();
            } else {
                this.showAlert(this.elements.connectionStatus, 'danger', 
                    `<i class="bi bi-exclamation-triangle-fill"></i> ${data.message}`);
            }
        })
        .catch(error => {
            this.showAlert(this.elements.connectionStatus, 'danger', 
                `<i class="bi bi-exclamation-triangle-fill"></i> Error connecting to Flipper Zero: ${error}`);
        });
    }
    
    // Disconnect from Flipper Zero
    disconnect() {
        fetch('/flipper/detach', {
            method: 'POST'
        })
        .then(response => response.json())
        .then(data => {
            if (data.success) {
                this.updateConnectionStatus(false);
            } else {
                this.showAlert(this.elements.connectionStatus, 'danger', 
                    `<i class="bi bi-exclamation-triangle-fill"></i> ${data.message}`);
            }
        })
        .catch(error => {
            this.showAlert(this.elements.connectionStatus, 'danger', 
                `<i class="bi bi-exclamation-triangle-fill"></i> Error disconnecting from Flipper Zero: ${error}`);
        });
    }
    
    // Load IR signals
    loadIrSignals() {
        if (!this.isConnected) return;
        
        // Show loading
        this.elements.irSignalsLoading.classList.remove('d-none');
        this.elements.irSignalsList.classList.add('d-none');
        this.elements.irSignalsEmpty.classList.add('d-none');
        
        fetch('/flipper/ir/list')
            .then(response => response.json())
            .then(data => {
                this.elements.irSignalsLoading.classList.add('d-none');
                
                if (data.success && data.signals && data.signals.length > 0) {
                    this.elements.irSignalsList.innerHTML = '';
                    
                    data.signals.forEach(signal => {
                        const li = document.createElement('li');
                        li.className = 'list-group-item bg-dark text-light border-secondary signal-item d-flex justify-content-between align-items-center';
                        
                        const nameSpan = document.createElement('span');
                        nameSpan.textContent = signal;
                        
                        const btnSend = document.createElement('button');
                        btnSend.className = 'btn btn-sm btn-flipper';
                        btnSend.innerHTML = '<i class="bi bi-play-fill"></i> Send';
                        btnSend.onclick = () => {
                            this.sendIrSignal(signal);
                        };
                        
                        li.appendChild(nameSpan);
                        li.appendChild(btnSend);
                        this.elements.irSignalsList.appendChild(li);
                    });
                    
                    this.elements.irSignalsList.classList.remove('d-none');
                } else {
                    this.elements.irSignalsEmpty.classList.remove('d-none');
                }
            })
            .catch(error => {
                this.elements.irSignalsLoading.classList.add('d-none');
                this.elements.irSignalsEmpty.classList.remove('d-none');
                console.error('Error loading IR signals:', error);
            });
    }
    
    // Send IR signal
    sendIrSignal(signal) {
        fetch('/flipper/ir/send', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                signal: signal
            })
        })
        .then(response => response.json())
        .then(data => {
            if (!data.success) {
                alert(`Failed to send IR signal: ${data.message}`);
            }
        })
        .catch(error => {
            alert(`Error sending IR signal: ${error}`);
        });
    }
    
    // Record IR signal
    recordIrSignal(e) {
        e.preventDefault();
        const signalName = this.elements.irSignalName.value.trim();
        
        if (!signalName) {
            alert('Please enter a signal name');
            return;
        }
        
        // Show recording status
        this.elements.recordingStatus.classList.remove('d-none');
        this.elements.btnRecordIr.disabled = true;
        
        fetch('/flipper/ir/record', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                name: signalName
            })
        })
        .then(response => response.json())
        .then(data => {
            // Don't hide recording status - it will be hidden by socket event
        })
        .catch(error => {
            this.elements.recordingStatus.classList.add('d-none');
            this.elements.btnRecordIr.disabled = false;
            alert(`Error recording IR signal: ${error}`);
        });
    }
    
    // Send command form handler
    sendCommandForm(e) {
        e.preventDefault();
        const command = this.elements.commandInput.value.trim();
        
        if (!command) {
            alert('Please enter a command');
            return;
        }
        
        this.sendCommand(command);
    }
    
    // Send command to Flipper Zero
    sendCommand(command) {
        fetch('/flipper/execute', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                command: command
            })
        })
        .then(response => response.json())
        .then(data => {
            if (data.success) {
                this.elements.commandResponse.textContent = JSON.stringify(data.result.response, null, 2);
            } else {
                this.elements.commandResponse.textContent = `Error: ${data.message}`;
            }
        })
        .catch(error => {
            this.elements.commandResponse.textContent = `Error: ${error}`;
        });
    }
    
    // Load SubGHz signals
    loadSubghzSignals() {
        if (!this.isConnected) return;
        
        // Show loading
        this.elements.subghzSignalsLoading.classList.remove('d-none');
        this.elements.subghzSignalsList.classList.add('d-none');
        this.elements.subghzSignalsEmpty.classList.add('d-none');
        
        fetch('/flipper/subghz/list')
            .then(response => response.json())
            .then(data => {
                this.elements.subghzSignalsLoading.classList.add('d-none');
                
                if (data.success && data.files && data.files.length > 0) {
                    this.elements.subghzSignalsList.innerHTML = '';
                    
                    data.files.forEach(file => {
                        const li = document.createElement('li');
                        li.className = 'list-group-item bg-dark text-light border-secondary signal-item d-flex justify-content-between align-items-center';
                        
                        const nameSpan = document.createElement('span');
                        nameSpan.textContent = file;
                        
                        const btnGroup = document.createElement('div');
                        btnGroup.className = 'btn-group';
                        
                        const btnTransmit = document.createElement('button');
                        btnTransmit.className = 'btn btn-sm btn-flipper';
                        btnTransmit.innerHTML = '<i class="bi bi-broadcast-pin"></i> Transmit';
                        btnTransmit.onclick = () => {
                            this.transmitSubghzSignal(file);
                        };
                        
                        const btnDelete = document.createElement('button');
                        btnDelete.className = 'btn btn-sm btn-danger';
                        btnDelete.innerHTML = '<i class="bi bi-trash"></i>';
                        btnDelete.onclick = () => {
                            if (confirm(`Delete SubGHz signal ${file}?`)) {
                                this.deleteSubghzSignal(file);
                            }
                        };
                        
                        btnGroup.appendChild(btnTransmit);
                        btnGroup.appendChild(btnDelete);
                        
                        li.appendChild(nameSpan);
                        li.appendChild(btnGroup);
                        this.elements.subghzSignalsList.appendChild(li);
                    });
                    
                    this.elements.subghzSignalsList.classList.remove('d-none');
                } else {
                    this.elements.subghzSignalsEmpty.classList.remove('d-none');
                }
            })
            .catch(error => {
                this.elements.subghzSignalsLoading.classList.add('d-none');
                this.elements.subghzSignalsEmpty.classList.remove('d-none');
                console.error('Error loading SubGHz signals:', error);
            });
    }
    
    // Load SubGHz frequencies
    loadSubghzFrequencies() {
        fetch('/flipper/subghz/frequencies')
            .then(response => response.json())
            .then(data => {
                if (data.success && data.frequencies) {
                    this.elements.subghzFrequency.innerHTML = '';
                    
                    data.frequencies.forEach(freq => {
                        const option = document.createElement('option');
                        option.value = freq.value;
                        option.textContent = freq.label;
                        this.elements.subghzFrequency.appendChild(option);
                    });
                }
            })
            .catch(error => {
                console.error('Error loading SubGHz frequencies:', error);
            });
    }
    
    // Transmit SubGHz signal
    transmitSubghzSignal(file) {
        fetch('/flipper/subghz/transmit', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                file: file
            })
        })
        .then(response => response.json())
        .then(data => {
            if (!data.success) {
                alert(`Failed to transmit SubGHz signal: ${data.message}`);
            }
        })
        .catch(error => {
            alert(`Error transmitting SubGHz signal: ${error}`);
        });
    }
    
    // Delete SubGHz signal
    deleteSubghzSignal(file) {
        fetch('/flipper/subghz/delete', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                file: file
            })
        })
        .then(response => response.json())
        .then(data => {
            if (data.success) {
                this.loadSubghzSignals();
            } else {
                alert(`Failed to delete SubGHz signal: ${data.message}`);
            }
        })
        .catch(error => {
            alert(`Error deleting SubGHz signal: ${error}`);
        });
    }
    
    // Receive SubGHz signal
    receiveSubghzSignal(e) {
        e.preventDefault();
        const frequency = this.elements.subghzFrequency.value;
        const fileName = this.elements.subghzFileName.value.trim();
        const timeout = parseInt(this.elements.subghzTimeout.value) || 30;
        
        // Show receiving status
        this.elements.receivingStatus.classList.remove('d-none');
        this.elements.btnReceiveSubghz.disabled = true;
        this.elements.receivingFrequency.textContent = `${frequency} MHz`;
        
        fetch('/flipper/subghz/receive', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                frequency: frequency,
                file_name: fileName || undefined,
                timeout: timeout
            })
        })
        .then(response => response.json())
        .then(data => {
            // Don't hide receiving status - it will be hidden by socket event
        })
        .catch(error => {
            this.elements.receivingStatus.classList.add('d-none');
            this.elements.btnReceiveSubghz.disabled = false;
            alert(`Error receiving SubGHz signal: ${error}`);
        });
    }
    
    // Show alert in specified element
    showAlert(element, type, message) {
        element.className = `alert alert-${type} mb-3`;
        element.innerHTML = message;
    }
}

// Initialize when DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
    // Initialize the Flipper controller
    window.flipperController = new FlipperController();
}); 