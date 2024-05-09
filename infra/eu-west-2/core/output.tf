# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

output "message" {
  value = <<-EOM
Your ${var.project_name} cluster has been provisioned!

The load balancer address where the Nomad UI and API will be available is:
  https://${module.core_cluster_lb.lb_public_ip}

Extract mTLS certificates and SSH key from state:
  make

Run the Ansible playbook to configure the VMs:
  cd ./ansible && ansible-playbook ./playbook.yaml && cd ..

Export the environment variables necessary to access the Nomad cluster:
  export NOMAD_ADDR=https://${module.core_cluster_lb.lb_public_ip}:443
  export NOMAD_CACERT="$PWD/tls/nomad-agent-ca.pem"

If this is a new cluster, bootstrap the ACL system and store the token
somewhere safe. Export it as the NOMAD_TOKEN environment variable.

Use the core-nomad infrastructure folder to configure the Nomad cluster.

Use the following commands to SSH into hosts:
  Bastion:
    ssh -i ./keys/${var.project_name}.pem ubuntu@${module.bastion.public_ip}
  Load Balancer:
    ssh -i ./keys/${var.project_name}.pem ubuntu@${module.core_cluster_lb.lb_public_ip}
  Nomad servers:
%{for ip in module.core_cluster.server_private_ips~}
    ssh -i ./keys/${var.project_name}.pem -J ubuntu@${module.bastion.public_ip} ubuntu@${ip}
%{endfor~}
  Nomad clients:
%{for ip in module.core_cluster.client_private_ips~}
    ssh -i ./keys/${var.project_name}.pem -J ubuntu@${module.bastion.public_ip} ubuntu@${ip}
%{endfor~}
EOM
}

output "ami_id" {
  value = data.aws_ami.ubuntu.id
}

output "ssh_key" {
  value     = module.ssh.private_key_pem
  sensitive = true
}

output "ssh_key_name" {
  value = module.ssh.key_name
}

output "ca_cert" {
  value     = module.tls.ca_cert
  sensitive = true
}

output "ca_key" {
  value     = module.tls.ca_key
  sensitive = true
}

output "server_cert" {
  value     = module.tls.certs.server
  sensitive = true
}

output "server_key" {
  value     = module.tls.keys.server
  sensitive = true
}

output "client_cert" {
  value     = module.tls.certs.client
  sensitive = true
}

output "client_key" {
  value     = module.tls.keys.client
  sensitive = true
}

output "cli_cert" {
  value     = module.tls.certs.cli
  sensitive = true
}

output "cli_key" {
  value     = module.tls.keys.cli
  sensitive = true
}

output "influxdb_token" {
  value     = random_password.influxdb_token.result
  sensitive = true
}

output "private_subnet_ids" {
  value = module.network.private_subnet_ids
}

output "security_group_id" {
  value = module.network.nomad_security_group_id
}

output "lb_private_ip" {
  value = module.core_cluster_lb.lb_private_ip
}

output "lb_public_ip" {
  value = module.core_cluster_lb.lb_public_ip
}

output "bastion_ip" {
  value = module.bastion.public_ip
}
