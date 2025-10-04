#!/bin/bash
# Fix Docker commands to show live output
# This script fixes the Docker commands to show pull progress and container creation

set -euo pipefail

echo "Fixing Docker commands for live output..."

# Function to fix docker run commands in a file
fix_docker_commands() {
    local file="$1"

    if [ ! -f "$file" ]; then
        echo "Warning: $file not found"
        return
    fi

    echo "Fixing Docker commands in $(basename $file)..."

    # Remove the incorrect --progress=plain flag that was added
    sed -i 's/docker run --progress=plain -d/docker run -d/g' "$file"

    # Add explicit docker pull before docker run to show progress
    # Find all docker run commands and add a docker pull before them
    awk '
    /docker run -d/ {
        # Extract the image name from the docker run command
        if (match($0, /docker\.elastic\.co\/elasticsearch\/elasticsearch:[^ ]+/)) {
            image = substr($0, RSTART, RLENGTH)
            print "    log_info \"Pulling Docker image: " image "...\""
            print "    docker pull " image
        }
        else if (match($0, /cassandra:[^ ]+/)) {
            image = substr($0, RSTART, RLENGTH)
            print "    log_info \"Pulling Docker image: " image "...\""
            print "    docker pull " image
        }
        else if (match($0, /wazuh\/wazuh-indexer:[^ ]+/)) {
            image = substr($0, RSTART, RLENGTH)
            print "    log_info \"Pulling Docker image: " image "...\""
            print "    docker pull " image
        }
        else if (match($0, /kasmweb\/[^:]+:[^ ]+/)) {
            image = substr($0, RSTART, RLENGTH)
            print "    log_info \"Pulling Docker image: " image "...\""
            print "    docker pull " image
        }
        else if (match($0, /portainer\/portainer-ce:[^ ]+/)) {
            image = substr($0, RSTART, RLENGTH)
            print "    log_info \"Pulling Docker image: " image "...\""
            print "    docker pull " image
        }
        print "    log_info \"Creating container...\""
    }
    { print }
    ' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
}

# Fix all service deployment scripts
echo "=== Fixing Service Deployment Scripts ==="
for script in services/*/deploy.sh; do
    if [ -f "$script" ]; then
        fix_docker_commands "$script"
    fi
done

# Add more verbose output to the deploy_infrastructure function
echo "=== Adding more verbose output to deployment functions ==="
if [ -f "deployment/fresh-btpi-react.sh" ]; then
    # Add immediate output when entering the loop
    sed -i '/for service in "${DATABASE_DEPLOYMENT_ORDER\[@\]}"; do/a\        echo "[DEPLOY] Processing service from DATABASE_DEPLOYMENT_ORDER: $service"' deployment/fresh-btpi-react.sh

    # Add output before calling deploy_service
    sed -i '/deploy_service "$service"/i\        echo "[DEPLOY] About to call deploy_service for: $service"' deployment/fresh-btpi-react.sh
fi

echo ""
echo "=== Docker output fixes applied! ==="
echo ""
echo "Changes made:"
echo "1. Removed invalid --progress=plain flag from docker run commands"
echo "2. Added explicit 'docker pull' before 'docker run' to show download progress"
echo "3. Added log messages before pulling images and creating containers"
echo "4. Added more verbose output in deployment loops"
echo ""
