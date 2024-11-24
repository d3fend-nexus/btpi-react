#!/bin/sh
ACCEPT_EULA=y
cd /tmp
curl -O https://kasm-static-content.s3.amazonaws.com/kasm_release_1.16.1.98d6fa.tar.gz
curl -O https://kasm-static-content.s3.amazonaws.com/kasm_release_service_images_amd64_1.16.1.98d6fa.tar.gz
curl -O https://kasm-static-content.s3.amazonaws.com/kasm_release_workspace_images_amd64_1.16.1.98d6fa.tar.gz
tar -xf kasm_release_1.16.1.98d6fa.tar.gz
sudo echo $ACCEPT_EULA | bash kasm_release/install.sh --role db --database-user reactor --database-name btpi_react --offline-workspaces /tmp/kasm_release_workspace_images_amd64_1.16.1.98d6fa.tar.gz --offline-service /tmp/kasm_release_service_images_amd64_1.16.1.98d6fa.tar.gz