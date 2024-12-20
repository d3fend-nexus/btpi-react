## Install Kasm
# Set up environment for Kasm installation
cd /tmp

# Add necessary tools
apk add bash tar

# Download required files
curl -fLO https://kasm-static-content.s3.amazonaws.com/kasm_release_1.15.0.06fdc8.tar.gz
curl -fLO https://kasm-static-content.s3.amazonaws.com/kasm_release_workspace_images_amd64_1.15.0.06fdc8.tar.gz
curl -fLO https://kasm-static-content.s3.amazonaws.com/kasm_release_service_images_amd64_1.15.0.06fdc8.tar.gz

# Verify downloads
sha256sum /tmp/*.tar.gz

# Extract release tarball
tar -xf kasm_release_1.15.0.06fdc8.tar.gz

# Debugging: Check the directory structure
ls -la ./kasm_release/

# Ensure the installer script is executable
chmod +x ./kasm_release/install.sh

# Set the environment variable to accept the EULA
ACCEPT_EULA=y

# Run the installation script with the necessary parameters
echo $ACCEPT_EULA | bash -x ./kasm_release/install.sh -L 6443 --offline-workspaces /tmp/kasm_release_workspace_images_amd64_1.15.0.06fdc8.tar.gz --offline-service /tmp/kasm_release_service_images_amd64_1.15.0.06fdc8.tar.gz