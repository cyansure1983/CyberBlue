#!/bin/bash

# Dynamic Network Interface Detection Script for CyberBlueSOC
# This script automatically detects the primary network interface and updates the configuration

echo "🔍 Detecting primary network interface..."

# Get the default network interface (the one used for internet connectivity)
DEFAULT_INTERFACE=$(ip route | grep default | awk '{print $5}' | head -1)

if [ -z "$DEFAULT_INTERFACE" ]; then
    echo "❌ Error: Could not detect default network interface"
    exit 1
fi

echo "✅ Detected primary interface: $DEFAULT_INTERFACE"

# Update the .env file with the detected interface
ENV_FILE="/home/ubuntu/CyberBlueSOC/.env"

if [ -f "$ENV_FILE" ]; then
    echo "📝 Updating $ENV_FILE with detected interface..."
    
    # Create a backup
    cp "$ENV_FILE" "$ENV_FILE.backup.$(date +%Y%m%d_%H%M%S)"
    
    # Update all SURICATA_INT entries to use the detected interface
    sed -i "s/^SURICATA_INT=.*/SURICATA_INT=$DEFAULT_INTERFACE/" "$ENV_FILE"
    
    echo "✅ Updated SURICATA_INT to $DEFAULT_INTERFACE"
    
    # Show the updated values
    echo "📋 Current SURICATA_INT settings:"
    grep "SURICATA_INT" "$ENV_FILE"
else
    echo "❌ Error: .env file not found at $ENV_FILE"
    exit 1
fi

echo "🎯 Network interface detection and configuration complete!"
echo "💡 You can now restart Suricata with: sudo docker-compose restart suricata"
