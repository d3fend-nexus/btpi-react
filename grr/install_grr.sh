# Install Google Rapid Response
cd /opt
git clone https://github.com/google/grr
cd grr*
./docker_config_files/init_certs.sh
sed -i 's/ports:\s*-\s*"8000:8000"/ports:\n  - "8500:8000"/; s/expose:\s*-\s*"8000"/expose:\n  - "8500"/' compose.yaml
docker compose up -d
#-------------------------------