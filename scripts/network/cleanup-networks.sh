#!/bin/bash
# BTPI-REACT Network Cleanup Utility

echo "=== BTPI-REACT Network Cleanup ==="
echo

networks=(btpi-core-network btpi-wazuh-network btpi-infra-network btpi-proxy-network btpi-network)

for network in "${networks[@]}"; do
    if docker network ls | grep -q "$network"; then
        echo "🔄 Cleaning up network: $network"

        # Get connected containers
        containers=$(docker network inspect "$network" -f '{{range $id,$container := .Containers}}{{$container.Name}} {{end}}' 2>/dev/null)

        if [[ -n "$containers" && "$containers" != " " ]]; then
            echo "   Disconnecting containers: $containers"
            for container in $containers; do
                echo "   - Disconnecting $container"
                docker network disconnect "$network" "$container" 2>/dev/null || true
            done
        fi

        echo "   - Removing network $network"
        docker network rm "$network" 2>/dev/null || true
        echo "   ✅ Network $network removed"
    else
        echo "   ℹ️  Network $network not found"
    fi
    echo
done

echo "=== Cleanup Complete ==="
