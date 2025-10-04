#!/bin/bash
# Fix hanging deployment and restart with Kasm priority

echo "🔧 Fixing hanging BTPI-REACT deployment..."

# Kill any hanging deployment processes
echo "Terminating hanging deployment processes..."
sudo pkill -f "fresh-btpi-react.sh" 2>/dev/null || true
sleep 2

# Show current running containers
echo ""
echo "Current running containers:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo ""
echo "🚀 Ready to restart deployment with fixes applied:"
echo "   - Kasm will deploy first (as requested)"
echo "   - Elasticsearch health check fixed (no more hanging)"
echo "   - Enhanced error handling and skip logic for healthy services"
echo ""
echo "To restart deployment:"
echo "   sudo bash deployment/fresh-btpi-react.sh --mode simple --debug"
echo ""
echo "Services will deploy in this order:"
echo "   1. Kasm (priority)"
echo "   2. Elasticsearch"
echo "   3. Cassandra"
echo "   4. Velociraptor"
echo "   5. Portainer"
