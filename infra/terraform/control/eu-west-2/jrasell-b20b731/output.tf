output "message" {
  value = <<-EOM
Your Test Cluster has been provisioned!

Load balancer address: http://${module.jrasell_b20b731_alb.alb_dns_name}

In order to provision the cluster, you can run the following Ansible command:
  cd ../../../../ansible && \
    ansible-playbook -i ./${var.project_name}_inventory.ini ./playbook_client.yaml

To run the Nomad Nodesim job, you can run the following command:
  nomad run -address=http://${module.jrasell_b20b731_alb.alb_dns_name}:80 \
    -var="server_addr=[\"<PRIVATE IP>:4647\"]" \
    ../../../../jobs/nomad-nodesim.nomad.hcl
EOM
}

resource "local_file" "ansible_inventory" {
  content  = <<EOT
[bastion]
${var.bastion_ip}

[bastion:vars]
ansible_user= "ubuntu"
ansible_ssh_private_key_file="${var.ssh_key_path}"
ansible_ssh_common_args='-o StrictHostKeyChecking=no -o IdentitiesOnly=yes'

[server]
%{for serverIP in module.jrasell_b20b731.server_private_ips~}
${serverIP}
%{endfor~}

[client]
%{for serverIP in module.jrasell_b20b731.client_private_ips~}
${serverIP}
%{endfor~}

[server:vars]
ansible_ssh_common_args='-o StrictHostKeyChecking=no -o IdentitiesOnly=yes -o ProxyCommand="ssh -o StrictHostKeyChecking=no -o IdentitiesOnly=yes -i "${var.ssh_key_path}" -W %h:%p -q ubuntu@${var.bastion_ip}"'
ansible_ssh_user="ubuntu"
ansible_ssh_private_key_file="${var.ssh_key_path}"

[client:vars]
ansible_ssh_common_args='-o StrictHostKeyChecking=no -o IdentitiesOnly=yes -o ProxyCommand="ssh -o StrictHostKeyChecking=no -o IdentitiesOnly=yes -i "${var.ssh_key_path}" -W %h:%p -q ubuntu@${var.bastion_ip}"'
ansible_ssh_user="ubuntu"
ansible_ssh_private_key_file="${var.ssh_key_path}"
EOT
  filename = "${path.module}/../../../../ansible/${var.project_name}_inventory.ini"
}
