#!/bin/bash

# ============================================================================
# CyberBlue Force Start Script
# ============================================================================
# This script performs a complete Docker restart and brings up all services.
# Use this when containers are stuck or Docker networking has issues.
#
# Usage: ./force-start.sh [OPTIONS]
# Options:
#   --help    Show this help message
# ============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --help)
            echo -e "${BLUE}CyberBlue Force Start Script${NC}"
            echo "============================================"
            echo ""
            echo "This script performs a complete Docker restart and brings up all CyberBlue services."
            echo ""
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --help    Show this help message"
            echo ""
            echo "What this script does:"
            echo "  1. Restart Docker daemon"
            echo "  2. Wait for Docker to be ready"
            echo "  3. Start all CyberBlue services with docker-compose"
            echo ""
            echo "⚠️  Warning: This will temporarily stop all running containers"
            echo "✅ Use this when containers are stuck or networking has issues"
            exit 0
            ;;
        *)
            echo -e "${RED}❌ Unknown option: $1${NC}"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

echo -e "${BLUE}🚀 CyberBlue Force Start Script${NC}"
echo "============================================"
echo ""

# Check if we're in the right directory
if [ ! -f "docker-compose.yml" ]; then
    echo -e "${RED}❌ Error: docker-compose.yml not found${NC}"
    echo "Please run this script from the CyberBlue directory"
    exit 1
fi

echo -e "${YELLOW}⚠️  WARNING: This will restart Docker and temporarily stop all containers${NC}"
echo ""
echo -e "${CYAN}ℹ️  Running in non-interactive mode - proceeding automatically...${NC}"
echo ""

echo -e "${BLUE}🔄 Step 1: Restarting Docker daemon...${NC}"
echo "   This will stop all running containers temporarily"
if sudo systemctl restart docker; then
    echo -e "${GREEN}✅ Docker daemon restarted successfully${NC}"
else
    echo -e "${RED}❌ Failed to restart Docker daemon${NC}"
    exit 1
fi

echo ""
echo -e "${BLUE}⏳ Step 2: Waiting for Docker to be ready...${NC}"
echo "   Waiting up to 30 seconds for Docker daemon to initialize"

# Wait for Docker to be ready
WAIT_TIME=0
MAX_WAIT=30
while [ $WAIT_TIME -lt $MAX_WAIT ]; do
    if sudo docker info >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Docker daemon is ready${NC}"
        break
    fi
    sleep 2
    WAIT_TIME=$((WAIT_TIME + 2))
    echo "   Waiting... (${WAIT_TIME}s elapsed)"
done

if [ $WAIT_TIME -ge $MAX_WAIT ]; then
    echo -e "${RED}❌ Docker daemon failed to start within ${MAX_WAIT} seconds${NC}"
    exit 1
fi

echo ""
echo -e "${BLUE}🚀 Step 3: Starting all CyberBlue services...${NC}"
echo "   This may take 2-5 minutes to bring up all 30+ containers"
echo ""

# Start all services with docker-compose
if sudo docker compose up -d; then
    echo ""
    echo -e "${GREEN}✅ All CyberBlue services started successfully${NC}"
else
    echo ""
    echo -e "${RED}❌ Failed to start some services${NC}"
    echo "Check the output above for errors"
    exit 1
fi

echo ""
echo -e "${BLUE}⏳ Step 4: Waiting for services to initialize...${NC}"
echo "   Allowing 30 seconds for containers to fully start"
sleep 30

echo ""
echo -e "${BLUE}🔍 Step 5: Verifying deployment...${NC}"

# Count running containers
RUNNING_CONTAINERS=$(sudo docker ps --format "table {{.Names}}" | grep -v NAMES | wc -l 2>/dev/null || echo "0")
echo "   Running containers: $RUNNING_CONTAINERS"

if [ "$RUNNING_CONTAINERS" -ge 25 ]; then
    echo -e "${GREEN}✅ Force start completed successfully!${NC}"
    DEPLOYMENT_STATUS="SUCCESS"
else
    echo -e "${YELLOW}⚠️  Force start completed with warnings${NC}"
    echo "   Some containers may still be starting up"
    DEPLOYMENT_STATUS="PARTIAL"
fi

echo ""
echo -e "${GREEN}🎉 CyberBlue Force Start Complete!${NC}"
echo "============================================"
echo ""
echo "📊 Final Status:"
echo "   • Deployment: $DEPLOYMENT_STATUS"
echo "   • Running Containers: $RUNNING_CONTAINERS"
echo "   • Docker Status: ✅ Healthy"
echo ""
echo "🌐 Access Your CyberBlue Portal:"
echo "   🔒 HTTPS: https://$(hostname -I | awk '{print $1}'):5443"
echo "   🔑 Login: admin / cyberblue123"
echo ""
echo "🛡️  Individual Tools:"
echo "   • Wazuh: http://$(hostname -I | awk '{print $1}'):7001"
echo "   • MISP: https://$(hostname -I | awk '{print $1}'):7003"
echo "   • Arkime: http://$(hostname -I | awk '{print $1}'):7008"
echo "   • Caldera: http://$(hostname -I | awk '{print $1}'):7009"
echo "   • OpenVAS: http://$(hostname -I | awk '{print $1}'):7014"
echo "   • ...and many more on ports 7000-7099!"
echo ""
echo -e "${CYAN}💡 Tip: Use the portal to manage all services from one interface${NC}"
echo ""
