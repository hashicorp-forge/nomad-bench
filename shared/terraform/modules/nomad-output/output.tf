locals {
  ansible_root_path = var.ansible_root_path != "" ? var.ansible_root_path : abspath("${path.module}../../../../ansible/")
  key_absolute_path = abspath(var.ssh_key_path)
}

resource "local_file" "ansible_inventory" {
  filename = "${local.ansible_root_path}/${var.project_name}_inventory.ini"
  content  = <<EOT
[bastion]
${var.bastion_host_public_ip}

[bastion:vars]
ansible_user= "ubuntu"
ansible_ssh_private_key_file="${local.key_absolute_path}"
ansible_ssh_common_args='-o StrictHostKeyChecking=no -o IdentitiesOnly=yes'

%{if var.nomad_lb_public_ip_address != ""~}
[lb]
${var.nomad_lb_public_ip_address}

[lb:vars]
ansible_user= "ubuntu"
ansible_ssh_private_key_file="${local.key_absolute_path}"
ansible_ssh_common_args='-o StrictHostKeyChecking=no -o IdentitiesOnly=yes'
server_ips=[%{for serverIP in var.nomad_server_private_ips~}"${serverIP}",%{endfor}]
client_ips=[%{for serverIP in var.nomad_client_private_ips~}"${serverIP}",%{endfor}]
%{endif~}

%{if length(var.nomad_server_private_ips) > 0~}
[server]
%{for serverIP in var.nomad_server_private_ips~}
${serverIP}
%{endfor~}

[server:vars]
ansible_ssh_common_args='-o StrictHostKeyChecking=no -o IdentitiesOnly=yes -o ProxyCommand="ssh -o StrictHostKeyChecking=no -o IdentitiesOnly=yes -i "${local.key_absolute_path}" -W %h:%p -q ubuntu@${var.bastion_host_public_ip}"'
ansible_ssh_user="ubuntu"
ansible_ssh_private_key_file="${local.key_absolute_path}"
%{endif~}

%{if length(var.nomad_client_private_ips) > 0~}
[client]
%{for clientIP in var.nomad_client_private_ips~}
${clientIP}
%{endfor~}

[client:vars]
ansible_ssh_common_args='-o StrictHostKeyChecking=no -o IdentitiesOnly=yes -o ProxyCommand="ssh -o StrictHostKeyChecking=no -o IdentitiesOnly=yes -i "${local.key_absolute_path}" -W %h:%p -q ubuntu@${var.bastion_host_public_ip}"'
ansible_ssh_user="ubuntu"
ansible_ssh_private_key_file="${local.key_absolute_path}"
%{endif~}

[all:vars]
project_name="${var.project_name}"
influxdb_telegraf_output_bucket="${var.project_name}"
%{if var.nomad_lb_private_ip_address != ""~}
influxdb_telegraf_output_urls=["http://${var.nomad_lb_private_ip_address}:8086"]
%{endif~}
EOT
}

output "message" {
  value = <<-EOM
Your ${var.project_name} cluster has been provisioned!

%{if var.nomad_lb_public_ip_address != ""~}
The load balancer address where the Nomad UI and API will be available is:
  https://${var.nomad_lb_public_ip_address}
%{endif}
SSH into the bastion host:
  ssh -i ./keys/${var.project_name}.pem ubuntu@${var.bastion_host_public_ip}

SSH into an instance:
  ssh -i ./keys/${var.project_name}.pem -J ubuntu@${var.bastion_host_public_ip} ubuntu@<PRIVATE IP>

Open SSH tunnel to Nomad:
  ssh -i ./keys/${var.project_name}.pem -L 4646:<PRIVATE IP>:4646 ubuntu@${var.bastion_host_public_ip}

In order to provision the cluster, you can run the following command which will trigger the Ansible
playbooks:
  cd ./ansible && \
    ansible-playbook ./playbook_bastion.yaml && \
    ansible-playbook ./playbook_server.yaml && \
    ansible-playbook ./playbook_client.yaml && \
    ansible-playbook ./playbook_lb.yaml && \
    cd ..

CA, Certs, and Keys for Nomad have been provisioned here:
  ${var.tls_certs_root_path}/

In order to connect to the Nomad cluster, you need to setup the following environment variables:
  export NOMAD_ADDR=https://${var.nomad_lb_public_ip_address}:443
  export NOMAD_CACERT="${var.tls_certs_root_path}/nomad-agent-ca.pem"
  export NOMAD_CLIENT_CERT="${var.tls_certs_root_path}/global-client-nomad.pem"
  export NOMAD_CLIENT_KEY="${var.tls_certs_root_path}/global-client-nomad-key.pem"

Once Ansible finishes its run, the Nomad cluster will have ACLs enabled with a default read-only policy.
In order to use the cluster, you can export the NOMAD_TOKEN variable pointing to the bootstrap token:
  export NOMAD_TOKEN=$(cat ../../../../ansible/nomad-token)

%{if var.nomad_lb_public_ip_address != ""~}
If you are deploying InfluxDB to this cluster, the following command can be used to perform the
initial job registration. Once the allocation has been started, the InfluxDB UI will be available
at http://${var.nomad_lb_public_ip_address}:8086. If you need to customize the job via the available
variables, please check the job specificaiton.
  nomad run -var='influxdb_bucket_name=${var.project_name}' ../../../shared/nomad/jobs/influxdb.nomad.hcl
%{endif}

If you are using this environment to test development changes of Nomad, the Ansible scripts include
basic functionality for syncing, building, and using a custom build. It primarliy allows us to use
our workstation IDEs while compiling and running on remote hosts.

To sync your local code with the remote host and build a development binary, you can run the
following Ansible command. You will need to replace the path to the Nomad code, so that it matches
your own setup. The code will be sync'd to the bastion host at "/home/{USER}/nomad" where {USER} is
the username from your local workstation.
  cd ./ansible && \
    ansible-playbook ./playbook_bastion.yaml --extra-vars "build_nomad_local_code_path=/Users/jrasell/Projects/Go/nomad" --tags "never,custom_build" && \
    cd ..

Once the custom binary has been complied and fetched into your local Nomad repository, you can run
the following Ansible command to trigger a deployment. You will need to replace the path to the
Nomad binary, so that it matches your own setup. You can also trigger "playbook_client.yaml" if you
wish to also update the Nomad clients.
  cd ./ansible && \
    ansible-playbook ./playbook_server.yaml --extra-vars "nomad_custom_binary_source=/Users/jrasell/Projects/Go/nomad/pkg/linux_amd64/nomad" --tags "never,custom_build" && \
    cd ..
EOM
}
