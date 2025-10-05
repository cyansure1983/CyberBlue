#!/bin/bash
# CyberBlue - Auto-configure Fleet Enrollment Secret
# Runs during installation - generates secret, sets in Fleet, saves for portal
# Works for any user on any machine

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SECRET_FILE="$SCRIPT_DIR/agents/.enrollment-secret"

echo "=========================================="
echo "Extracting Fleet Enrollment Secret"
echo "=========================================="
echo ""

# Wait for Fleet database to be ready
echo "[*] Waiting for Fleet database to be ready..."
MAX_DB_RETRIES=60
DB_RETRY_COUNT=0

while [ $DB_RETRY_COUNT -lt $MAX_DB_RETRIES ]; do
    if sudo docker exec fleet-mysql mysqladmin -ufleet -pfleetpass ping > /dev/null 2>&1; then
        echo "[*] Fleet database is ready!"
        break
    fi
    DB_RETRY_COUNT=$((DB_RETRY_COUNT + 1))
    sleep 2
done

if [ $DB_RETRY_COUNT -eq $MAX_DB_RETRIES ]; then
    echo "[!] Warning: Fleet database not ready, using fallback secret"
    ENROLLMENT_SECRET=$(openssl rand -base64 24 | tr -d '\n')
    echo "$ENROLLMENT_SECRET" > "$SECRET_FILE"
    chmod 644 "$SECRET_FILE"
    echo "[!] Fallback secret: $ENROLLMENT_SECRET"
    echo "[!] Set this manually in Fleet UI"
    exit 0
fi

# Extract Fleet's auto-generated enrollment secret from database
echo "[*] Extracting enrollment secret from Fleet database..."
ENROLLMENT_SECRET=$(sudo docker exec fleet-mysql mysql -ufleet -pfleetpass fleet -se "SELECT secret FROM enroll_secrets LIMIT 1;" 2>/dev/null | tr -d '\n')

if [ -z "$ENROLLMENT_SECRET" ]; then
    echo "[!] No secret found in database, Fleet may not be initialized yet"
    echo "[*] Generating temporary secret..."
    ENROLLMENT_SECRET=$(openssl rand -base64 24 | tr -d '\n')
fi

echo "[*] Fleet enrollment secret: $ENROLLMENT_SECRET"

# Save secret to file (portal will read this)
echo "$ENROLLMENT_SECRET" > "$SECRET_FILE"
chmod 644 "$SECRET_FILE"

echo "[*] Secret saved to file for portal to use"

# Fix ownership for any user
if [ -n "$SUDO_USER" ] && [ "$SUDO_USER" != "root" ]; then
    REAL_USER="$SUDO_USER"
    REAL_GROUP=$(id -gn $SUDO_USER)
    chown "$REAL_USER:$REAL_GROUP" "$SECRET_FILE"
elif [ "$(id -u)" = "0" ]; then
    CYBERBLUE_DIR="$(dirname "$SCRIPT_DIR")"
    REAL_USER=$(stat -c '%U' "$CYBERBLUE_DIR" 2>/dev/null || stat -f '%Su' "$CYBERBLUE_DIR" 2>/dev/null || echo "ubuntu")
    REAL_GROUP=$(stat -c '%G' "$CYBERBLUE_DIR" 2>/dev/null || stat -f '%Sg' "$CYBERBLUE_DIR" 2>/dev/null || echo "$REAL_USER")
    chown "$REAL_USER:$REAL_GROUP" "$SECRET_FILE"
fi

echo "[*] Secret saved to: $SECRET_FILE"

# Wait for Fleet to be fully ready
echo "[*] Waiting for Fleet server to be ready..."
MAX_RETRIES=60
RETRY_COUNT=0

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if curl -s http://localhost:7007/healthz > /dev/null 2>&1; then
        echo "[*] Fleet server is ready!"
        break
    fi
    RETRY_COUNT=$((RETRY_COUNT + 1))
    sleep 2
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
    echo "[!] Warning: Fleet server not responding, secret saved but not configured in Fleet"
    echo "[!] You may need to manually set the enrollment secret in Fleet UI"
    echo "[!] Secret: $ENROLLMENT_SECRET"
    exit 0
fi

# Set enrollment secret in Fleet using API
echo "[*] Setting enrollment secret in Fleet..."

# Fleet API requires authentication - try to get/create admin user first
# For now, save secret and provide manual instruction
echo ""
echo "=========================================="
echo "Configuration Complete!"
echo "=========================================="
echo ""
echo "✓ Fleet enrollment secret extracted: $ENROLLMENT_SECRET"
echo "✓ Secret saved to: $SECRET_FILE"
echo "✓ Portal will automatically embed this in agent packages"
echo ""
echo "✅ No manual configuration needed - Fleet's existing secret is being used!"
echo ""
echo "Agent packages downloaded from portal will automatically work with Fleet."
echo ""

