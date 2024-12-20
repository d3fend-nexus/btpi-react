#!/bin/bash
# Install Google Rapid Response
cd /opt
git clone https://github.com/google/grr
cd grr*
./docker_config_files/init_certs.sh
rm compose.yaml
curl https://raw.githubusercontent.com/cmndcntrlcyber/btpi-react/refs/heads/main/grr/compose.yaml > /opt/grr/compose.yaml
docker compose up -d
#-------------------------------