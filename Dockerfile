FROM docker:dind

EXPOSE 22 443 3000 6901 8000 8500 9443

VOLUME ["/var/run", "/var/lib/docker/volumes", "/portainer_data"]

RUN apk update
RUN apk upgrade

RUN apk add bash
RUN apk add nano
RUN apk add curl
RUN apk add wget

#-------------------------------
#Configure kubectl, helm and k3d
#RUN curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash; exit 0
#RUN curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" && chmod +x ./kubectl && mv ./kubectl /usr/local/bin/kubectl; exit 0
#RUN curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/arm64/kubectl" && chmod +x ./kubectl && mv ./kubectl /usr/local/bin/kubectl; exit 0
#RUN curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash && helm repo add stable https://charts.helm.sh/stable && helm repo add gitlab https://charts.gitlab.io/; exit 0
#RUN wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | tee /usr/share/keyrings/hashicorp-archive-keyring.gpg && echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashicorp.list && apk update && apk add terraform; exit 0
#WORKDIR "/usr/local"
#RUN curl -L https://dl.dagger.io/dagger/install.sh | sh
#WORKDIR "/opt"
#-------------------------------

#-------------------------------
# Install portainer
WORKDIR "/opt"
RUN apk add bash tar wget
RUN wget https://github.com/cmndcntrlcyber/btpi-nexus/grr/install_grr.sh > /opt/btpi-nexus/install_portainer.sh
RUN bash /opt/btpi-nexus/install_portainer.sh

#RUN docker run -d -p 8000:8000 -p 9443:9443 --name portainer --restart=always -v /var/run/docker.sock:/var/run/docker.sock -v portainer_data:/data portainer/portainer-ce:2.21.0

#-------------------------------
## Install Kasm
# Set up environment for Kasm installation
WORKDIR /tmp
# Add necessary tools
RUN apk add bash tar wget

## Automated Install
RUN wget https://github.com/cmndcntrlcyber/btpi-nexus/kasm/install_kasm.sh > /opt/btpi-nexus/install_kasm.sh
RUN bash /opt/btpi-nexus/install_kasm.sh

## Manual Install
# Download required files
#RUN curl -fLO https://kasm-static-content.s3.amazonaws.com/kasm_release_1.15.0.06fdc8.tar.gz
#RUN curl -fLO https://kasm-static-content.s3.amazonaws.com/kasm_release_workspace_images_amd64_1.15.0.06fdc8.tar.gz
#RUN curl -fLO https://kasm-static-content.s3.amazonaws.com/kasm_release_service_images_amd64_1.15.0.06fdc8.tar.gz

# Verify downloads
#RUN sha256sum /tmp/*.tar.gz

# Extract release tarball
#RUN tar -xf kasm_release_1.15.0.06fdc8.tar.gz

# Debugging: Check the directory structure
#RUN ls -la ./kasm_release/

# Ensure the installer script is executable
#RUN chmod +x ./kasm_release/install.sh

# Set the environment variable to accept the EULA
#ENV ACCEPT_EULA=y

# Run the installation script with the necessary parameters
#RUN echo $ACCEPT_EULA | bash -x ./kasm_release/install.sh --offline-workspaces /tmp/kasm_release_workspace_images_amd64_1.15.0.06fdc8.tar.gz --offline-service /tmp/kasm_release_service_images_amd64_1.15.0.06fdc8.tar.gz
#---------------------------------

#---------------------------------
# Install Google Rapid Response
WORKDIR "/opt"
RUN apk add bash tar wget

## Automated Install
RUN wget https://github.com/cmndcntrlcyber/btpi-nexus/grr/install_grr.sh > /opt/btpi-nexus/install_grr.sh
RUN bash /opt/btpi-nexus/install_grr.sh

## Manual Install
#RUN git clone https://github.com/google/grr
#RUN cd grr*
#RUN ./docker_config_files/init_certs.sh
#RUN sed -i 's/ports:\s*-\s*"8000:8000"/ports:\n  - "8500:8000"/; s/expose:\s*-\s*"8000"/expose:\n  - "8500"/' compose.yaml
#RUN docker compose up -d
#-------------------------------

#-------------------------------
# Install Safeline WAF
#WORKDIR "/opt"
#RUN mkdir -p "/data/safeline"
#RUN cd "/data/safeline"
#RUN wget "https://waf.chaitin.com/release/latest/compose.yaml"
#RUN cd "/data/safeline"
#RUN touch ".env"
#RUN echo "SAFELINE_DIR=/data/safeline" >> ".env"
#RUN echo "SAFELINE_DIR=/data/safeline" >> ".env"
#RUN echo "IMAGE_TAG=latest" >> ".env"
#RUN echo "MGT_PORT=10443" >> ".env"
#RUN echo "POSTGRES_PASSWORD= `BTPI-N3xu5-P@55`" >> ".env"
#RUN echo "SUBNET_PREFIX=172.17.0" >> ".env"
#RUN echo "IMAGE_PREFIX=chaitin" >> ".env"
#RUN echo "RELEASE=lts" >> ".env"
#RUN docker compose up -d
#RUN docker exec safeline-mgt resetadmin
#--------------------------------
