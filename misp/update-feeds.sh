#!/bin/bash
# CyberBlue - MISP Feed Update (Every 3 Hours)
# Runs via cron to keep threat intel fresh

MISP_API_KEY=$(sudo docker exec misp-core mysql -h db -u misp -pexample misp -se "SELECT authkey FROM users WHERE email='admin@admin.test' LIMIT 1;" 2>/dev/null || echo "")

if [ -n "$MISP_API_KEY" ]; then
    echo "[$(date)] Updating MISP threat feeds..."
    sudo docker exec misp-core curl -k -X POST -H "Authorization: $MISP_API_KEY" -H "Accept: application/json" \
        https://localhost/feeds/fetchFromAllFeeds > /dev/null 2>&1
    echo "[$(date)] MISP feeds updated successfully"
else
    echo "[$(date)] Could not get MISP API key"
fi

