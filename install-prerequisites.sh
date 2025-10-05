#!/bin/bash

# ============================================================================
# CyberBlue SOC - Prerequisites Installation Script
# ============================================================================
# This script installs all required prerequisites for CyberBlue SOC platform
# including Docker, Docker Compose, and system optimizations.
#
# Usage: ./install-prerequisites.sh [OPTIONS]
# Options:
#   --skip-updates    Skip system updates (faster, but not recommended)
#   --force           Skip confirmation prompts
#   --help            Show this help message
# ============================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
SKIP_UPDATES=false
FORCE=false

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --skip-updates)
                SKIP_UPDATES=true
                shift
                ;;
            --force)
                FORCE=true
                shift
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                echo -e "${RED}❌ Unknown option: $1${NC}"
                show_help
                exit 1
                ;;
        esac
    done
}

show_help() {
    echo -e "${BLUE}🚀 CyberBlue SOC - Prerequisites Installation Script${NC}"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --skip-updates    Skip system updates (faster, but not recommended)"
    echo "  --force           Skip confirmation prompts"
    echo "  --help            Show this help message"
    echo ""
    echo "This script installs:"
    echo "  🐳 Docker CE (latest)"
    echo "  📦 Docker Compose (latest)"
    echo "  ⚙️  System optimizations"
    echo "  🌐 Network configurations"
    echo "  🔧 User permissions"
}

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

# Check if running as root
check_permissions() {
    if [[ $EUID -eq 0 ]]; then
        log_error "Do not run this script as root. It will use sudo when needed."
        exit 1
    fi
}

# Check OS compatibility
check_os() {
    if [[ ! -f /etc/os-release ]]; then
        log_error "Cannot determine OS version. This script supports Ubuntu 20.04+ and Debian-based systems."
        exit 1
    fi
    
    . /etc/os-release
    
    if [[ "$ID" != "ubuntu" ]] && [[ "$ID" != "debian" ]]; then
        log_error "This script supports Ubuntu and Debian-based systems only. Detected: $ID"
        exit 1
    fi
    
    log_info "Detected OS: $PRETTY_NAME"
}

# Confirmation prompt
confirm_installation() {
    if [[ "$FORCE" == "true" ]]; then
        return 0
    fi

    echo -e "${YELLOW}🚀 CyberBlue SOC Prerequisites Installation${NC}"
    echo ""
    echo "This script will install and configure:"
    echo "  🐳 Docker CE (latest stable)"
    echo "  📦 Docker Compose (latest)"
    echo "  ⚙️  System optimizations (sysctl, limits)"
    echo "  🌐 Network configurations (iptables, Docker daemon)"
    echo "  👥 User permissions (Docker group)"
    echo ""
    echo "Estimated time: 5-10 minutes"
    echo "Internet connection required for downloads"
    echo ""
    
    read -p "Continue with installation? (y/N): " -r
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${GREEN}✅ Installation cancelled.${NC}"
        exit 0
    fi
}

# Check if Docker is already installed
check_docker_installed() {
    if command -v docker >/dev/null 2>&1 && command -v docker-compose >/dev/null 2>&1; then
        local docker_version=$(docker --version 2>/dev/null || echo "unknown")
        local compose_version=$(docker-compose --version 2>/dev/null || echo "unknown")
        
        log_info "Docker already installed: $docker_version"
        log_info "Docker Compose already installed: $compose_version"
        
        if [[ "$FORCE" == "false" ]]; then
            read -p "Docker is already installed. Reinstall/update? (y/N): " -r
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                log_info "Skipping Docker installation"
                return 1
            fi
        fi
    fi
    return 0
}

# Function to handle apt lock conflicts
clear_apt_locks() {
    log_info "Checking for apt lock conflicts..."
    
    # Kill any stuck apt processes
    if pgrep -f "apt|dpkg" >/dev/null 2>&1; then
        log_info "Found running apt/dpkg processes, terminating them..."
        sudo pkill -f "apt" >/dev/null 2>&1 || true
        sudo pkill -f "dpkg" >/dev/null 2>&1 || true
        sudo pkill -f "unattended-upgrade" >/dev/null 2>&1 || true
        sleep 3
    fi
    
    # Remove lock files if they exist
    if [ -f /var/lib/dpkg/lock-frontend ] || [ -f /var/lib/dpkg/lock ] || [ -f /var/cache/apt/archives/lock ]; then
        log_info "Clearing apt lock files..."
        sudo rm -f /var/lib/dpkg/lock-frontend >/dev/null 2>&1 || true
        sudo rm -f /var/lib/dpkg/lock >/dev/null 2>&1 || true
        sudo rm -f /var/cache/apt/archives/lock >/dev/null 2>&1 || true
        sudo rm -f /var/lib/apt/lists/lock >/dev/null 2>&1 || true
    fi
    
    # Configure dpkg if needed
    sudo dpkg --configure -a >/dev/null 2>&1 || true
    
    log_info "Apt locks cleared, ready for package operations"
}

# System updates and basic packages
install_basic_packages() {
    # Clear any apt locks before starting
    clear_apt_locks
    
    if [[ "$SKIP_UPDATES" == "false" ]]; then
        log_info "Updating system packages..."
        timeout 300 sudo apt update || log_warn "apt update timed out"
        timeout 600 sudo DEBIAN_FRONTEND=noninteractive apt upgrade -y || log_warn "apt upgrade timed out"
        log "System updated successfully"
    else
        log_warn "Skipping system updates (--skip-updates specified)"
        timeout 300 sudo apt update || log_warn "apt update timed out"
    fi
    
    log_info "Installing basic packages..."
    DEBIAN_FRONTEND=noninteractive sudo apt install -y ca-certificates curl gnupg lsb-release git
    log "Basic packages installed"
}

# Install Docker
install_docker() {
    log_info "Installing Docker CE..."
    
    # Clear any apt locks before Docker installation
    clear_apt_locks
    
    # Add Docker's official GPG key
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg >/dev/null 2>&1
    
    # Add Docker repository
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Install Docker
    timeout 300 sudo apt update || log_warn "apt update timed out"
    timeout 600 sudo DEBIAN_FRONTEND=noninteractive apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin || {
        log_error "Docker installation failed or timed out"
        exit 1
    }
    
    log "Docker CE installed successfully"
}

# Install Docker Compose standalone
install_docker_compose() {
    log_info "Installing Docker Compose standalone..."
    
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose >/dev/null 2>&1
    sudo chmod +x /usr/local/bin/docker-compose
    
    log "Docker Compose installed successfully"
}

# Configure Docker permissions and service
configure_docker() {
    log_info "Configuring Docker permissions and service..."
    
    # Add user to Docker group
    sudo usermod -aG docker $USER
    
    # Set Docker socket permissions
    sudo chown root:docker /var/run/docker.sock
    sudo chmod 660 /var/run/docker.sock
    
    # Enable and start Docker service
    sudo systemctl enable docker >/dev/null 2>&1
    sudo systemctl start docker >/dev/null 2>&1
    
    log "Docker service configured and started"
}

# System optimizations
configure_system_optimizations() {
    log_info "Applying system optimizations for containers..."
    
    # Increase vm.max_map_count for Elasticsearch/OpenSearch
    if ! grep -q "vm.max_map_count=262144" /etc/sysctl.conf; then
        echo 'vm.max_map_count=262144' | sudo tee -a /etc/sysctl.conf >/dev/null
    fi
    sudo sysctl -p >/dev/null 2>&1
    
    # Increase file descriptor limits
    if ! grep -q "* soft nofile 65536" /etc/security/limits.conf; then
        echo '* soft nofile 65536' | sudo tee -a /etc/security/limits.conf >/dev/null
        echo '* hard nofile 65536' | sudo tee -a /etc/security/limits.conf >/dev/null
    fi
    
    log "System optimizations applied"
}

# Configure environment variables
configure_environment() {
    log_info "Setting up environment variables..."
    
    # Export for current session
    export DOCKER_BUILDKIT=1
    export COMPOSE_DOCKER_CLI_BUILD=1
    
    # Add to bashrc if not already present
    if ! grep -q "export DOCKER_BUILDKIT=1" ~/.bashrc; then
        echo 'export DOCKER_BUILDKIT=1' >> ~/.bashrc
        echo 'export COMPOSE_DOCKER_CLI_BUILD=1' >> ~/.bashrc
    fi
    
    log "Environment variables configured"
}

# Configure Docker daemon for better networking
configure_docker_daemon() {
    log_info "Configuring Docker daemon for optimal networking..."
    
    sudo mkdir -p /etc/docker
    sudo tee /etc/docker/daemon.json > /dev/null <<'DAEMON_EOF'
{
  "iptables": true,
  "userland-proxy": false,
  "live-restore": true,
  "storage-driver": "overlay2",
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
DAEMON_EOF
    
    log "Docker daemon configuration updated"
}

# Reset iptables to prevent conflicts
reset_iptables() {
    log_info "Resetting iptables to prevent networking conflicts..."
    
    sudo iptables -t nat -F 2>/dev/null || true
    sudo iptables -t mangle -F 2>/dev/null || true
    sudo iptables -F 2>/dev/null || true
    sudo iptables -X 2>/dev/null || true
    
    log "iptables reset completed"
}

# Restart Docker with new configuration
restart_docker_service() {
    log_info "Restarting Docker with new configuration..."
    
    sudo systemctl restart docker
    sleep 5
    
    # Clean any existing Docker networks that might conflict
    sudo docker network prune -f >/dev/null 2>&1 || true
    
    log "Docker service restarted successfully"
}

# Check for port conflicts
check_port_conflicts() {
    log_info "Checking for potential port conflicts..."
    
    local required_ports="5443 7000 7001 7002 7003 7004 7005 7006 7007 7008 7009 7010 7011 7012 7013 7014 7015 9200 9443 1514 1515 55000"
    local conflicts=()
    
    for port in $required_ports; do
        if sudo netstat -tulpn 2>/dev/null | grep -q ":$port "; then
            conflicts+=($port)
        fi
    done
    
    if [ ${#conflicts[@]} -gt 0 ]; then
        log_warn "The following ports are already in use: ${conflicts[*]}"
        log_warn "These may cause conflicts during CyberBlue deployment"
        log_warn "Consider stopping services using these ports or rebooting if needed"
    else
        log "All required ports are available"
    fi
}

# Test Docker access
test_docker_access() {
    log_info "Testing Docker access..."
    
    # Test Docker daemon access
    if docker ps >/dev/null 2>&1; then
        log "Docker daemon access confirmed - no logout required!"
        
        # Test Docker networking capability
        if docker network ls >/dev/null 2>&1; then
            log "Docker networking confirmed - ready for CyberBlue deployment!"
        else
            log_warn "Docker networking issue detected - may need system reboot"
        fi
    elif sudo docker ps >/dev/null 2>&1; then
        log_warn "Docker requires sudo - logout/login recommended for group permissions"
    else
        log_error "Docker daemon not accessible - check installation"
        return 1
    fi
}

# Apply Docker group and test access with newgrp
apply_docker_group() {
    log_info "Applying Docker group permissions..."
    
    # Force apply group membership without requiring logout/login
    sudo usermod -aG docker $USER
    
    # Restart Docker to ensure proper group recognition
    sudo systemctl restart docker
    sleep 5
    
    # Change socket permissions to ensure immediate access
    sudo chown root:docker /var/run/docker.sock
    sudo chmod 660 /var/run/docker.sock
    
    # Test Docker access in current session
    if sg docker -c "docker --version" >/dev/null 2>&1; then
        log "Docker access confirmed - no logout required!"
        export DOCKER_ACCESS_READY=true
    else
        log_warn "Docker group applied but may need session refresh"
        log_warn "If Docker commands fail, run: newgrp docker"
    fi
}

# Verify installation
verify_installation() {
    log_info "Verifying installation..."
    
    # Check Docker version
    if docker --version >/dev/null 2>&1; then
        local docker_version=$(docker --version)
        log "Docker verified: $docker_version"
    else
        log_error "Docker version check failed"
        return 1
    fi
    
    # Check Docker Compose version
    if docker compose version >/dev/null 2>&1; then
        local compose_version=$(docker compose version --short)
        log "Docker Compose verified: $compose_version"
    else
        log_error "Docker Compose version check failed"
        return 1
    fi
    
    return 0
}

# Main installation function
main_installation() {
    echo -e "${BLUE}"
    echo "🚀 =================================="
    echo "   CyberBlue SOC Prerequisites"
    echo "🚀 =================================="
    echo -e "${NC}"
    
    check_permissions
    check_os
    confirm_installation
    
    log_info "Starting prerequisites installation..."
    
    # Check if Docker is already installed
    if check_docker_installed; then
        install_basic_packages
        install_docker
        install_docker_compose
        configure_docker
    else
        log_info "Using existing Docker installation"
    fi
    
    configure_system_optimizations
    configure_environment
    configure_docker_daemon
    reset_iptables
    restart_docker_service
    check_port_conflicts
    apply_docker_group
    test_docker_access
    
    if verify_installation; then
        echo ""
        echo -e "${GREEN}🎉 =================================="
        echo "   Prerequisites Installation Complete!"
        echo "🎉 ==================================${NC}"
        echo ""
        echo -e "${CYAN}📋 Next Steps:${NC}"
        echo "1. Clone CyberBlue repository (if not already done)"
        echo "2. Run: ${YELLOW}./cyberblue_init.sh${NC}"
        echo ""
        echo -e "${YELLOW}💡 Note: ${NC}If Docker commands still require sudo, logout and login again."
        echo ""
    else
        log_error "Installation verification failed"
        exit 1
    fi
}

# Main execution
main() {
    parse_args "$@"
    main_installation
}

# Run main function with all arguments
main "$@"


