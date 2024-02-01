#!/bin/bash -xe
wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | tee /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashicorp.list
apt update && apt install -y --no-install-recommends \
    docker.io \
    nomad \
    podman \
    tzdata

cat > /etc/nomad.d/nomad.hcl <<EOF
${nomad_conf}
EOF

systemctl daemon-reload
systemctl enable nomad
systemctl restart nomad
