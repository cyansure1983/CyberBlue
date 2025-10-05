#!/bin/bash

# Post-Reboot Verification Script for CyberBlue SOC
# This script verifies all services are running properly after system reboot

set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() { echo -e "${GREEN}✅${NC} $1"; }
print_error() { echo -e "${RED}❌${NC} $1"; }
print_warning() { echo -e "${YELLOW}⚠️${NC} $1"; }
print_info() { echo -e "${BLUE}ℹ️${NC} $1"; }

echo "🔍 CyberBlue SOC Post-Reboot Verification"
echo "========================================"
echo ""

# Wait for system to stabilize
echo "⏳ Waiting 30 seconds for system to stabilize..."
sleep 30

# 1. Check SystemD Services
echo "📋 Checking SystemD Services..."
services=("docker" "cyberblue-soc" "netfilter-persistent" "caldera-autostart")
for service in "${services[@]}"; do
    if sudo systemctl is-active --quiet "$service"; then
        print_status "$service service is running"
    else
        print_error "$service service is not running"
        echo "   Attempting to start..."
        sudo systemctl start "$service"
    fi
done
echo ""

# 2. Check Docker Containers
echo "🐳 Checking Docker Containers..."
echo "   Waiting for containers to start..."
sleep 60  # Give containers time to start

EXPECTED_CONTAINERS=30  # Total number of expected containers
RUNNING_CONTAINERS=$(sudo docker ps -q | wc -l)

echo "   Running containers: $RUNNING_CONTAINERS"
if [ "$RUNNING_CONTAINERS" -ge "$EXPECTED_CONTAINERS" ]; then
    print_status "All containers running ($RUNNING_CONTAINERS)"
elif [ "$RUNNING_CONTAINERS" -ge 25 ]; then
    print_status "Most containers running ($RUNNING_CONTAINERS/$EXPECTED_CONTAINERS)"
else
    print_warning "Only $RUNNING_CONTAINERS containers running (expected $EXPECTED_CONTAINERS)"
    echo "   This is normal during startup - containers may still be initializing"
fi

# Check ALL services that should be running
echo ""
echo "🎯 Checking ALL CyberBlue SOC Services..."
all_services=(
    "arkime" "caldera" "cortex" "cyber-blue-portal" "cyberchef" 
    "elasticsearch" "evebox" "fleet-mysql" "fleet-redis" "fleet-server"
    "misp-core" "misp-db" "misp-mail" "misp-modules" "misp-redis"
    "mitre-navigator" "openvas" "os01" "portainer" "shuffle-backend"
    "shuffle-frontend" "shuffle-opensearch" "shuffle-orborus" "suricata"
    "thehive" "velociraptor" "wazuh-dashboard" "wazuh-indexer" "wazuh-manager" "wireshark"
)

running_count=0
total_count=${#all_services[@]}

for service in "${all_services[@]}"; do
    if sudo docker ps | grep -q "$service"; then
        status=$(sudo docker ps --filter "name=$service" --format "{{.Status}}" | head -1)
        print_status "$service: $status"
        ((running_count++))
    else
        print_error "$service: Not running"
    fi
done

echo ""
echo "📊 Service Summary: $running_count/$total_count services running"
echo ""

# 3. Check Network Configuration
echo "🌐 Checking Network Configuration..."
PRIMARY_INTERFACE=$(ip route | grep default | awk '{print $5}' | head -1)
print_info "Primary interface: $PRIMARY_INTERFACE"

FORWARD_POLICY=$(sudo iptables -L FORWARD | head -1 | grep -oP '(?<=policy )[A-Z]+')
if [ "$FORWARD_POLICY" = "ACCEPT" ]; then
    print_status "FORWARD policy: $FORWARD_POLICY"
else
    print_error "FORWARD policy: $FORWARD_POLICY (should be ACCEPT)"
fi

# Check if Docker NAT rules exist
NAT_RULES=$(sudo iptables -t nat -L DOCKER -n | grep DNAT | wc -l)
if [ "$NAT_RULES" -gt 0 ]; then
    print_status "Docker NAT rules: $NAT_RULES rules active"
else
    print_error "Docker NAT rules: No rules found"
fi
echo ""

# 4. Test Service Accessibility
echo "🔌 Testing Service Accessibility..."
SERVER_IP=$(ip -4 addr show "$PRIMARY_INTERFACE" | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1)
print_info "Testing on server IP: $SERVER_IP"

# Test ALL external ports
test_ports=(5443 5500 7000 7001 7002 7003 7004 7005 7006 7007 7008 7009 7013 7014 7015 8000 9200 9210 9300 9443)
accessible_count=0

echo "   Testing all external ports..."
for port in "${test_ports[@]}"; do
    if timeout 3 bash -c "</dev/tcp/$SERVER_IP/$port" >/dev/null 2>&1; then
        print_status "Port $port: Accessible"
        ((accessible_count++))
    else
        print_warning "Port $port: Not responding"
    fi
done

echo ""
echo "📊 Port Summary: $accessible_count/${#test_ports[@]} ports accessible"
echo ""

# 5. Show Access URLs
echo "🌐 Complete Service Access URLs:"
echo "   🏠 Portal:          https://$SERVER_IP:5443 (admin / cyberblue123)"
echo "   🔒 MISP:            https://$SERVER_IP:7003 (admin@admin.test / admin)"
echo "   🛡️  Wazuh:           http://$SERVER_IP:7001 (admin / cyberblue)"
echo "   📊 Arkime:          http://$SERVER_IP:7008 (admin / admin)"
echo "   🧠 Caldera:         http://$SERVER_IP:7009 (admin / cyberblue)"
echo "   🕷️  TheHive:         http://$SERVER_IP:7005 (admin / cyberblue)"
echo "   🔧 Fleet:           http://$SERVER_IP:7007 (admin / cyberblue)"
echo "   🧪 CyberChef:       http://$SERVER_IP:7004"
echo "   🔗 Shuffle:         http://$SERVER_IP:7002 (admin / cyberblue)"
echo "   🖥️  Portainer:       http://$SERVER_IP:9443 (admin / cyberblue)"
echo "   🔍 EveBox:          http://$SERVER_IP:7015"
echo "   🛡️  OpenVAS:        http://$SERVER_IP:7014"
echo "   🗺️  MITRE Navigator: http://$SERVER_IP:7013"
echo "   🦕 Velociraptor:    http://$SERVER_IP:7000"
echo ""

# 6. Final Status
if [ "$accessible_count" -ge 4 ] && [ "$RUNNING_CONTAINERS" -ge 20 ]; then
    print_status "🎉 CyberBlue SOC post-reboot verification PASSED!"
    print_info "All critical services should be accessible within 2-3 minutes"
else
    print_warning "⏳ System is still starting up - wait 2-3 minutes and run this script again"
fi

echo ""
echo "💡 If services are not accessible:"
echo "   1. Wait 5 minutes for full startup"
echo "   2. Run: sudo docker ps (check container status)"
echo "   3. Run: sudo systemctl status cyberblue-soc"
echo "   4. Run: ./fix-docker-external-access.sh --apply-only"
echo ""
