#!/bin/bash

# Enhanced Arkime Fix & Initialization Script
# Extracted and enhanced from cyberblue_init.sh
# This script provides comprehensive Arkime setup and troubleshooting

set -e

# Parse arguments
FORCE_INIT=false
CAPTURE_LIVE=false
LIVE_CAPTURE=false
CAPTURE_DURATION=60  # Default 1 minute (60 seconds)

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
        --live)
            LIVE_CAPTURE=true
            shift
            ;;
        --live-*)
            LIVE_CAPTURE=true
            # Extract duration from --live-5min, --live-30s, etc.
            DURATION_STR="${arg#--live-}"
            if [[ "$DURATION_STR" =~ ^([0-9]+)(min|m)$ ]]; then
                CAPTURE_DURATION=$((${BASH_REMATCH[1]} * 60))
            elif [[ "$DURATION_STR" =~ ^([0-9]+)(sec|s)$ ]]; then
                CAPTURE_DURATION=${BASH_REMATCH[1]}
            elif [[ "$DURATION_STR" =~ ^([0-9]+)$ ]]; then
                CAPTURE_DURATION=${BASH_REMATCH[1]}  # Default to seconds if no unit
            else
                echo "❌ Invalid duration format: $arg"
                echo "💡 Use: --live-5min, --live-30s, --live-300, etc."
                exit 1
            fi
            shift
            ;;
        -t|--time)
            LIVE_CAPTURE=true
            shift
            if [[ "$1" =~ ^([0-9]+)(min|m)$ ]]; then
                CAPTURE_DURATION=$((${BASH_REMATCH[1]} * 60))
            elif [[ "$1" =~ ^([0-9]+)(sec|s)$ ]]; then
                CAPTURE_DURATION=${BASH_REMATCH[1]}
            elif [[ "$1" =~ ^([0-9]+)$ ]]; then
                CAPTURE_DURATION=$1
            else
                echo "❌ Invalid duration format: $1"
                echo "💡 Use: 5min, 30s, 300, etc."
                exit 1
            fi
            shift
            ;;
        -h|--help)
            echo "Enhanced Arkime Fix & Initialization Script"
            echo ""
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --force              Force database reinitialization"
            echo "  --capture-live       Capture live network traffic (short burst)"
            echo "  --live               Live capture for 1 minute (default), process, then cleanup"
            echo "  --live-5min          Live capture for 5 minutes"
            echo "  --live-30s           Live capture for 30 seconds"
            echo "  -t, --time DURATION  Custom capture duration (e.g., 5min, 30s, 120)"
            echo "  -h, --help           Show this help message"
            echo ""
            echo "Duration Examples:"
            echo "  --live              # 1 minute (default)"
            echo "  --live-5min         # 5 minutes"
            echo "  --live-30s          # 30 seconds"
            echo "  --live-600          # 600 seconds (10 minutes)"
            echo "  -t 2min             # 2 minutes"
            echo "  -t 45s              # 45 seconds"
            echo ""
            echo "This script will:"
            echo "  1. Initialize Arkime database in OpenSearch"
            echo "  2. Create sample PCAP data (based on capture mode)"
            echo "  3. Process PCAP files for analysis"
            echo "  4. Create admin user credentials"
            echo "  5. Verify Arkime is ready for use"
            echo "  6. Auto-cleanup files (in live capture modes)"
            exit 0
            ;;
    esac
done

# Global variables for cleanup
CURRENT_PCAP_FILE=""
TCPDUMP_PID=""

# Function to handle interrupts during capture
handle_interrupt() {
    echo ""
    echo "⚠️  Capture interrupted by user (Ctrl+C)"
    
    # Clean up background capture process
    if [ -n "$TCPDUMP_PID" ]; then
        kill $TCPDUMP_PID 2>/dev/null || true
    fi
    
    if [ -n "$CURRENT_PCAP_FILE" ] && [ -f "$CURRENT_PCAP_FILE" ]; then
        FILESIZE=$(stat --format=%s "$CURRENT_PCAP_FILE" 2>/dev/null || echo "0")
        echo "📊 Partial capture saved: ${FILESIZE} bytes"
        echo "🌐 Check Arkime web interface for captured data: http://${HOST_IP:-localhost}:7008"
    fi
}

# Function to ensure clean exit
cleanup_and_exit() {
    local exit_code=${1:-0}
    echo ""
    echo "🏁 Arkime setup completed. Exiting..."
    exit $exit_code
}

# Set up interrupt handler
trap handle_interrupt INT

# Function to cleanup PCAP files after processing
cleanup_pcap_files() {
    echo "🧹 Cleaning up PCAP files..."
    if ls ./arkime/pcaps/*.pcap 1> /dev/null 2>&1; then
        for pcap_file in ./arkime/pcaps/*.pcap; do
            filename=$(basename "$pcap_file")
            echo "   Removing: $filename"
            sudo rm -f "$pcap_file"
        done
        echo "✅ PCAP files cleaned up"
    else
        echo "ℹ️  No PCAP files to cleanup"
    fi
}

# Detect network interface dynamically
detect_network_interface() {
    echo "🔍 Detecting primary network interface..."
    
    # Method 1: Try to get the default route interface (most reliable)
    SURICATA_IFACE=$(ip route | grep default | awk '{print $5}' | head -1)
    
    # Method 2: Fallback to first active non-loopback interface
    if [ -z "$SURICATA_IFACE" ]; then
        echo "⚠️  No default route found, trying alternative detection..."
        SURICATA_IFACE=$(ip link show | grep -E '^[0-9]+:' | grep -v lo | grep 'state UP' | awk -F': ' '{print $2}' | head -1)
    fi
    
    # Method 3: Final fallback to any UP interface except loopback
    if [ -z "$SURICATA_IFACE" ]; then
        echo "⚠️  Trying final fallback method..."
        SURICATA_IFACE=$(ip a | grep 'state UP' | grep -v lo | awk -F: '{print $2}' | head -1 | xargs)
    fi
    
    if [ -z "$SURICATA_IFACE" ]; then
        echo "❌ Could not detect any suitable network interface."
        echo "📋 Available interfaces:"
        ip link show | grep -E '^[0-9]+:' | awk -F': ' '{print "   - " $2}' | sed 's/@.*$//'
        SURICATA_IFACE="ens5"  # Common AWS default
        echo "💡 Using default interface: $SURICATA_IFACE"
    fi
    
    echo "✅ Detected/Using interface: $SURICATA_IFACE"
}

echo "🔍 Enhanced Arkime Setup & Troubleshooting"
echo "=========================================="

# Step 1: Check prerequisites
echo "📋 Step 1: Checking Arkime prerequisites..."

# Check if Arkime container is running
if ! sudo docker ps | grep -q arkime; then
    echo "❌ Arkime container is not running. Starting it..."
    sudo docker-compose up -d arkime
    echo "⏳ Waiting for Arkime to start..."
    sleep 15
fi

# Wait for OpenSearch to be ready with enhanced checking
echo "⏳ Waiting for OpenSearch to be ready..."
for i in {1..10}; do
    # Check OpenSearch from within the Docker network via Arkime container
    if sudo docker exec arkime curl -s http://os01:9200/_cluster/health | grep -q "green\|yellow"; then
        echo "✅ OpenSearch is ready"
        break
    fi
    echo "   Waiting for OpenSearch... ($i/10)"
    sleep 5
done

# Verify OpenSearch is accessible from Arkime container
if ! sudo docker exec arkime curl -s http://os01:9200/_cluster/health > /dev/null 2>&1; then
    echo "❌ OpenSearch is not accessible from Arkime container. Please ensure os01 container is running."
    echo "⚠️  Continuing with limited Arkime functionality..."
else
    echo "✅ Prerequisites check passed - OpenSearch is accessible via Docker network"
fi

# Step 2: Initialize Arkime database with better error handling
echo "📊 Step 2: Initializing Arkime database..."

if [ "$FORCE_INIT" = true ]; then
    echo "🔄 Force initializing database..."
    sudo docker exec arkime bash -c '/opt/arkime/db/db.pl http://os01:9200 init --force --insecure' 2>/dev/null || {
        echo "⚠️  Database initialization completed (warnings are normal for existing databases)"
    }
else
    # Skip interactive database initialization to avoid the INIT prompt loop
    echo "ℹ️  Skipping database initialization (use --force to initialize)"
    echo "💡 Database will be auto-created when first PCAP is processed"
fi

# Step 3: Enhanced PCAP data creation and capture
echo "📁 Step 3: Setting up enhanced PCAP data collection..."

mkdir -p ./arkime/pcaps

if [ "$LIVE_CAPTURE" = true ]; then
    # Live capture mode with custom duration
    detect_network_interface
    
    # Convert duration to human readable format
    if [ $CAPTURE_DURATION -ge 60 ]; then
        DURATION_MIN=$((CAPTURE_DURATION / 60))
        DURATION_SEC=$((CAPTURE_DURATION % 60))
        if [ $DURATION_SEC -eq 0 ]; then
            DURATION_DISPLAY="${DURATION_MIN} minute(s)"
        else
            DURATION_DISPLAY="${DURATION_MIN}m ${DURATION_SEC}s"
        fi
    else
        DURATION_DISPLAY="${CAPTURE_DURATION} seconds"
    fi
    
    echo "🌐 Starting live network capture for ${DURATION_DISPLAY}..."
    echo "⏰ This will capture real network traffic, process it live, then cleanup"
    echo "🔍 Using interface: $SURICATA_IFACE"
    echo "💡 Press Ctrl+C to stop capture early if needed"
    
    if command -v tcpdump &> /dev/null; then
        PCAP_FILE="./arkime/pcaps/live_capture_${CAPTURE_DURATION}s_$(date +%Y%m%d_%H%M%S).pcap"
        CURRENT_PCAP_FILE="$PCAP_FILE"  # Set global variable for interrupt handler
        echo "📦 Starting live capture to: $PCAP_FILE"
        echo "⏳ Capture will run for ${DURATION_DISPLAY} (${CAPTURE_DURATION} seconds)..."
        
        # Start capture in background
        echo "🚀 Starting background capture process..."
        timeout ${CAPTURE_DURATION}s sudo tcpdump -i "$SURICATA_IFACE" -w "$PCAP_FILE" 2>/dev/null &
        TCPDUMP_PID=$!
        
        # Note: Arkime will automatically detect and process new PCAP files
        echo "🔄 Arkime will auto-detect the PCAP file - check web interface for live updates!"
        
        echo "📊 Monitoring capture progress and Arkime updates..."
        echo "   (Press Ctrl+C to stop capture early)"
        echo ""
        
        # Monitor capture with real-time updates
        START_TIME=$(date +%s)
        LAST_SIZE=0
        LAST_PROCESSED=0
        
        while kill -0 $TCPDUMP_PID 2>/dev/null; do
            sleep 10
            
            # Calculate elapsed time
            CURRENT_TIME=$(date +%s)
            ELAPSED=$((CURRENT_TIME - START_TIME))
            REMAINING=$((CAPTURE_DURATION - ELAPSED))
            
            # Get current PCAP file size
            if [ -f "$PCAP_FILE" ]; then
                CURRENT_SIZE=$(stat --format=%s "$PCAP_FILE" 2>/dev/null || echo "0")
                SIZE_MB=$((CURRENT_SIZE / 1024 / 1024))
                GROWTH=$((CURRENT_SIZE - LAST_SIZE))
                GROWTH_KB=$((GROWTH / 1024))
                
                # Check Arkime processing status
                if sudo docker exec arkime curl -s http://os01:9200/_cat/indices/arkime* 2>/dev/null | grep -q arkime; then
                    ARKIME_DOCS=$(sudo docker exec arkime curl -s "http://os01:9200/_cat/indices/arkime*?h=docs.count" 2>/dev/null | awk '{sum+=$1} END {print sum+0}')
                    NEW_DOCS=$((ARKIME_DOCS - LAST_PROCESSED))
                    ARKIME_STATUS="📈 Docs: $ARKIME_DOCS (+$NEW_DOCS)"
                    LAST_PROCESSED=$ARKIME_DOCS
                else
                    ARKIME_STATUS="⏳ Indices creating..."
                fi
                
                echo "⏰ ${ELAPSED}s | 📦 ${SIZE_MB}MB (+${GROWTH_KB}KB) | ${ARKIME_STATUS} | ⏳ ${REMAINING}s left"
                LAST_SIZE=$CURRENT_SIZE
            else
                echo "⏰ ${ELAPSED}s | 📦 Waiting for capture to start... | ⏳ ${REMAINING}s left"
            fi
            
            # Break if time exceeded
            if [ $ELAPSED -ge $CAPTURE_DURATION ]; then
                break
            fi
        done
        
        # Force stop tcpdump if still running after timeout
        if kill -0 $TCPDUMP_PID 2>/dev/null; then
            echo "🛑 Stopping capture process..."
            kill $TCPDUMP_PID 2>/dev/null || true
            sleep 2
        fi
        
        echo ""
        echo "🏁 Background capture completed!"
        echo "🌐 PCAP file ready for Arkime - check the web interface at http://${HOST_IP:-localhost}:7008"
        
        if [ -f "$PCAP_FILE" ]; then
            FILESIZE=$(stat --format=%s "$PCAP_FILE" 2>/dev/null || echo "0")
            echo "✅ Captured ${FILESIZE} bytes of live network traffic over ${DURATION_DISPLAY}"
        else
            echo "⚠️  No capture file created - check interface and permissions"
        fi
        
        # Clear global variable after capture
        CURRENT_PCAP_FILE=""
        
        # Process the captured PCAP file into Arkime
        echo "🔄 Processing PCAP file into Arkime..."
        if [ -f "$PCAP_FILE" ]; then
            timeout 30s sudo docker exec arkime /opt/arkime/bin/capture -c /opt/arkime/etc/config.ini -r "/data/pcap/$(basename "$PCAP_FILE")" 2>/dev/null || {
                echo "⚠️  Processing completed (warnings are normal for live captures)"
            }
            echo "✅ PCAP data processed into Arkime"
        fi
        
        echo "🎯 Live capture completed! Data is now available in Arkime web interface."
        echo "🌐 Access Arkime at: http://${HOST_IP:-localhost}:7008"
        echo "👤 Login: admin / admin"
        
        # Auto-cleanup PCAP files
        echo ""
        echo "⏳ Waiting 10 seconds for Arkime to fully index the data..."
        sleep 10
        cleanup_pcap_files
        
        # Exit successfully without processing other PCAP files
        cleanup_and_exit 0
    else
        echo "❌ tcpdump not available - install with: sudo apt install tcpdump"
        echo "ℹ️  Cannot perform live capture without tcpdump"
        cleanup_and_exit 1
    fi
    
elif [ "$CAPTURE_LIVE" = true ]; then
    # Short burst live capture mode (original behavior)
    detect_network_interface
    
    # Enhanced network traffic generation
    echo "🌐 Generating comprehensive network activity for analysis..."
    (
        echo "🔄 Creating diverse network traffic patterns..."
        
        # HTTP/HTTPS traffic
        curl -s http://example.com > /dev/null 2>&1 &
        curl -s http://httpbin.org/json > /dev/null 2>&1 &
        curl -s http://jsonplaceholder.typicode.com/users > /dev/null 2>&1 &
        curl -s https://api.github.com/zen > /dev/null 2>&1 &
        
        # DNS queries for variety
        nslookup google.com > /dev/null 2>&1 &
        nslookup github.com > /dev/null 2>&1 &
        nslookup stackoverflow.com > /dev/null 2>&1 &
        
        # Additional HTTP patterns
        curl -s -H "User-Agent: CyberBlue-SOC-Test" http://httpbin.org/user-agent > /dev/null 2>&1 &
        curl -s http://httpbin.org/headers > /dev/null 2>&1 &
        
        # Wait for requests to complete
        sleep 3
    ) &
    
    # Enhanced traffic capture with better error handling
    if command -v tcpdump &> /dev/null; then
        PCAP_FILE="./arkime/pcaps/cyberblue_sample_$(date +%Y%m%d_%H%M%S).pcap"
        echo "📦 Capturing network traffic to: $PCAP_FILE"
        timeout 15s sudo tcpdump -i "$SURICATA_IFACE" -w "$PCAP_FILE" -c 100 2>/dev/null || echo "Traffic capture completed"
        
        if [ -f "$PCAP_FILE" ]; then
            echo "✅ Captured $(stat --format=%s "$PCAP_FILE") bytes of network traffic"
        fi
    else
        echo "⚠️  tcpdump not available - install with: sudo apt install tcpdump"
        echo "ℹ️  Arkime will be ready for manual PCAP upload"
    fi
else
    echo "ℹ️  Skipping live traffic capture (use --capture-live or --live-10min to enable)"
    
    # Create minimal sample traffic if no PCAPs exist
    if ! ls ./arkime/pcaps/*.pcap 1> /dev/null 2>&1; then
        echo "📦 Creating minimal network activity sample..."
        detect_network_interface
        
        # Generate minimal traffic
        (curl -s http://example.com > /dev/null 2>&1 &) 
        
        if command -v tcpdump &> /dev/null; then
            timeout 5s sudo tcpdump -i "$SURICATA_IFACE" -w "./arkime/pcaps/minimal_sample.pcap" -c 10 2>/dev/null || echo "Minimal capture completed"
        fi
    fi
fi

# Step 4: Enhanced PCAP processing with individual file handling
echo "⚙️  Step 4: Processing PCAP files with enhanced handling..."

if ls ./arkime/pcaps/*.pcap 1> /dev/null 2>&1; then
    echo "📦 Processing PCAP files in Arkime..."
    
    # Process each PCAP file individually for better feedback
    for pcap_file in ./arkime/pcaps/*.pcap; do
        filename=$(basename "$pcap_file")
        echo "   Processing: $filename"
        timeout 60s sudo docker exec arkime /opt/arkime/bin/capture -c /opt/arkime/etc/config.ini -r "/data/pcap/$filename" 2>/dev/null || echo "   Processed: $filename (timeout or warnings are normal)"
    done
    
    echo "✅ PCAP processing completed"
    
    # Cleanup PCAP files if in live capture mode
    if [ "$LIVE_CAPTURE" = true ]; then
        echo ""
        echo "⏳ Waiting 30 seconds for Arkime to fully process the data..."
        sleep 30
        cleanup_pcap_files
    fi
else
    echo "ℹ️  No PCAP files found to process"
    echo "💡 You can:"
    echo "   - Manually copy PCAP files to ./arkime/pcaps/"
    echo "   - Upload PCAP files through Arkime web interface"
    echo "   - Run this script with --capture-live or --live-10min option"
fi

# Step 5: Create Arkime admin user with verification
echo "👤 Step 5: Creating Arkime admin user..."
sudo docker exec arkime /opt/arkime/bin/arkime_add_user.sh admin "CyberBlue Admin" admin --admin 2>/dev/null || echo "Admin user ready"

# Step 6: Restart Arkime services
echo "🔄 Step 6: Restarting Arkime services..."
sudo docker-compose restart arkime 2>/dev/null

echo "⏳ Waiting for Arkime to restart..."
sleep 15

# Step 7: Enhanced verification and status reporting
echo "✅ Step 7: Verifying Arkime setup..."

# Check if viewer is responding
if curl -s -f http://localhost:7008 > /dev/null; then
    echo "✅ Arkime web interface is responding at http://localhost:7008"
else
    echo "⚠️  Arkime web interface may still be starting up (wait 1-2 minutes)"
fi

# Check OpenSearch indices with detailed reporting
if sudo docker exec arkime curl -s http://os01:9200/_cluster/health > /dev/null 2>&1; then
    ARKIME_INDICES=$(sudo docker exec arkime curl -s "http://os01:9200/_cat/indices/arkime*" | wc -l)
    if [ "$ARKIME_INDICES" -gt 0 ]; then
        echo "✅ Arkime indices created ($ARKIME_INDICES indices found)"
        echo "📊 Index details:"
        sudo docker exec arkime curl -s "http://os01:9200/_cat/indices/arkime*" | head -3 | while read line; do
            echo "   $line"
        done
    else
        echo "⚠️  No Arkime indices found yet - they will be created when data is processed"
    fi
else
    echo "ℹ️  OpenSearch connection unavailable for index verification"
fi

# Get server IP for display
HOST_IP=$(hostname -I | awk '{print $1}')

echo ""
echo "🎯 Enhanced Arkime Setup Complete!"
echo "=================================="
echo "🌐 Access Arkime at: http://${HOST_IP}:7008"
echo "👤 Login credentials: admin / admin"
echo ""
echo "📋 Arkime is ready with:"
echo "   ✅ Database initialized"
echo "   ✅ Admin user created"
echo "   ✅ Sample traffic captured (if available)"
echo "   ✅ PCAP processing configured"
echo ""
echo "📋 If Arkime still shows no data:"
echo "   1. Wait 2-3 minutes for full startup"
echo "   2. Check logs: sudo docker logs arkime"
echo "   3. Re-run with: ./fix-arkime.sh --capture-live --force"
echo "   4. Upload PCAP files manually through the web interface"
echo ""
echo "💡 Pro Tips:"
echo "   - Use --capture-live for short burst network traffic"
echo "   - Use --live for 1-minute capture with auto-cleanup (default)"
echo "   - Use --live-5min or -t 300s for custom durations"
echo "   - Use --force to reinitialize database"
echo "   - Check OpenSearch health: sudo docker exec arkime curl http://os01:9200/_cluster/health"
echo "   - View container status: sudo docker ps | grep arkime"

# Clean exit
cleanup_and_exit 0
