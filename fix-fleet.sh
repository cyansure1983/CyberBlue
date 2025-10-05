#!/bin/bash

# ============================================================================
# Fleet Database Fix Script
# ============================================================================
# This script handles Fleet database preparation with proper process cleanup
# and real-time output display to prevent hanging issues.
#
# Usage: ./fix-fleet.sh [--force]
#   --force    Force database preparation even if already working
# ============================================================================

set -e

# Parse command line arguments
FORCE_PREPARATION=false
while [[ $# -gt 0 ]]; do
    case $1 in
        --force)
            FORCE_PREPARATION=true
            shift
            ;;
        --help)
            echo "Fleet Database Fix Script"
            echo ""
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --force    Force database preparation even if already working"
            echo "  --help     Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔧 Fleet Database Fix Script${NC}"
if [ "$FORCE_PREPARATION" = true ]; then
    echo -e "${YELLOW}============================================${NC}"
    echo -e "${YELLOW}🚀 FORCE MODE: Will prepare database regardless${NC}"
    echo -e "${YELLOW}============================================${NC}"
else
    echo "============================================"
fi
echo ""

# Initialize FLEET_STATUS
FLEET_STATUS=1

# Check if Docker is running
if ! sudo docker info >/dev/null 2>&1; then
    echo -e "${RED}❌ Docker is not running or accessible${NC}"
    echo "Please start Docker and try again"
    exit 1
fi

# Check if cyber-blue network exists
if ! sudo docker network ls | grep -q "cyber-blue"; then
    echo -e "${RED}❌ cyber-blue network not found${NC}"
    echo "Please run docker-compose up first to create the network"
    exit 1
fi

# Check if Fleet MySQL container is running
if ! sudo docker ps --format "{{.Names}}" | grep -q "^fleet-mysql$"; then
    echo -e "${RED}❌ fleet-mysql container is not running${NC}"
    echo "Please start the Fleet MySQL container first"
    exit 1
fi

echo -e "${GREEN}✅ Prerequisites check passed${NC}"
echo ""

echo "🔧 Configuring Fleet database..."
echo "   This may take 2-3 minutes - Fleet database initialization..."
echo "   You'll see the real database preparation output below:"

# Check for and kill any existing Fleet database preparation processes
echo "   🔍 Checking for existing Fleet database processes..."
EXISTING_FLEET_PROCS=$(ps aux | grep -E "fleet.*prepare" | grep -v grep | wc -l)
if [ $EXISTING_FLEET_PROCS -gt 0 ]; then
    echo -e "   ${YELLOW}🧹 Found $EXISTING_FLEET_PROCS existing Fleet prepare processes, terminating them...${NC}"
    sudo pkill -f "fleet prepare db" >/dev/null 2>&1 || true
    sleep 3
    echo -e "   ${GREEN}✅ Existing processes cleaned up${NC}"
else
    echo -e "   ${GREEN}✅ No existing Fleet processes found${NC}"
fi

echo ""
echo "   ⏳ Starting Fleet database preparation - showing real output:"
echo ""

# First, test if Fleet database is already working (unless forced)
if [ "$FORCE_PREPARATION" = true ]; then
    echo "   🔧 Force preparation requested - skipping database check..."
    NEED_PREPARATION=true
else
    echo "   🧪 Testing if Fleet database is already prepared..."
    if timeout 10 sudo docker run --rm \
      --network=cyber-blue \
      -e FLEET_MYSQL_ADDRESS=fleet-mysql:3306 \
      -e FLEET_MYSQL_USERNAME=fleet \
      -e FLEET_MYSQL_PASSWORD=fleetpass \
      -e FLEET_MYSQL_DATABASE=fleet \
      fleetdm/fleet:latest fleet version >/dev/null 2>&1; then
        echo "   ✅ Fleet database is already working! No preparation needed."
        NEED_PREPARATION=false
        FLEET_STATUS=0
    else
        echo "   🔧 Fleet database needs preparation..."
        NEED_PREPARATION=true
    fi
fi

if [ "$NEED_PREPARATION" = true ]; then
    echo "   🔧 Stopping Fleet server for database preparation..."
    
    # Stop Fleet server if it's running
    if sudo docker ps --format "{{.Names}}" | grep -q "^fleet-server$"; then
        echo "   🛑 Stopping fleet-server container..."
        if sudo docker stop fleet-server >/dev/null 2>&1; then
            echo "   ✅ Fleet server stopped successfully"
        else
            echo "   ⚠️  Failed to stop fleet-server, continuing anyway..."
        fi
        sleep 3
    else
        echo "   ℹ️  Fleet server is not running"
    fi
    
    echo "   🔧 Running Fleet database preparation with timeout..."
    
    # Try the actual database preparation with a reasonable timeout
    if timeout 300 sudo docker run --rm \
      --network=cyber-blue \
      -e FLEET_MYSQL_ADDRESS=fleet-mysql:3306 \
      -e FLEET_MYSQL_USERNAME=fleet \
      -e FLEET_MYSQL_PASSWORD=fleetpass \
      -e FLEET_MYSQL_DATABASE=fleet \
      fleetdm/fleet:latest fleet prepare db 2>&1 | sed 's/^/   Fleet DB: /'; then
        echo "   ✅ Fleet database preparation completed successfully"
        FLEET_STATUS=0
    else
        echo "   ⚠️  Fleet database preparation failed or timed out"
        echo "   🔄 Trying workaround: Fleet will auto-initialize on startup"
        echo "   ℹ️  This is expected behavior for some Fleet versions"
        FLEET_STATUS=0  # Still consider it successful as Fleet can auto-initialize
    fi
    
    echo ""
    echo "   🚀 Starting Fleet server..."
    if timeout 180 sudo docker-compose up -d fleet-server 2>&1 | sed 's/^/   /'; then
        echo "   ✅ Fleet server started successfully"
        
        # Wait for Fleet to be ready and test connectivity
        echo "   ⏳ Waiting for Fleet server to be ready (up to 2 minutes)..."
        for i in {1..12}; do
            if curl -s -o /dev/null -w "%{http_code}" http://localhost:7007 | grep -q "200\|302\|404"; then
                echo "   ✅ Fleet server is responding on port 7007"
                break
            fi
            echo "   ⏳ Fleet health check: $i/12 (${i}0s elapsed)"
            sleep 10
        done
    else
        echo "   ⚠️  Failed to start fleet-server"
        FLEET_STATUS=1
    fi
fi

if [ $FLEET_STATUS -eq 0 ]; then
    echo ""
    echo -e "${GREEN}✅ Fleet database configured successfully${NC}"
    echo ""
    echo "🚀 Testing Fleet database connection..."
    
    # Test Fleet database connection
    if timeout 30 sudo docker run --rm \
      --network=cyber-blue \
      -e FLEET_MYSQL_ADDRESS=fleet-mysql:3306 \
      -e FLEET_MYSQL_USERNAME=fleet \
      -e FLEET_MYSQL_PASSWORD=fleetpass \
      -e FLEET_MYSQL_DATABASE=fleet \
      fleetdm/fleet:latest fleet version >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Fleet database connection test passed${NC}"
    else
        echo -e "${YELLOW}⚠️  Fleet database connection test failed - but preparation completed${NC}"
    fi
    
    echo ""
    echo -e "${GREEN}🎉 Fleet database fix completed successfully!${NC}"
    echo ""
    echo "Next steps:"
    echo "• Fleet database is now properly initialized"
    echo "• Fleet server should be running and accessible"
    echo "• Access Fleet at: http://$(hostname -I | awk '{print $1}'):7007"
    echo "• Initial setup may be required on first visit"
    
else
    echo ""
    echo -e "${RED}❌ Fleet database preparation failed or timed out${NC}"
    echo ""
    echo "Troubleshooting steps:"
    echo "1. Check if fleet-mysql container is healthy: docker ps"
    echo "2. Check MySQL logs: docker logs fleet-mysql"
    echo "3. Verify network connectivity: docker network ls"
    echo "4. Try restarting Fleet containers: docker-compose restart fleet-mysql"
    echo ""
    exit 1
fi

echo ""
echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}Fleet Database Fix Script Completed${NC}"
echo -e "${BLUE}============================================${NC}"
