#!/bin/bash
# shellcheck shell=bash
# ==============================================================================
# Home Assistant Community Add-on: Tailscale
# Setup addon services via Tailscale
# ==============================================================================

set -e

# Setup addon services via Tailscale
# Reads addon_services from Home Assistant options.json and registers them with Tailscale

CONFIG_PATH="/data/options.json"

if [ ! -f "$CONFIG_PATH" ]; then
    echo "No options.json found, skipping addon services setup"
    touch /run/addon_services_ready
    exit 0
fi

# Check if addon_services is configured
if ! jq -e '.addon_services' "$CONFIG_PATH" > /dev/null 2>&1; then
    echo "No addon_services configured"
    touch /run/addon_services_ready
    exit 0
fi

echo "Setting up addon services..."

# Iterate through each addon service
jq -r '.addon_services[]? | @base64' "$CONFIG_PATH" | while read service_b64; do
    service=$(echo "$service_b64" | base64 -d)
    
    port=$(echo "$service" | jq -r '.port')
    name=$(echo "$service" | jq -r '.name')
    host=$(echo "$service" | jq -r '.host // "localhost"')
    funnel=$(echo "$service" | jq -r '.funnel // false')
    
    if [ -z "$port" ] || [ -z "$name" ]; then
        echo "Skipping invalid service config: $service"
        continue
    fi
    
    # Build the target URL
    target_url="http://$host:$port"
    
    echo "Registering service: $name (target: $target_url, funnel: $funnel)"
    
    if [ "$funnel" = "true" ]; then
        echo "Setting up funnel for $name"
        tailscale serve funnel "tcp:443/$name" "$target_url" || \
            echo "Warning: Failed to set up funnel for $name"
    else
        echo "Setting up serve for $name"
        tailscale serve "tcp:$name" "$target_url" || \
            echo "Warning: Failed to set up serve for $name"
    fi
done

echo "Addon services setup complete"
touch /run/addon_services_ready
