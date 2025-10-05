#!/bin/bash

# 🛡️ CyberBlue Quick Start Script
# Automated setup and deployment for the CyberBlue cybersecurity platform
# Version: 2.0.0

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Banner
echo -e "${BLUE}"
cat << "EOF"
 ██████╗██╗   ██╗██████╗ ███████╗██████╗ ██████╗ ██╗     ██╗   ██╗███████╗
██╔════╝╚██╗ ██╔╝██╔══██╗██╔════╝██╔══██╗██╔══██╗██║     ██║   ██║██╔════╝
██║      ╚████╔╝ ██████╔╝█████╗  ██████╔╝██████╔╝██║     ██║   ██║█████╗  
██║       ╚██╔╝  ██╔══██╗██╔══╝  ██╔══██╗██╔══██╗██║     ██║   ██║██╔══╝  
╚██████╗   ██║   ██████╔╝███████╗██║  ██║██████╔╝███████╗╚██████╔╝███████╗
 ╚═════╝   ╚═╝   ╚═════╝ ╚══════╝╚═╝  ╚═╝╚═════╝ ╚══════╝ ╚═════╝ ╚══════╝
                                                                           
    🚀 QUICK START DEPLOYMENT SCRIPT 🚀
    Complete Cybersecurity Platform Setup
EOF
echo -e "${NC}"

# Global variables
LOG_FILE="cyberblue-setup.log"
BACKUP_DIR="./backup-$(date +%Y%m%d-%H%M%S)"
START_TIME=$(date +%s)

# Logging function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
    echo -e "$1"
}

# Success message
success_message() {
    local end_time=$(date +%s)
    local duration=$((end_time - START_TIME))
    local minutes=$((duration / 60))
    local seconds=$((duration % 60))
    
    echo -e "${GREEN}"
    cat << "EOF"
✅ DEPLOYMENT COMPLETE! ✅
CyberBlue is ready for action!
EOF
    echo -e "${NC}"
    log "${GREEN}🎉 CyberBlue deployment completed successfully!${NC}"
    log "${CYAN}⏱️  Total setup time: ${minutes}m ${seconds}s${NC}"
    log ""
    log "${WHITE}🌐 Portal Access:${NC}"
    log "${CYAN}   http://${HOST_IP}:5500${NC}"
    log ""
    log "${WHITE}📖 Next Steps:${NC}"
    log "${YELLOW}   1. Visit the portal to verify all services${NC}"
    log "${YELLOW}   2. Access Arkime at http://${HOST_IP}:7008 (admin/admin)${NC}"
    log "${YELLOW}   3. Review SECURITY.md for hardening steps${NC}"
    log "${YELLOW}   4. Change default passwords immediately${NC}"
    log "${YELLOW}   5. Configure individual tools as needed${NC}"
}

# Error handling
error_exit() {
    log "${RED}❌ ERROR: $1${NC}"
    log "${YELLOW}📋 Check the log file: $LOG_FILE${NC}"
    exit 1
}

# Check prerequisites
check_prerequisites() {
    log "${BLUE}🔍 Checking prerequisites...${NC}"
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        error_exit "Docker is not installed. Please install Docker first."
    fi
    
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        error_exit "Docker Compose is not installed."
    fi
    
    if ! docker info &> /dev/null; then
        error_exit "Docker daemon is not running. Please start Docker first."
    fi
    
    log "${GREEN}✅ Prerequisites check passed${NC}"
}

# Configure environment
configure_environment() {
    log "${BLUE}⚙️  Configuring environment...${NC}"
    
    # Get host IP
    HOST_IP=$(hostname -I | awk '{print $1}' 2>/dev/null || echo "localhost")
    
    # Create .env if it doesn't exist
    if [ ! -f .env ]; then
        if [ -f .env.example ]; then
            log "${CYAN}📋 Creating .env from .env.example...${NC}"
            cp .env.example .env
        else
            error_exit ".env.example not found. Please ensure you're in the CyberBlue directory."
        fi
    fi
    
    # Update HOST_IP in .env
    if grep -q "^HOST_IP=" .env; then
        sed -i "s|^HOST_IP=.*|HOST_IP=${HOST_IP}|" .env
    else
        echo "HOST_IP=${HOST_IP}" >> .env
    fi
    
    log "${GREEN}✅ Environment configured${NC}"
    log "${CYAN}   Host IP: $HOST_IP${NC}"
}

# Main deployment
main() {
    log "${WHITE}🚀 Starting CyberBlue Quick Start Deployment${NC}"
    log "${CYAN}📅 $(date)${NC}"
    log ""
    
    check_prerequisites
    configure_environment
    
    # Run the original cyberblue_init.sh if it exists
    if [ -f "./cyberblue_init.sh" ]; then
        log "${BLUE}🔧 Running CyberBlue initialization...${NC}"
        ./cyberblue_init.sh || error_exit "CyberBlue initialization failed"
    else
        # Fallback: basic Docker deployment
        log "${BLUE}🐳 Starting Docker services...${NC}"
        docker-compose up -d || error_exit "Failed to start Docker services"
    fi
    
    log ""
    log "${RED}🚨 CRITICAL SECURITY REMINDERS:${NC}"
    log "${YELLOW}   1. Change ALL default passwords in .env file${NC}"
    log "${YELLOW}   2. Review and implement SECURITY.md recommendations${NC}"
    log "${YELLOW}   3. Configure firewalls to restrict access${NC}"
    log ""
    
    success_message
}

# Help function
show_help() {
    echo "CyberBlue Quick Start Script"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo ""
    echo "This script will:"
    echo "  1. Check system prerequisites"
    echo "  2. Configure the environment"
    echo "  3. Deploy the CyberBlue platform"
    echo "  4. Provide access information"
}

# Parse arguments
case "${1:-}" in
    -h|--help)
        show_help
        exit 0
        ;;
    *)
        main "$@"
        ;;
esac 