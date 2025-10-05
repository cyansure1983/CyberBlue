#!/bin/bash
# CyberBlue - Download Fleet/Osquery Agent Packages
# Works with any user on any machine

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BINARIES_DIR="$SCRIPT_DIR/binaries"

echo "========================================"
echo "Downloading Fleet/Osquery Packages"
echo "========================================"
echo ""

mkdir -p "$BINARIES_DIR"
cd "$BINARIES_DIR"

OSQUERY_VERSION="5.13.1"
BASE_URL="https://github.com/osquery/osquery/releases/download/${OSQUERY_VERSION}"

echo "[*] Downloading osquery ${OSQUERY_VERSION} packages..."
echo ""

# Windows
echo "[1/4] Downloading Windows MSI (18 MB)..."
curl -L -o osquery-windows.msi "${BASE_URL}/osquery-${OSQUERY_VERSION}.msi" \
    || { echo "Failed"; exit 1; }
echo "      ✓ osquery-windows.msi"

# Ubuntu/Debian
echo "[2/4] Downloading Ubuntu/Debian DEB (29 MB)..."
curl -L -o osquery-ubuntu.deb "${BASE_URL}/osquery_${OSQUERY_VERSION}-1.linux_amd64.deb" \
    || { echo "Failed"; exit 1; }
echo "      ✓ osquery-ubuntu.deb"

# RHEL/CentOS
echo "[3/4] Downloading RHEL/CentOS RPM (29 MB)..."
curl -L -o osquery-centos.rpm "${BASE_URL}/osquery-${OSQUERY_VERSION}-1.linux.x86_64.rpm" \
    || { echo "Failed"; exit 1; }
echo "      ✓ osquery-centos.rpm"

# macOS
echo "[4/4] Downloading macOS PKG (23 MB)..."
curl -L -o osquery-macos.pkg "${BASE_URL}/osquery-${OSQUERY_VERSION}.pkg" \
    || { echo "Failed"; exit 1; }
echo "      ✓ osquery-macos.pkg"

echo ""
echo "========================================"
echo "Download Complete!"
echo "========================================"
echo ""

# Auto-fix ownership for any user
if [ -n "$SUDO_USER" ] && [ "$SUDO_USER" != "root" ]; then
    REAL_USER="$SUDO_USER"
    REAL_GROUP=$(id -gn $SUDO_USER)
    echo "[*] Fixing ownership for: $REAL_USER"
    chown -R "$REAL_USER:$REAL_GROUP" "$SCRIPT_DIR"
    echo "    ✓ Ownership set to $REAL_USER:$REAL_GROUP"
elif [ "$(id -u)" = "0" ]; then
    CYBERBLUE_DIR="$(dirname "$(dirname "$(dirname "$SCRIPT_DIR")")")"
    REAL_USER=$(stat -c '%U' "$CYBERBLUE_DIR" 2>/dev/null || stat -f '%Su' "$CYBERBLUE_DIR" 2>/dev/null || echo "ubuntu")
    REAL_GROUP=$(stat -c '%G' "$CYBERBLUE_DIR" 2>/dev/null || stat -f '%Sg' "$CYBERBLUE_DIR" 2>/dev/null || echo "$REAL_USER")
    echo "[*] Fixing ownership for: $REAL_USER (detected)"
    chown -R "$REAL_USER:$REAL_GROUP" "$SCRIPT_DIR"
    echo "    ✓ Ownership set to $REAL_USER:$REAL_GROUP"
fi

ls -lh "$BINARIES_DIR"
echo ""
echo "Total size: $(du -sh "$BINARIES_DIR" | cut -f1)"
echo ""
echo "Fleet osquery agent deployment ready!"
echo ""

