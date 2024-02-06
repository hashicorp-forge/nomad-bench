output "message" {
  value = <<-EOM
Your Control Cluster has been provisioned!

Load balancer address: http://${module.core_cluster_lb.lb_dns_name}

SSH into the bastion host:
  ssh -i ./keys/${var.project_name}.pem ubuntu@${module.bastion.public_ip}

SSH into instance:
  ssh -i ./keys/${var.project_name}.pem -J ubuntu@${module.bastion.public_ip} ubuntu@<PRIVATE IP>

Open SSH tunnel to Nomad:
  ssh -i ./keys/${var.project_name}.pem -L 4646:<PRIVATE IP>:4646 ubuntu@${module.bastion.public_ip}

In order to provision the cluster, you can run the following Ansible command:
  cd ../../../../ansible && \
    ansible-playbook -i ./${var.project_name}_control_inventory.ini ./playbook_client.yaml

If you are deploying Traefik and InfluxDB to this cluster, the following commands can be used to
perform the initial job registrations. Once the allocations have been started, Traefik will be
available on your LB at port 8080, and InfluxDB at port 8086. If you need to customize any of
the jobs via the available variables, please check the job specificaitons.
  nomad run -address=http://${module.core_cluster_lb.lb_dns_name}:80 ../../../../jobs/traefik.nomad.hcl
  nomad run -address=http://${module.core_cluster_lb.lb_dns_name}:80 ../../../../jobs/influxdb.nomad.hcl
EOM
}

output "bench_cluster_vars" {
  value = <<-EOM
The following variables can be copied into your bench cluster terraform.tfvars file. This
will allow you to build and provision a cluster for benchmarking.

ssh_key_path = "${abspath(path.root)}/keys/${var.project_name}.pem"
bastion_ip   = "${module.bastion.public_ip}"

vpc_id             = "${module.network.vpc_id}"
vpc_cidr_block     = "${module.network.vpc_cidr_block}"
private_subnet_ids = [
  %{for id in module.network.private_subnet_ids~}"${id}",
  %{endfor~}]
public_subnet_ids  =  [
  %{for id in module.network.public_subnet_ids~}"${id}",
  %{endfor~}]
nomad_security_group_id = "${module.network.nomad_security_group_id}"
EOM
}

resource "local_file" "ansible_inventory" {
  content  = <<EOT
[bastion]
${module.bastion.public_ip}

[bastion:vars]
ansible_user= "ubuntu"
ansible_ssh_private_key_file="${abspath(path.root)}/keys/${var.project_name}.pem"
ansible_ssh_common_args='-o StrictHostKeyChecking=no -o IdentitiesOnly=yes'

[core_server]
%{for serverIP in module.core_cluster.server_private_ips~}
${serverIP}
%{endfor~}

[core_client]
%{for clientIP in module.core_cluster.client_private_ips~}
${clientIP}
%{endfor~}

[server:children]
core_server

[client:children]
core_client

[server:vars]
ansible_ssh_common_args='-o StrictHostKeyChecking=no -o IdentitiesOnly=yes -o ProxyCommand="ssh -o StrictHostKeyChecking=no -o IdentitiesOnly=yes -i ${abspath(path.root)}/keys/${var.project_name}.pem -W %h:%p -q ubuntu@${module.bastion.public_ip}"'
ansible_ssh_user="ubuntu"
ansible_ssh_private_key_file="${abspath(path.root)}/keys/${var.project_name}.pem"

[client:vars]
ansible_ssh_common_args='-o StrictHostKeyChecking=no -o IdentitiesOnly=yes -o ProxyCommand="ssh -o StrictHostKeyChecking=no -o IdentitiesOnly=yes -i ${abspath(path.root)}/keys/${var.project_name}.pem -W %h:%p -q ubuntu@${module.bastion.public_ip}"'
ansible_ssh_user="ubuntu"
ansible_ssh_private_key_file="${abspath(path.root)}/keys/${var.project_name}.pem"
EOT
  filename = "${path.module}/../../../../ansible/${var.project_name}_control_inventory.ini"
}
