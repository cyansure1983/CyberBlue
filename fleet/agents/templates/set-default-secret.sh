#!/bin/bash
# Set default Fleet enrollment secret for CyberBlue
# This runs during installation to create a known enrollment secret

FLEET_SECRET="cyberblue-fleet-enrollment-secret-$(openssl rand -hex 8)"
SECRET_FILE="/tmp/fleet-enrollment-secret.txt"

echo "$FLEET_SECRET" > "$SECRET_FILE"
chmod 644 "$SECRET_FILE"

echo "Fleet enrollment secret set: $FLEET_SECRET"
echo "Saved to: $SECRET_FILE"
echo "Portal will use this automatically for agent generation"

