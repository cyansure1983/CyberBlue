#!/bin/bash
# CyberBlue - Download Wazuh Agent Packages
# This script downloads official Wazuh agent packages for agent deployment
# Run this during CyberBlue installation
# Works with any user on any machine

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BINARIES_DIR="$SCRIPT_DIR/binaries"

echo "========================================"
echo "Downloading Wazuh Agent Packages"
echo "========================================"
echo ""

# Create binaries directory
mkdir -p "$BINARIES_DIR"
cd "$BINARIES_DIR"

# Wazuh version
WAZUH_VERSION="4.12.0-1"
BASE_URL="https://packages.wazuh.com/4.x"

echo "[*] Downloading Wazuh ${WAZUH_VERSION} agent packages..."
echo ""

# Windows MSI
echo "[1/3] Downloading Windows MSI (5.2 MB)..."
curl -L -o wazuh-agent-windows.msi "${BASE_URL}/windows/wazuh-agent-${WAZUH_VERSION}.msi" \
    || { echo "Failed to download Windows MSI"; exit 1; }
echo "      ✓ wazuh-agent-windows.msi downloaded"

# Linux - Ubuntu/Debian
echo "[2/3] Downloading Ubuntu/Debian DEB (11.4 MB)..."
curl -L -o wazuh-agent-ubuntu.deb "${BASE_URL}/apt/pool/main/w/wazuh-agent/wazuh-agent_${WAZUH_VERSION}_amd64.deb" \
    || { echo "Failed to download Ubuntu/Debian DEB"; exit 1; }
echo "      ✓ wazuh-agent-ubuntu.deb downloaded"

# Linux - RHEL/CentOS
echo "[3/3] Downloading RHEL/CentOS RPM (9.6 MB)..."
curl -L -o wazuh-agent-centos.rpm "${BASE_URL}/yum/wazuh-agent-${WAZUH_VERSION}.x86_64.rpm" \
    || { echo "Failed to download RHEL/CentOS RPM"; exit 1; }
echo "      ✓ wazuh-agent-centos.rpm downloaded"

echo ""
echo "========================================"
echo "Download Complete!"
echo "========================================"
echo ""

# Fix file ownership to ensure portal can read files
# Auto-detect the actual user (works with ANY username on ANY machine)
if [ -n "$SUDO_USER" ] && [ "$SUDO_USER" != "root" ]; then
    # Script was run with sudo - chown to the real user
    REAL_USER="$SUDO_USER"
    REAL_GROUP=$(id -gn $SUDO_USER)
    echo "[*] Fixing file ownership for user: $REAL_USER (detected via SUDO_USER)"
    chown -R "$REAL_USER:$REAL_GROUP" "$SCRIPT_DIR"
    echo "    ✓ Ownership set to $REAL_USER:$REAL_GROUP"
elif [ "$(id -u)" = "0" ]; then
    # Running as root directly (no SUDO_USER) - find the actual install user
    # Get the owner of the parent CyberBlue directory (works for ubuntu, cb, or any user)
    CYBERBLUE_DIR="$(dirname "$(dirname "$(dirname "$SCRIPT_DIR")")")"
    REAL_USER=$(stat -c '%U' "$CYBERBLUE_DIR" 2>/dev/null || stat -f '%Su' "$CYBERBLUE_DIR" 2>/dev/null || echo "ubuntu")
    REAL_GROUP=$(stat -c '%G' "$CYBERBLUE_DIR" 2>/dev/null || stat -f '%Sg' "$CYBERBLUE_DIR" 2>/dev/null || echo "$REAL_USER")
    echo "[*] Fixing file ownership for user: $REAL_USER (detected from directory owner)"
    chown -R "$REAL_USER:$REAL_GROUP" "$SCRIPT_DIR"
    echo "    ✓ Ownership set to $REAL_USER:$REAL_GROUP"
else
    # Running as regular user - files should already be owned correctly
    CURRENT_USER=$(whoami)
    echo "[*] Files owned by: $CURRENT_USER (no sudo - should be correct)"
fi

echo "Downloaded packages:"
ls -lh "$BINARIES_DIR"
echo ""
echo "Total size: $(du -sh "$BINARIES_DIR" | cut -f1)"
echo ""
echo "Wazuh agent deployment system is now ready!"
echo "Users can generate and download agent packages from the portal."
echo ""
echo "NOTE: macOS package must be downloaded separately from:"
echo "      https://packages.wazuh.com/4.x/macos/wazuh-agent-${WAZUH_VERSION}.pkg"
echo ""

