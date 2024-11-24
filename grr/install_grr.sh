# Install Google Rapid Response
cd /opt
git clone https://github.com/google/grr
cd grr*
./docker_config_files/init_certs.sh
rm compose.yaml
wget https://github.com/cmndcntrlcyber/btpi-nexus/grr/compose.yaml > /opt/btpi-nexus/grr/compose.yaml
docker compose up -d
#-------------------------------