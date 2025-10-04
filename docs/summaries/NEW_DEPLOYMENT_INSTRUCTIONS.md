# Updated Deployment Instructions

## Quick Start

### Prerequisites
- Ubuntu 22.04 LTS (recommended) or Ubuntu 20.04 LTS
- 16GB+ RAM (32GB recommended)
- 8+ CPU cores (16+ recommended)
- 200GB+ available disk space
- Root or sudo access

### Unified Deployment

1. **Clone the repository**:
   ```bash
   git clone https://github.com/d3fend-nexus/btpi-react.git
   cd btpi-react
   ```

2. **Run the unified deployment script**:
   ```bash
   # Full deployment (recommended)
   sudo ./deployment/fresh-btpi-react.sh

   # Simple deployment (no system optimizations)
   sudo ./deployment/fresh-btpi-react.sh --mode simple

   # Custom deployment (specific services)
   sudo ./deployment/fresh-btpi-react.sh --mode custom --services velociraptor,wazuh-manager,elasticsearch,cassandra
   ```

3. **Available options**:
   ```bash
   --mode full|simple|custom  # Deployment mode
   --services LIST            # Comma-separated service list (for custom mode)
   --skip-checks             # Skip system requirements checks
   --skip-optimization       # Skip system optimizations
   --debug                   # Enable debug logging
   --help                    # Show help
   ```

4. **Monitor deployment** (30-45 minutes for full deployment)

5. **Access services** after completion:
   - **Velociraptor**: https://YOUR_SERVER_IP:8889
   - **Wazuh Dashboard**: https://YOUR_SERVER_IP:5601
   - **Portainer**: https://YOUR_SERVER_IP:9443
   - **Kasm Workspaces**: https://YOUR_SERVER_IP:6443
   - **Wazuh Dashboard**: https://YOUR_SERVER_IP:5601
   - **Kasm Workspaces**: https://YOUR_SERVER_IP:6443
   - **Portainer**: https://YOUR_SERVER_IP:9443

### Migration from Old Scripts

The deployment script has been enhanced and unified:
- **Old**: Separate scripts with limited options
- **New**: Single script with multiple deployment modes
- **Enhanced Features**: Better health checking, debugging, and deployment modes

The enhanced script (`deployment/fresh-btpi-react.sh`) now provides all functionality in one place.

### Troubleshooting

- Check logs in `logs/deployment.log`
- Review the deployment report in `logs/deployment_report_*.txt`
- Use `--debug` flag for detailed logging
- See `BTPI-REACT_CONSOLIDATION_SUMMARY.md` for detailed information
