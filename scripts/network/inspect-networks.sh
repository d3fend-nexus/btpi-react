#!/bin/bash
# BTPI-REACT Network Inspection Utility

echo "=== BTPI-REACT Network Status ==="
echo

for network in btpi-core-network btpi-wazuh-network btpi-infra-network btpi-proxy-network; do
    if docker network ls | grep -q "$network"; then
        echo "📡 Network: $network"
        echo "   Subnet: $(docker network inspect $network -f '{{range .IPAM.Config}}{{.Subnet}}{{end}}')"
        echo "   Gateway: $(docker network inspect $network -f '{{range .IPAM.Config}}{{.Gateway}}{{end}}')"

        # List containers
        containers=$(docker network inspect $network -f '{{range $id,$container := .Containers}}{{$container.Name}} {{end}}' 2>/dev/null)
        if [[ -n "$containers" && "$containers" != " " ]]; then
            echo "   Containers: $containers"
        else
            echo "   Containers: (none)"
        fi

        # Show container IPs
        docker network inspect $network -f '{{range $id,$container := .Containers}}{{$container.Name}}: {{$container.IPv4Address}} {{end}}' 2>/dev/null | while read line; do
            if [[ -n "$line" && "$line" != ": " ]]; then
                echo "     $line"
            fi
        done
        echo
    else
        echo "❌ Network: $network (not found)"
        echo
    fi
done

echo "=== Port Allocations ==="
echo "Core Services (9000-9299): Elasticsearch:9200, Available:9000-9001"
echo "Wazuh Services (9300-9599): Wazuh-indexer:9300, Wazuh-manager:9400, Wazuh-dashboard:9500"
echo "Infrastructure (9600-9899): Velociraptor:9600, Portainer:9700, GRR:9800"
echo "Proxy Services (8000-8999): NGINX:8080, External access gateway"
echo

echo "=== Network Connectivity Test ==="
for network in btpi-core-network btpi-wazuh-network btpi-infra-network btpi-proxy-network; do
    if docker network ls | grep -q "$network"; then
        gateway=$(docker network inspect $network -f '{{range .IPAM.Config}}{{.Gateway}}{{end}}')
        if ping -c 1 -W 1 "$gateway" >/dev/null 2>&1; then
            echo "✅ $network gateway ($gateway) reachable"
        else
            echo "❌ $network gateway ($gateway) unreachable"
        fi
    fi
done
