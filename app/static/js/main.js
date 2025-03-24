/**
 * HakPak Main JavaScript File
 * Handles common functionality across the application
 */

// Socket.IO connection
let socket;

// Initialize socket connection if available
function initializeSocket() {
    try {
        socket = io();
        
        socket.on('connect', function() {
            console.log('Connected to WebSocket server');
            showToast('Connection established', 'success');
        });
        
        socket.on('disconnect', function() {
            console.log('Disconnected from WebSocket server');
            showToast('Connection lost', 'danger');
        });
        
        // Listen for global notifications
        socket.on('notification', function(data) {
            showToast(data.message, data.type);
        });
        
        // Listen for system status updates
        socket.on('system_status', function(data) {
            updateSystemStatusBadges(data);
        });
    } catch (e) {
        console.error('Failed to initialize WebSocket connection:', e);
    }
}

// Show a toast notification
function showToast(message, type = 'info') {
    // Create toast container if it doesn't exist
    let toastContainer = document.getElementById('toast-container');
    if (!toastContainer) {
        toastContainer = document.createElement('div');
        toastContainer.id = 'toast-container';
        toastContainer.className = 'position-fixed bottom-0 end-0 p-3';
        document.body.appendChild(toastContainer);
    }
    
    // Create toast
    const toastId = 'toast-' + Date.now();
    const toast = document.createElement('div');
    toast.className = `toast bg-${type} text-light` ;
    toast.id = toastId;
    toast.setAttribute('role', 'alert');
    toast.setAttribute('aria-live', 'assertive');
    toast.setAttribute('aria-atomic', 'true');
    
    // Toast content
    toast.innerHTML = `
        <div class="toast-header bg-${type} text-light">
            <strong class="me-auto">HakPak</strong>
            <button type="button" class="btn-close btn-close-white" data-bs-dismiss="toast" aria-label="Close"></button>
        </div>
        <div class="toast-body">
            ${message}
        </div>
    `;
    
    // Add to container
    toastContainer.appendChild(toast);
    
    // Initialize Bootstrap toast and show it
    const bsToast = new bootstrap.Toast(toast);
    bsToast.show();
    
    // Remove after it's hidden
    toast.addEventListener('hidden.bs.toast', function () {
        toast.remove();
    });
}

// Update system status badges in the navbar
function updateSystemStatusBadges(data) {
    if (data.battery) {
        const batteryLevel = document.getElementById('battery-level');
        if (batteryLevel) {
            batteryLevel.textContent = data.battery.percentage + '%';
            // Change color based on level
            const batteryBadge = batteryLevel.closest('.badge');
            if (batteryBadge) {
                batteryBadge.className = 'badge me-2 '; // Reset classes
                if (data.battery.percentage > 50) {
                    batteryBadge.className += 'bg-success';
                } else if (data.battery.percentage > 20) {
                    batteryBadge.className += 'bg-warning';
                } else {
                    batteryBadge.className += 'bg-danger';
                }
            }
        }
    }
    
    if (data.cpu_usage !== undefined) {
        const cpuUsage = document.getElementById('cpu-usage');
        if (cpuUsage) {
            cpuUsage.textContent = data.cpu_usage + '%';
        }
    }
}

// Run terminal command and show output
function runTerminalCommand(command, outputElementId, callback) {
    if (!command) return;
    
    const outputElement = document.getElementById(outputElementId);
    if (outputElement) {
        outputElement.innerHTML += `<div class="mb-1">$ ${command}</div>`;
        outputElement.scrollTop = outputElement.scrollHeight;
    }
    
    fetch('/terminal/run', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({ command: command })
    })
    .then(response => response.json())
    .then(data => {
        if (outputElement) {
            outputElement.innerHTML += `<div class="mb-3">${data.output}</div>`;
            outputElement.scrollTop = outputElement.scrollHeight;
        }
        if (callback && typeof callback === 'function') {
            callback(data);
        }
    })
    .catch(error => {
        console.error('Error running command:', error);
        if (outputElement) {
            outputElement.innerHTML += `<div class="text-danger mb-3">Error: ${error}</div>`;
            outputElement.scrollTop = outputElement.scrollHeight;
        }
    });
}

// Initialize on page load
document.addEventListener('DOMContentLoaded', function() {
    // Initialize tooltips
    const tooltipTriggerList = [].slice.call(document.querySelectorAll('[data-bs-toggle="tooltip"]'));
    tooltipTriggerList.map(function(tooltipTriggerEl) {
        return new bootstrap.Tooltip(tooltipTriggerEl);
    });
    
    // Initialize Socket.IO connection
    initializeSocket();
}); 