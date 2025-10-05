#!/bin/bash

# Dynamic Suricata Startup Script for CyberBlueSOC
# Automatically detects network interface and starts Suricata

echo "🚀 Starting Suricata with dynamic interface detection..."

# Detect the primary network interface
DEFAULT_INTERFACE=$(ip route | grep default | awk '{print $5}' | head -1)

if [ -z "$DEFAULT_INTERFACE" ]; then
    echo "❌ Error: Could not detect default network interface"
    echo "📋 Available interfaces:"
    ip link show | grep -E '^[0-9]+:' | awk -F': ' '{print "   - " $2}' | sed 's/@.*$//'
    exit 1
fi

echo "✅ Detected primary interface: $DEFAULT_INTERFACE"

# Update environment variable
ENV_FILE="/home/ubuntu/CyberBlueSOC/.env"
if [ -f "$ENV_FILE" ]; then
    echo "📝 Updating SURICATA_INT in .env file..."
    sed -i "s/^SURICATA_INT=.*/SURICATA_INT=$DEFAULT_INTERFACE/" "$ENV_FILE"
    echo "✅ Updated SURICATA_INT to $DEFAULT_INTERFACE"
fi

# Stop existing Suricata container if running
echo "🔄 Stopping existing Suricata container..."
docker-compose -f /home/ubuntu/CyberBlueSOC/docker-compose.yml stop suricata 2>/dev/null

# Start Suricata with the correct interface
echo "🌐 Starting Suricata on interface $DEFAULT_INTERFACE..."
docker-compose -f /home/ubuntu/CyberBlueSOC/docker-compose.yml up -d suricata

# Wait a moment and check status
sleep 5
echo "📊 Checking Suricata status..."
docker-compose -f /home/ubuntu/CyberBlueSOC/docker-compose.yml ps suricata

echo "✅ Suricata startup complete!"
echo "📁 Logs will be available in: ./suricata/logs/"
echo "🔍 Events will be visible in Evebox at: http://localhost:7015"
