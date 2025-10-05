#!/bin/bash

# VMware Compatibility Fix Script for CyberBlue SOC
# This script resolves Docker Compose compatibility issues on VMware VMs

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}✅${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠️${NC} $1"
}

print_error() {
    echo -e "${RED}❌${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ️${NC} $1"
}

print_header() {
    echo -e "${BLUE}🔧 $1${NC}"
    echo "$(printf '=%.0s' {1..50})"
}

# Function to detect virtualization environment
detect_environment() {
    print_info "Detecting virtualization environment..."
    
    if command -v systemd-detect-virt >/dev/null 2>&1; then
        VIRT_ENV=$(systemd-detect-virt)
        if [ "$VIRT_ENV" = "vmware" ]; then
            print_warning "VMware environment detected - applying compatibility fixes"
            return 0
        elif [ "$VIRT_ENV" = "kvm" ]; then
            print_info "KVM environment detected - may need compatibility fixes"
            return 0
        elif [ "$VIRT_ENV" = "none" ]; then
            print_info "Bare metal environment detected"
            return 1
        else
            print_info "Virtualization environment: $VIRT_ENV"
            return 0
        fi
    fi
    
    # Fallback detection methods
    if dmidecode -s system-product-name 2>/dev/null | grep -qi "vmware"; then
        print_warning "VMware detected via DMI - applying compatibility fixes"
        return 0
    elif dmidecode -s system-product-name 2>/dev/null | grep -qi "amazon ec2"; then
        print_status "AWS EC2 detected - no fixes needed"
        return 1
    elif dmidecode -s system-product-name 2>/dev/null | grep -qi "virtualbox"; then
        print_warning "VirtualBox detected - may need compatibility fixes"
        return 0
    fi
    
    print_info "Environment detection inconclusive - applying fixes as precaution"
    return 0
}

# Function to check and update Docker Compose version
update_docker_compose() {
    print_header "Docker Compose Version Check"
    
    CURRENT_VERSION=$(docker compose version --short 2>/dev/null || echo "not found")
    print_info "Current Docker Compose version: $CURRENT_VERSION"
    
    # Check if version is older than 2.20 (when start_interval was added)
    if [ "$CURRENT_VERSION" = "not found" ]; then
        print_error "Docker Compose not found!"
        print_info "Installing Docker Compose..."
        
        sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
        
        NEW_VERSION=$(docker compose version --short 2>/dev/null || docker-compose version --short 2>/dev/null)
        print_status "Docker Compose installed: $NEW_VERSION"
    else
        # Extract major.minor version for comparison
        VERSION_MAJOR=$(echo "$CURRENT_VERSION" | cut -d'.' -f1 | sed 's/v//')
        VERSION_MINOR=$(echo "$CURRENT_VERSION" | cut -d'.' -f2)
        
        if [ "$VERSION_MAJOR" -lt 2 ] || ([ "$VERSION_MAJOR" -eq 2 ] && [ "$VERSION_MINOR" -lt 20 ]); then
            print_warning "Docker Compose version $CURRENT_VERSION is older than 2.20"
            print_info "Updating to latest version..."
            
            sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
            sudo chmod +x /usr/local/bin/docker-compose
            
            NEW_VERSION=$(docker compose version --short 2>/dev/null || docker-compose version --short 2>/dev/null)
            print_status "Docker Compose updated to: $NEW_VERSION"
        else
            print_status "Docker Compose version is compatible"
        fi
    fi
}

# Function to set missing environment variables
set_environment_variables() {
    print_header "Environment Variables Setup"
    
    # List of variables that commonly cause issues on VMware
    ENV_VARS=(
        "FASTCGI_STATUS_LISTEN"
        "PHP_SESSION_COOKIE_DOMAIN"
        "HSTS_MAX_AGE"
        "X_FRAME_OPTIONS"
        "CONTENT_SECURITY_POLICY"
        "MODULES_COMMIT"
        "job_directory"
        "CORE_COMMIT"
        "PYPI_REDIS_VERSION"
        "PYPI_LIEF_VERSION"
        "PYPI_PYDEEP2_VERSION"
        "PYPI_PYTHON_MAGIC_VERSION"
        "PYPI_MISP_LIB_STIX2_VERSION"
        "PYPI_MAEC_VERSION"
        "PYPI_MIXBOX_VERSION"
        "PYPI_CYBOX_VERSION"
        "PYPI_PYMISP_VERSION"
        "PYPI_MISP_STIX_VERSION"
        "CRON_PULLALL"
        "CRON_PUSHALL"
        "DISABLE_IPV6"
        "DISABLE_SSL_REDIRECT"
        "DISABLE_CA_REFRESH"
    )
    
    print_info "Setting environment variables to prevent warnings..."
    
    for var in "${ENV_VARS[@]}"; do
        if [ -z "${!var}" ]; then
            export "$var"=""
            echo "export $var=\"\"" >> ~/.bashrc
        fi
    done
    
    print_status "Environment variables configured"
}

# Function to create VMware-compatible docker-compose file
create_vmware_compose() {
    print_header "VMware Docker Compose Compatibility"
    
    if [ -f "docker-compose.yml" ]; then
        print_info "Creating VMware-compatible docker-compose file..."
        
        # Create backup
        cp docker-compose.yml docker-compose.yml.backup
        
        # Remove problematic health check parameters for older Docker Compose versions
        sed -i '/start_interval:/d' docker-compose.yml
        sed -i '/start_period: *[0-9]/s/start_period:/interval:/' docker-compose.yml
        
        print_status "Created VMware-compatible docker-compose.yml"
        print_info "Original backed up as docker-compose.yml.backup"
    else
        print_warning "docker-compose.yml not found in current directory"
    fi
}

# Function to fix common VMware volume issues
fix_volume_permissions() {
    print_header "Volume Permissions Fix"
    
    print_info "Creating required directories with proper permissions..."
    
    # Create common directories that may cause issues
    sudo mkdir -p /opt/cyberblue/{suricata,arkime,wazuh,logs} 2>/dev/null || true
    sudo chown -R $USER:$USER /opt/cyberblue 2>/dev/null || true
    
    # Fix local directory permissions
    sudo chown -R $USER:$USER . 2>/dev/null || true
    
    print_status "Volume permissions configured"
}

# Function to optimize system for containers
optimize_system() {
    print_header "System Optimization for VMware"
    
    print_info "Applying container optimizations..."
    
    # Increase virtual memory for Elasticsearch/OpenSearch
    echo 'vm.max_map_count=262144' | sudo tee -a /etc/sysctl.conf >/dev/null 2>&1 || true
    sudo sysctl -p >/dev/null 2>&1 || true
    
    # Increase file descriptor limits
    echo '* soft nofile 65536' | sudo tee -a /etc/security/limits.conf >/dev/null 2>&1 || true
    echo '* hard nofile 65536' | sudo tee -a /etc/security/limits.conf >/dev/null 2>&1 || true
    
    # Enable Docker BuildKit for better performance
    echo 'export DOCKER_BUILDKIT=1' >> ~/.bashrc
    echo 'export COMPOSE_DOCKER_CLI_BUILD=1' >> ~/.bashrc
    
    print_status "System optimized for container deployment"
}

# Function to test Docker setup
test_docker_setup() {
    print_header "Docker Setup Verification"
    
    print_info "Testing Docker installation..."
    
    if docker --version >/dev/null 2>&1; then
        DOCKER_VERSION=$(docker --version)
        print_status "Docker: $DOCKER_VERSION"
    else
        print_error "Docker not found or not working"
        return 1
    fi
    
    if docker compose version >/dev/null 2>&1; then
        COMPOSE_VERSION=$(docker compose version --short)
        print_status "Docker Compose: $COMPOSE_VERSION"
    elif docker-compose version >/dev/null 2>&1; then
        COMPOSE_VERSION=$(docker-compose version --short)
        print_warning "Using legacy docker-compose command"
        print_info "Consider updating to docker compose plugin"
    else
        print_error "Docker Compose not found"
        return 1
    fi
    
    if docker ps >/dev/null 2>&1; then
        print_status "Docker daemon is accessible"
    else
        print_error "Cannot access Docker daemon - check permissions"
        print_info "Try: sudo usermod -aG docker $USER && newgrp docker"
        return 1
    fi
    
    return 0
}

# Main execution
main() {
    print_header "VMware Compatibility Fix for CyberBlue SOC"
    echo "This script fixes Docker Compose compatibility issues on VMware VMs"
    echo ""
    
    # Parse arguments
    SKIP_UPDATE=false
    FORCE_FIX=false
    
    for arg in "$@"; do
        case $arg in
            --skip-update)
                SKIP_UPDATE=true
                shift
                ;;
            --force)
                FORCE_FIX=true
                shift
                ;;
            -h|--help)
                echo "Usage: $0 [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  --skip-update    Skip Docker Compose update"
                echo "  --force          Apply fixes even if environment is not VMware"
                echo "  -h, --help       Show this help message"
                echo ""
                echo "This script:"
                echo "  1. Detects VMware environment"
                echo "  2. Updates Docker Compose to latest version"
                echo "  3. Sets missing environment variables"
                echo "  4. Creates VMware-compatible docker-compose file"
                echo "  5. Fixes volume permissions"
                echo "  6. Optimizes system for containers"
                exit 0
                ;;
        esac
    done
    
    # Step 1: Detect environment
    if detect_environment || [ "$FORCE_FIX" = true ]; then
        print_info "Applying VMware compatibility fixes..."
    else
        print_status "Environment appears to be cloud-optimized (AWS/Azure/GCP)"
        print_info "No VMware-specific fixes needed"
        if [ "$FORCE_FIX" = false ]; then
            echo "Use --force to apply fixes anyway"
            exit 0
        fi
    fi
    
    # Step 2: Test current Docker setup
    if ! test_docker_setup; then
        print_error "Docker setup issues detected - please fix Docker installation first"
        exit 1
    fi
    
    # Step 3: Update Docker Compose (unless skipped)
    if [ "$SKIP_UPDATE" = false ]; then
        update_docker_compose
    else
        print_info "Skipping Docker Compose update"
    fi
    
    # Step 4: Set environment variables
    set_environment_variables
    
    # Step 5: Create VMware-compatible compose file
    create_vmware_compose
    
    # Step 6: Fix volume permissions
    fix_volume_permissions
    
    # Step 7: Optimize system
    optimize_system
    
    # Final verification
    print_header "Compatibility Fix Complete"
    print_status "VMware compatibility fixes applied successfully!"
    print_info "You can now run: ./cyberblue_init.sh"
    
    echo ""
    print_info "If you still encounter issues:"
    echo "   1. Try: docker compose --compatibility up -d"
    echo "   2. Use legacy: docker-compose up -d"
    echo "   3. Check logs: docker compose logs"
    echo "   4. Review: VMWARE_COMPATIBILITY_FIX.md"
}

# Detect platform for informational purposes
detect_platform() {
    if command -v systemd-detect-virt >/dev/null 2>&1; then
        systemd-detect-virt 2>/dev/null || echo "unknown"
    elif [ -f /sys/class/dmi/id/sys_vendor ]; then
        case $(cat /sys/class/dmi/id/sys_vendor 2>/dev/null) in
            "VMware, Inc.") echo "vmware" ;;
            "Microsoft Corporation") echo "azure" ;;
            "Google") echo "gcp" ;;
            "QEMU") echo "qemu" ;;
            "innotek GmbH") echo "virtualbox" ;;
            *) echo "unknown" ;;
        esac
    else
        echo "unknown"
    fi
}

# Show platform info
PLATFORM=$(detect_platform)
print_info "Detected platform: $PLATFORM"

# Run main function
main "$@"
