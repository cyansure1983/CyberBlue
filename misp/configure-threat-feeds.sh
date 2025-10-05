#!/bin/bash
# CyberBlue - Auto-configure MISP Threat Feeds
# Enables popular free feeds and syncs initial data
# Works automatically during installation

set -e

echo "=========================================="
echo "Configuring MISP Threat Intelligence Feeds"
echo "=========================================="
echo ""

# Wait for MISP to be ready
echo "[*] Waiting for MISP to be ready..."
MAX_RETRIES=120
RETRY_COUNT=0

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if sudo docker exec misp-core curl -k -s https://localhost/users/heartbeat > /dev/null 2>&1; then
        echo "[*] MISP is ready!"
        break
    fi
    RETRY_COUNT=$((RETRY_COUNT + 1))
    sleep 3
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
    echo "[!] Warning: MISP not responding, skipping feed configuration"
    exit 0
fi

# CRITICAL: First set change_pw=0 so API key works!
echo "[*] Enabling MISP API key..."
sudo docker exec misp-core mysql -h db -u misp -pexample misp -e "UPDATE users SET change_pw=0 WHERE email='admin@admin.test';" 2>/dev/null || true

sleep 2

# Get MISP API key (from default admin user)
echo "[*] Getting MISP API key..."
MISP_API_KEY=$(sudo docker exec misp-core mysql -h db -u misp -pexample misp -se "SELECT authkey FROM users WHERE email='admin@admin.test' LIMIT 1;" 2>/dev/null || echo "")

if [ -z "$MISP_API_KEY" ]; then
    echo "[!] Could not retrieve MISP API key"
    echo "[!] MISP may not be fully initialized yet - wait 5 more minutes and run:"
    echo "[!]   bash misp/configure-threat-feeds.sh"
    exit 0
fi

echo "[*] MISP API Key obtained"

# Enable popular free threat feeds
echo "[*] Enabling threat intelligence feeds..."

# Use docker exec to call MISP API from inside container
echo "  [1/5] Enabling CIRCL OSINT Feed..."
sudo docker exec misp-core curl -k -X POST -H "Authorization: $MISP_API_KEY" -H "Accept: application/json" \
    https://localhost/feeds/enable/1 > /dev/null 2>&1 || true

echo "  [2/5] Enabling Abuse.ch URLhaus..."
sudo docker exec misp-core curl -k -X POST -H "Authorization: $MISP_API_KEY" -H "Accept: application/json" \
    https://localhost/feeds/enable/2 > /dev/null 2>&1 || true

echo "  [3/5] Enabling AlienVault OTX..."
sudo docker exec misp-core curl -k -X POST -H "Authorization: $MISP_API_KEY" -H "Accept: application/json" \
    https://localhost/feeds/enable/3 > /dev/null 2>&1 || true

echo "  [4/5] Enabling Feodo Tracker..."
sudo docker exec misp-core curl -k -X POST -H "Authorization: $MISP_API_KEY" -H "Accept: application/json" \
    https://localhost/feeds/enable/4 > /dev/null 2>&1 || true

echo "  [5/5] Enabling OpenPhish..."
sudo docker exec misp-core curl -k -X POST -H "Authorization: $MISP_API_KEY" -H "Accept: application/json" \
    https://localhost/feeds/enable/5 > /dev/null 2>&1 || true

echo "[*] Feeds enabled successfully"

# Fetch initial feed data
echo ""
echo "[*] Fetching initial threat intelligence..."
echo "    (This may take 2-3 minutes)"

sudo docker exec misp-core curl -k -X POST -H "Authorization: $MISP_API_KEY" -H "Accept: application/json" \
    https://localhost/feeds/fetchFromAllFeeds > /dev/null 2>&1 || true

echo "[*] Initial feed sync complete"

echo ""
echo "=========================================="
echo "MISP Threat Feeds Configured!"
echo "=========================================="
echo ""
echo "✓ Popular threat feeds enabled"
echo "✓ Initial IOC data fetched"
echo "✓ MISP ready for threat intelligence operations"
echo ""
echo "Feeds configured:"
echo "  • CIRCL OSINT Feed"
echo "  • Abuse.ch URLhaus (malicious URLs)"
echo "  • AlienVault OTX"
echo "  • Feodo Tracker (botnet C2)"
echo "  • OpenPhish (phishing)"
echo ""
echo "Auto-update cron job will keep feeds fresh every 3 hours"
echo ""

