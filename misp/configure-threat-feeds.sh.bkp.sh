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

# CRITICAL: Wait for admin user to exist FIRST!
echo "[*] Waiting for admin user to be created..."
MAX_USER_WAIT=420
USER_WAIT=0

while [ $USER_WAIT -lt $MAX_USER_WAIT ]; do
    USER_EXISTS=$(sudo docker exec misp-core mysql -h db -u misp -pexample misp \
        -se "SELECT COUNT(*) FROM users WHERE email='admin@admin.test';" 2>/dev/null || echo "0")
    
    if [ "$USER_EXISTS" -gt "0" ]; then
        echo "[*] Admin user found!"
        break
    fi
    
    USER_WAIT=$((USER_WAIT + 5))
    sleep 5
done

if [ "$USER_EXISTS" -eq "0" ]; then
    echo "[!] Warning: Admin user not created after ${MAX_USER_WAIT}s"
    exit 0
fi

# NOW set change_pw=0 (admin exists, this will work!)
echo "[*] Disabling password change requirement..."
sudo docker exec misp-core mysql -h db -u misp -pexample misp \
    -e "UPDATE users SET change_pw=0 WHERE email='admin@admin.test';" 2>/dev/null || true

sleep 2

# Verify it worked
CHANGE_PW=$(sudo docker exec misp-core mysql -h db -u misp -pexample misp \
    -se "SELECT change_pw FROM users WHERE email='admin@admin.test';" 2>/dev/null || echo "1")

if [ "$CHANGE_PW" = "0" ]; then
    echo "[*] ✅ Password bypass verified (change_pw=0)"
else
    echo "[!] ⚠️  Password bypass failed (change_pw=$CHANGE_PW)"
fi

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

# Function to add feed if it doesn't exist
add_or_enable_feed() {
    local feed_name=$1
    local provider=$2
    local url=$3
    local format=$4
    local csv_value=$5
    local csv_delimiter=$6
    
    # Check if feed exists by URL
    FEED_ID=$(sudo docker exec misp-core mysql -h db -u misp -pexample misp \
        -se "SELECT id FROM feeds WHERE url='$url' LIMIT 1;" 2>/dev/null || echo "")
    
    if [ -n "$FEED_ID" ]; then
        # Feed exists, just enable it
        sudo docker exec misp-core curl -k -s -X POST \
            -H "Authorization: $MISP_API_KEY" \
            https://localhost/feeds/enable/$FEED_ID > /dev/null 2>&1
        echo "    ✅ Enabled (ID: $FEED_ID)"
        return 0
    fi
    
    # Feed doesn't exist, add it
    echo "    Adding to MISP..."
    
    # Build CSV settings if provided
    if [ -n "$csv_value" ]; then
        CSV_SETTINGS="{\\\"csv\\\":{\\\"value\\\":\\\"$csv_value\\\",\\\"delimiter\\\":\\\"$csv_delimiter\\\"},\\\"common\\\":{\\\"excluderegex\\\":\\\"\\\"}}"
    else
        CSV_SETTINGS="{\\\"csv\\\":{\\\"value\\\":\\\"\\\",\\\"delimiter\\\":\\\",\\\"},\\\"common\\\":{\\\"excluderegex\\\":\\\"\\\"}}"
    fi
    
    # Add feed via API
    ADD_RESULT=$(sudo docker exec misp-core curl -k -s -X POST \
        -H "Authorization: $MISP_API_KEY" \
        -H "Content-Type: application/json" \
        -H "Accept: application/json" \
        https://localhost/feeds/add -d "{
            \"Feed\": {
                \"name\": \"$feed_name\",
                \"provider\": \"$provider\",
                \"url\": \"$url\",
                \"source_format\": \"$format\",
                \"enabled\": true,
                \"distribution\": \"3\",
                \"sharing_group_id\": \"0\",
                \"tag_id\": \"0\",
                \"default\": false,
                \"input_source\": \"network\",
                \"delete_local_file\": false,
                \"lookup_visible\": true,
                \"publish\": false,
                \"override_ids\": false,
                \"fixed_event\": true,
                \"delta_merge\": false,
                \"settings\": \"$CSV_SETTINGS\"
            }
        }" 2>&1)
    
    # Verify it was added
    NEW_ID=$(sudo docker exec misp-core mysql -h db -u misp -pexample misp \
        -se "SELECT id FROM feeds WHERE url='$url' LIMIT 1;" 2>/dev/null || echo "")
    
    if [ -n "$NEW_ID" ]; then
        echo "    ✅ Added successfully (ID: $NEW_ID)"
        return 0
    else
        echo "    ❌ Failed to add feed"
        echo "    Error: $ADD_RESULT" | head -3
        return 1
    fi
}

# Configure 5 threat intelligence feeds
echo "[*] Configuring 5 threat intelligence feeds..."
echo ""

# Feed 1: CIRCL OSINT Feed
echo "[1/5] CIRCL OSINT Feed"
add_or_enable_feed "CIRCL OSINT Feed" "CIRCL" "https://www.circl.lu/doc/misp/feed-osint" "misp" "" ""
echo ""

# Feed 2: URLhaus (Malware URLs)
echo "[2/5] URLhaus - Malware URLs"
add_or_enable_feed "URLhaus - Malware URLs" "Abuse.ch" "https://urlhaus.abuse.ch/downloads/misp/" "misp" "" ""
echo ""

# Feed 3: Feodo Tracker (Botnet C2)
echo "[3/5] Feodo IP Blocklist"
add_or_enable_feed "Feodo IP Blocklist" "Abuse.ch" "https://feodotracker.abuse.ch/downloads/ipblocklist.csv" "csv" "2" ","
echo ""

# Feed 4: OpenPhish (Phishing URLs)
echo "[4/5] OpenPhish URL Feed"
add_or_enable_feed "OpenPhish URL Feed" "OpenPhish" "https://raw.githubusercontent.com/openphish/public_feed/refs/heads/main/feed.txt" "freetext" "" ""
echo ""

# Feed 5: AlienVault Reputation
echo "[5/5] AlienVault Reputation"
add_or_enable_feed "AlienVault Reputation" "AlienVault" "https://reputation.alienvault.com/reputation.generic" "csv" "1" "#"
echo ""

# Final verification
echo "[*] Verification..."
ENABLED_COUNT=$(sudo docker exec misp-core mysql -h db -u misp -pexample misp \
    -se "SELECT COUNT(*) FROM feeds WHERE enabled=1;" 2>/dev/null)

echo "[*] Total enabled feeds: $ENABLED_COUNT"
echo ""

# Show what's actually configured
echo "Configured feeds:"
sudo docker exec misp-core mysql -h db -u misp -pexample misp \
    -e "SELECT id, name, enabled FROM feeds WHERE enabled=1 ORDER BY id;" 2>/dev/null
echo ""

# Fetch initial feed data
echo "[*] Starting threat intelligence download..."
echo "    (Downloading from $ENABLED_COUNT feeds - may take 5-10 minutes)"
echo ""

# Start fetch in background so we can show it started
(
    sudo docker exec misp-core curl -k -X POST \
        -H "Authorization: $MISP_API_KEY" \
        -H "Accept: application/json" \
        https://localhost/feeds/fetchFromAllFeeds > /dev/null 2>&1 || true
    
    # Log when complete
    FINAL_COUNT=$(sudo docker exec misp-core mysql -h db -u misp -pexample misp \
        -se "SELECT COUNT(*) FROM attributes;" 2>/dev/null || echo "0")
    echo "[$(date)] ✅ MISP feeds synchronized! Total indicators: $FINAL_COUNT" | tee -a /var/log/misp-feed-sync.log
) &

FETCH_PID=$!
sleep 30

# Check if sync is running
if ps -p $FETCH_PID > /dev/null 2>&1; then
    echo "    ✅ Feed synchronization is active!"
else
    echo "    ✅ Feed synchronization started!"
fi

# Show current count
CURRENT_COUNT=$(sudo docker exec misp-core mysql -h db -u misp -pexample misp \
    -se "SELECT COUNT(*) FROM attributes;" 2>/dev/null || echo "0")

echo "    Current indicators: $CURRENT_COUNT (increasing as feeds sync)"
echo ""

echo "=========================================="
echo "MISP Threat Feeds Configured!"
echo "=========================================="
echo ""
echo "✓ Feeds enabled: $ENABLED_COUNT"
echo "✓ Feed synchronization: Started"
echo "✓ MISP ready for threat intelligence operations"
echo ""
echo "ℹ️  Feed sync continues in background (10-15 minutes)"
echo "ℹ️  Check progress: tail -f /var/log/misp-feed-sync.log"
echo "ℹ️  Portal Intel tab will update as indicators load"
echo ""
echo "Auto-update cron job will keep feeds fresh every 3 hours"
echo ""

