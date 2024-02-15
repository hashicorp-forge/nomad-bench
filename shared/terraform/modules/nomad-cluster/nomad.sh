#!/bin/bash -xe
wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | tee /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashicorp.list
apt -qq update && apt -qq install -y --no-install-recommends \
    nomad \
    podman \
    tzdata

rm /etc/nomad.d/nomad.hcl

systemctl daemon-reload
systemctl enable nomad
