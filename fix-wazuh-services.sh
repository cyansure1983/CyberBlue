#!/bin/bash

# ============================================================================
# CyberBlue SOC - Complete Wazuh Services Fix
# ============================================================================
# This script completely fixes all Wazuh SSL certificate issues and ensures
# all Wazuh components (indexer, manager, dashboard) start properly.
# ============================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging functions
log() {
    echo -e "${GREEN}[$(date +'%H:%M:%S')] ✅ $1${NC}"
}

log_info() {
    echo -e "${CYAN}[$(date +'%H:%M:%S')] ℹ️  $1${NC}"
}

log_warn() {
    echo -e "${YELLOW}[$(date +'%H:%M:%S')] ⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}[$(date +'%H:%M:%S')] ❌ $1${NC}"
}

echo -e "${BLUE}"
echo "🔧 =================================="
echo "   Complete Wazuh Services Fix"
echo "🔧 =================================="
echo -e "${NC}"

# Step 1: Complete cleanup of Wazuh components
log_info "Step 1: Stopping and removing all Wazuh components..."
sudo docker stop wazuh-indexer wazuh-dashboard wazuh-manager wazuh-cert-genrator 2>/dev/null || true
sudo docker rm wazuh-indexer wazuh-dashboard wazuh-manager wazuh-cert-genrator 2>/dev/null || true
log "All Wazuh containers stopped and removed"

# Step 2: Complete SSL certificate cleanup
log_info "Step 2: Completely cleaning SSL certificate directory..."
sudo rm -rf wazuh/config/wazuh_indexer_ssl_certs
sudo mkdir -p wazuh/config/wazuh_indexer_ssl_certs
sudo chown -R $(whoami):$(id -gn) wazuh/config/wazuh_indexer_ssl_certs
sudo chmod 755 wazuh/config/wazuh_indexer_ssl_certs
log "SSL certificate directory cleaned and recreated"

# Step 3: Remove any cached certificate volumes
log_info "Step 3: Cleaning Docker volumes for fresh certificate generation..."
sudo docker volume rm $(sudo docker volume ls -q | grep -E "(wazuh|cert)") 2>/dev/null || true
log "Docker volumes cleaned"

# Function to run Docker Compose (handles both v1 and v2)
docker_compose() {
    if command -v docker-compose >/dev/null 2>&1; then
        sudo docker-compose "$@"
    else
        sudo docker compose "$@"
    fi
}

# Step 4: Generate fresh certificates
log_info "Step 4: Generating fresh SSL certificates..."
docker_compose up -d generator
log_info "Waiting for certificate generation to complete (30 seconds)..."
sleep 30

# Check if certificates were generated
if [[ -f "wazuh/config/wazuh_indexer_ssl_certs/admin.pem" ]]; then
    log "SSL certificates generated successfully"
else
    log_error "Certificate generation failed"
    sudo docker logs wazuh-cert-genrator --tail 20
    exit 1
fi

# Step 5: Fix certificate permissions and ownership
log_info "Step 5: Fixing certificate permissions and ownership..."
sudo chown -R $(whoami):$(id -gn) wazuh/config/wazuh_indexer_ssl_certs/
sudo chmod 644 wazuh/config/wazuh_indexer_ssl_certs/*.pem
sudo chmod 644 wazuh/config/wazuh_indexer_ssl_certs/*.key 2>/dev/null || true

# Remove any directory artifacts that might have been created
sudo find wazuh/config/wazuh_indexer_ssl_certs -type d -name "*.pem" -exec rm -rf {} \; 2>/dev/null || true
sudo find wazuh/config/wazuh_indexer_ssl_certs -type d -name "*.key" -exec rm -rf {} \; 2>/dev/null || true
log "Certificate permissions fixed"

# Step 6: Start Wazuh services in proper order with health checks
log_info "Step 6: Starting Wazuh services in proper order..."

# Start indexer first
log_info "Starting Wazuh Indexer..."
docker_compose up -d wazuh.indexer
log_info "Waiting for Wazuh Indexer to initialize (45 seconds)..."
sleep 45

# Check indexer health
if curl -s -k -u admin:SecretPassword https://localhost:9200/_cluster/health >/dev/null 2>&1; then
    log "Wazuh Indexer is healthy"
else
    log_warn "Wazuh Indexer health check failed, but continuing..."
fi

# Start manager
log_info "Starting Wazuh Manager..."
docker_compose up -d wazuh.manager
log_info "Waiting for Wazuh Manager to initialize (30 seconds)..."
sleep 30

# Check manager health
if sudo docker ps | grep -q "wazuh-manager.*Up"; then
    log "Wazuh Manager is running"
else
    log_warn "Wazuh Manager may have issues, checking logs..."
    sudo docker logs wazuh-manager --tail 10
fi

# Start dashboard
log_info "Starting Wazuh Dashboard..."
docker_compose up -d wazuh.dashboard
log_info "Waiting for Wazuh Dashboard to initialize (45 seconds)..."
sleep 45

# Check dashboard health
if curl -s http://localhost:7001 >/dev/null 2>&1; then
    log "Wazuh Dashboard is accessible"
else
    log_warn "Wazuh Dashboard health check failed, but may still be starting..."
fi

# Step 7: Final verification
log_info "Step 7: Final verification of all Wazuh services..."
echo ""
echo -e "${BLUE}🔍 Wazuh Services Status:${NC}"
sudo docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep wazuh

# Count running Wazuh services
WAZUH_RUNNING=$(sudo docker ps | grep -c "wazuh.*Up" || echo "0")
echo ""
if [[ "$WAZUH_RUNNING" -eq 3 ]]; then
    log "All 3 Wazuh services are running successfully!"
    echo -e "${GREEN}✅ Wazuh Dashboard: http://$(hostname -I | awk '{print $1}'):7001${NC}"
    echo -e "${GREEN}✅ Credentials: admin / SecretPassword${NC}"
elif [[ "$WAZUH_RUNNING" -eq 2 ]]; then
    log_warn "2/3 Wazuh services are running (may need more time)"
elif [[ "$WAZUH_RUNNING" -eq 1 ]]; then
    log_warn "1/3 Wazuh services are running (check logs for issues)"
else
    log_error "No Wazuh services are running properly"
    echo "Check logs with: sudo docker logs [wazuh-container-name]"
    exit 1
fi

# Step 8: Restart certificate generator to clean state
log_info "Step 8: Cleaning up certificate generator..."
sudo docker stop wazuh-cert-genrator 2>/dev/null || true

echo ""
echo -e "${GREEN}🎉 =================================="
echo "   Wazuh Services Fix Complete!"
echo "🎉 ==================================${NC}"
echo ""
echo -e "${CYAN}📊 Total Running Services:${NC}"
TOTAL_RUNNING=$(sudo docker ps | grep -c "Up" || echo "0")
echo "   Running containers: $TOTAL_RUNNING"
echo ""
echo -e "${CYAN}🌐 Next Steps:${NC}"
echo "1. Check CyberBlue Portal: https://$(hostname -I | awk '{print $1}'):5443"
echo "2. Should now show 15/15 services running"
echo "3. Access Wazuh at: http://$(hostname -I | awk '{print $1}'):7001"
echo ""
