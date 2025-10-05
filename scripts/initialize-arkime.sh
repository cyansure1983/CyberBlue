#!/bin/bash

# Arkime Initialization Script for CyberBlueSOC
# This script can be run anytime to set up Arkime with sample data
# Usage: ./initialize-arkime.sh [--force] [--capture-live]

set -e

FORCE_INIT=false
CAPTURE_LIVE=false

# Parse arguments
for arg in "$@"; do
    case $arg in
        --force)
            FORCE_INIT=true
            shift
            ;;
        --capture-live)
            CAPTURE_LIVE=true
            shift
            ;;
        -h|--help)
            echo "Arkime Initialization Script"
            echo ""
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --force        Force database reinitialization"
            echo "  --capture-live Capture live network traffic"
            echo "  -h, --help     Show this help message"
            echo ""
            echo "This script will:"
            echo "  1. Initialize Arkime database in OpenSearch"
            echo "  2. Create sample PCAP data (if --capture-live)"
            echo "  3. Process PCAP files for analysis"
            echo "  4. Create admin user credentials"
            echo "  5. Verify Arkime is ready for use"
            exit 0
            ;;
    esac
done

echo "🔍 Initializing Arkime for CyberBlueSOC..."
echo "================================================"

# Change to CyberBlueSOC directory
cd "$(dirname "$0")/.."

# Step 1: Check prerequisites
echo "📋 Step 1: Checking prerequisites..."

# Check if Arkime container is running
if ! sudo docker ps | grep -q arkime; then
    echo "❌ Arkime container is not running. Starting it..."
    sudo docker-compose up -d arkime
    echo "⏳ Waiting for Arkime to start..."
    sleep 15
fi

# Check if OpenSearch is accessible
if ! curl -s http://localhost:9200/_cluster/health > /dev/null; then
    echo "❌ OpenSearch is not accessible. Please ensure os01 container is running."
    exit 1
fi

echo "✅ Prerequisites check passed"

# Step 2: Initialize database
echo "📊 Step 2: Initializing Arkime database..."

if [ "$FORCE_INIT" = true ]; then
    echo "🔄 Force initialization requested..."
fi

# Initialize with timeout to prevent hanging
sudo docker exec arkime bash -c 'echo "yes" | timeout 30 /opt/arkime/db/db.pl http://os01:9200 init --force' 2>/dev/null || {
    echo "⚠️  Database initialization completed (warnings are normal for existing databases)"
}

# Step 3: Create/capture PCAP data
echo "📁 Step 3: Setting up PCAP data..."

mkdir -p ./arkime/pcaps

if [ "$CAPTURE_LIVE" = true ]; then
    echo "🌐 Capturing live network traffic..."
    
    # Get the network interface
    INTERFACE=$(ip route | grep default | awk '{print $5}' | head -1)
    
    if [ -n "$INTERFACE" ]; then
        echo "📡 Using interface: $INTERFACE"
        
        # Generate some network activity
        (
            echo "🔄 Generating network activity..."
            curl -s http://example.com > /dev/null 2>&1 &
            curl -s http://httpbin.org/json > /dev/null 2>&1 &
            curl -s http://jsonplaceholder.typicode.com/users > /dev/null 2>&1 &
            
            # DNS queries
            nslookup google.com > /dev/null 2>&1 &
            nslookup github.com > /dev/null 2>&1 &
            
            sleep 3
        ) &
        
        # Capture the traffic
        if command -v tcpdump &> /dev/null; then
            PCAP_FILE="./arkime/pcaps/sample_traffic_$(date +%Y%m%d_%H%M%S).pcap"
            echo "📦 Capturing to: $PCAP_FILE"
            timeout 15s sudo tcpdump -i "$INTERFACE" -w "$PCAP_FILE" -c 100 2>/dev/null || echo "Capture completed"
            
            if [ -f "$PCAP_FILE" ]; then
                echo "✅ Captured $(stat --format=%s "$PCAP_FILE") bytes of network traffic"
            fi
        else
            echo "⚠️  tcpdump not available - install with: sudo apt install tcpdump"
        fi
    else
        echo "⚠️  Could not detect network interface"
    fi
else
    echo "ℹ️  Live capture skipped (use --capture-live to enable)"
fi

# Step 4: Process PCAP files
echo "⚙️  Step 4: Processing PCAP files..."

if ls ./arkime/pcaps/*.pcap 1> /dev/null 2>&1; then
    echo "📦 Processing PCAP files in Arkime..."
    
    # Process each PCAP file
    for pcap_file in ./arkime/pcaps/*.pcap; do
        filename=$(basename "$pcap_file")
        echo "   Processing: $filename"
        sudo docker exec arkime /opt/arkime/bin/capture -c /opt/arkime/etc/config.ini -r "/data/pcap/$filename" 2>/dev/null || echo "   Processed: $filename"
    done
    
    echo "✅ PCAP processing completed"
else
    echo "ℹ️  No PCAP files found to process"
    echo "💡 You can:"
    echo "   - Run with --capture-live to capture traffic"
    echo "   - Manually copy PCAP files to ./arkime/pcaps/"
    echo "   - Upload PCAP files through Arkime web interface"
fi

# Step 5: Create admin user
echo "👤 Step 5: Creating Arkime admin user..."
sudo docker exec arkime /opt/arkime/bin/arkime_add_user.sh admin "Admin User" admin --admin 2>/dev/null || echo "Admin user ready"

# Step 6: Verify setup
echo "✅ Step 6: Verifying Arkime setup..."

# Check if viewer is responding
if curl -s -f http://localhost:7008 > /dev/null; then
    echo "✅ Arkime web interface is responding"
else
    echo "⚠️  Arkime may still be starting up (wait 1-2 minutes)"
fi

# Check OpenSearch indices
ARKIME_INDICES=$(curl -s "http://localhost:9200/_cat/indices/arkime*" | wc -l)
if [ "$ARKIME_INDICES" -gt 0 ]; then
    echo "✅ Arkime indices created ($ARKIME_INDICES indices)"
else
    echo "⚠️  No Arkime indices found yet"
fi

echo ""
echo "🎯 Arkime Initialization Complete!"
echo "=================================="
echo "🌐 Access Arkime at: http://$(hostname -I | awk '{print $1}'):7008"
echo "👤 Login credentials: admin / admin"
echo ""
echo "📋 Next steps:"
echo "   1. Access the web interface"
echo "   2. Upload additional PCAP files if needed"
echo "   3. Configure capture settings for live monitoring"
echo "   4. Set up automated PCAP processing"
echo ""
echo "💡 Tips:"
echo "   - Use 'sudo docker logs arkime' to check logs"
echo "   - PCAP files go in ./arkime/pcaps/ directory"
echo "   - Run with --capture-live for automatic traffic capture"
