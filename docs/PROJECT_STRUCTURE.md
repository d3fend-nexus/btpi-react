# BTPI-REACT Project Structure

This document describes the reorganized structure of the BTPI-REACT project after the comprehensive tidying and reorganization completed on September 5, 2025.

## Overview

The project has been reorganized for better maintainability, clearer separation of concerns, and improved developer experience. All files are now logically grouped and archived content has been properly separated from active components.

## Directory Structure

```
btpi-react/
├── README.md                          # Main project documentation
├── LICENSE                            # Project license
├── Dockerfile                         # Main Docker configuration
├── healthcheck.sh                     # Health check script
├── .gitignore                         # Git ignore rules
│
├── deployment/                        # All deployment scripts
│   ├── fresh-btpi-react.sh           # Main deployment script (UPDATED PATHS)
│   ├── deploy-btpi-unified.sh        # Unified deployment script
│   ├── deploy-btpi-simple.sh         # Simple deployment script
│   ├── complete-consolidation.sh     # Consolidation script
│   └── archive/                       # Deprecated deployment scripts
│       ├── deploy-btpi-simple.sh.deprecated
│       └── fresh-btpi-react.sh.deprecated
│
├── docs/                              # Consolidated documentation
│   ├── DEPLOYMENT_GUIDE.md           # Comprehensive deployment guide
│   ├── PROJECT_STRUCTURE.md          # This document
│   ├── architecture/                 # Architecture documentation
│   │   └── BTPI-REACT_Deployment_Architecture.html
│   ├── planning/                     # Planning documents
│   │   ├── Claude New Plans.md
│   │   └── OpenAI New Plans.md
│   └── summaries/                    # Project summaries
│       ├── BTPI-REACT_CONSOLIDATION_SUMMARY.md
│       ├── BTPI-REACT_OPTIMIZATION_SUMMARY.md
│       ├── DEPLOYMENT_FIXES_SUMMARY.md
│       └── NEW_DEPLOYMENT_INSTRUCTIONS.md
│
├── config/                           # Centralized configuration
│   ├── .env                         # Environment variables (generated)
│   ├── application.conf             # Application configuration
│   ├── elasticsearch.yml           # Elasticsearch config
│   ├── jvm.options                 # JVM options
│   ├── opensearch.yml              # OpenSearch config
│   ├── server.cert                 # Server certificate
│   ├── server.config.yaml          # Server configuration
│   ├── analyzers/                  # (Removed - Cortex analyzer configurations)
│   ├── responders/                 # (Removed - Cortex responder configurations)
│   ├── global/                     # Global configurations
│   ├── services/                   # Service-specific configurations
│   └── [service-directories]/      # Individual service configs
│
├── services/                        # Service deployment scripts and configs
│   ├── cassandra/                  # Cassandra database service
│   │   ├── deploy.sh
│   │   ├── healthcheck.sh
│   │   ├── config/
│   │   ├── init-scripts/
│   │   └── archive/                # Backup files moved here
│   ├── cortex/                     # (Removed - Cortex analysis engine)
│   ├── elasticsearch/              # Elasticsearch search engine
│   │   ├── deploy.sh
│   │   ├── config/
│   │   ├── templates/
│   │   └── archive/
│   ├── integrations/               # Service integration scripts
│   ├── thehive/                    # (Removed - TheHive SIRP)
│   ├── velociraptor/               # Velociraptor DFIR
│   │   ├── deploy.sh
│   │   ├── config/
│   │   └── archive/
│   ├── wazuh-indexer/              # Wazuh indexer service
│   │   ├── deploy.sh
│   │   ├── certs/
│   │   ├── config/
│   │   ├── templates/
│   │   └── archive/
│   ├── wazuh-manager/              # Wazuh manager service
│   │   ├── deploy.sh
│   │   └── archive/
│   └── [other-services]/           # Other service directories
│
├── scripts/                        # Utility and management scripts
│   ├── common-utils.sh             # Common utility functions
│   ├── docker-health-check.sh      # Docker health monitoring
│   ├── docker-health-monitor.service # Systemd service file
│   ├── docker-health-monitor.timer   # Systemd timer file
│   ├── cleanup-networks.sh         # Network cleanup utilities
│   ├── inspect-networks.sh         # Network inspection tools
│   ├── install-docker-monitoring.sh # Docker monitoring setup
│   ├── network-isolation-setup.sh  # Network isolation configuration
│   ├── test-network-isolation.sh   # Network isolation testing
│   ├── health-monitoring/          # Health monitoring scripts
│   └── network/                    # Network management scripts
│
├── tests/                          # All test scripts
│   ├── integration-tests.sh        # Main integration test suite
│   ├── test-elasticsearch-connectivity.sh
│   ├── test-enhanced-detection.sh
│   ├── test-port-fix.sh
│   ├── test-wazuh-indexer-detection.sh
│   ├── connectivity/               # Connectivity tests
│   └── system/                     # System-level tests
│
├── data/                           # Runtime data storage
├── logs/                           # Log files
├── backups/                        # Backup storage
├── templates/                      # Template files
├── init-scripts/                   # Initialization scripts
├── img/                           # Images and assets
│
└── archive/                       # Archived/deprecated content
    ├── legacy/                    # Legacy components
    └── redundant-directories/     # Moved redundant directories
        ├── grr/                   # GRR components (archived)
        ├── kasm/                  # Kasm build scripts (archived)
        ├── portainer/             # Portainer build scripts (archived)
        ├── Velociraptor/          # Old Velociraptor directory
        ├── wazuh/                 # Old Wazuh directory
        ├── legacy/                # Old legacy directory
        └── root-code/             # Root code directory
```

## Key Changes Made

### 1. **Deployment Scripts Organization**
- **Before**: Scripts scattered in root directory
- **After**: All deployment scripts moved to `deployment/` directory
- **Updated**: Path references in `fresh-btpi-react.sh` to work from new location

### 2. **Documentation Consolidation**
- **Before**: Documentation files scattered in root
- **After**: All documentation organized in `docs/` with logical subdirectories:
  - `architecture/` - Architecture diagrams and documentation
  - `planning/` - Planning and design documents
  - `summaries/` - Project summary documents

### 3. **Configuration Reorganization**
- **Before**: Duplicate configs in root and service directories
- **After**: Centralized configuration structure:
  - `config/analyzers/` - Analyzer configurations
  - `config/responders/` - Responder configurations
  - `config/global/` - Global configurations
  - `config/services/` - Service-specific configurations

### 4. **Test Script Consolidation**
- **Before**: Test scripts mixed in root directory
- **After**: All tests moved to `tests/` directory with subdirectories:
  - `connectivity/` - Connection and networking tests
  - `system/` - System-level tests

### 5. **Service Directory Standardization**
- **Consistent Structure**: All services now follow the same pattern:
  - `deploy.sh` - Deployment script
  - `config/` - Service-specific configuration
  - `archive/` - Backup and deprecated files
- **Backup Organization**: All `.backup` files moved to service-specific `archive/` directories

### 6. **Archive Management**
- **Redundant Directories**: Moved old directories to `archive/redundant-directories/`
- **Deprecated Scripts**: Organized in `deployment/archive/`
- **Legacy Content**: Properly archived and separated

## Path Updates Made

### Main Deployment Script
The `deployment/fresh-btpi-react.sh` script has been updated with corrected path references:

```bash
# Old paths (when script was in root)
CONFIG_DIR="${SCRIPT_DIR}/config"
SERVICES_DIR="${SCRIPT_DIR}/services"

# New paths (script now in deployment/)
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
CONFIG_DIR="${PROJECT_ROOT}/config"
SERVICES_DIR="${PROJECT_ROOT}/services"
```

## Usage Instructions

### Running Deployments
```bash
# Main deployment (run from project root)
sudo ./deployment/fresh-btpi-react.sh

# Alternative deployment methods
sudo ./deployment/deploy-btpi-unified.sh
sudo ./deployment/complete-consolidation.sh
```

### Running Tests
```bash
# Integration tests
./tests/integration-tests.sh

# Specific connectivity tests
./tests/test-elasticsearch-connectivity.sh
./tests/test-wazuh-indexer-detection.sh
```

### Accessing Documentation
- **Main Guide**: `docs/DEPLOYMENT_GUIDE.md`
- **Architecture**: `docs/architecture/`
- **Project Structure**: `docs/PROJECT_STRUCTURE.md` (this file)

## Benefits of the New Structure

### 1. **Improved Maintainability**
- Clear separation of concerns
- Consistent directory structures
- Logical grouping of related files

### 2. **Better Developer Experience**
- Easy to find files
- Reduced root directory clutter
- Clear project organization

### 3. **Enhanced Scalability**
- Structured approach supports future growth
- Consistent patterns for adding new services
- Proper archive management

### 4. **Professional Appearance**
- Clean, organized structure
- Industry-standard organization
- Improved project credibility

## File Locations Quick Reference

| Component | Old Location | New Location |
|-----------|--------------|--------------|
| Deployment Scripts | Root directory | `deployment/` |
| Test Scripts | Root directory | `tests/` |
| Documentation | Root directory | `docs/` |
| Planning Files | Root directory | `docs/planning/` |
| Summary Documents | Root directory | `docs/summaries/` |
| Analyzer Configs | `analyzers-config/` | `config/analyzers/` |
| Responder Configs | `responders-config/` | `config/responders/` |
| Backup Files | Throughout services | `services/*/archive/` |
| Legacy Directories | Root directory | `archive/redundant-directories/` |

## Next Steps

1. **Update any external references** to the old file locations
2. **Update CI/CD pipelines** if they reference old paths
3. **Update documentation links** in external systems
4. **Verify all deployment scripts** work correctly with new paths
5. **Update team documentation** with new project structure

This reorganization provides a solid foundation for future development and maintenance of the BTPI-REACT project.
