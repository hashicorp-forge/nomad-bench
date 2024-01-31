output "message" {
  value = <<-EOM
Your cluster has been provisioned!

Load balancer address: ${aws_lb.alb.dns_name}

SSH into the bastion host:
  ssh -i ./keys/${local.project_name}.pem ubuntu@${aws_instance.bastion.public_ip}

SSH into instance:
  ssh -i ./keys/${local.project_name}.pem -J ubuntu@${aws_instance.bastion.public_ip} ubuntu@<PRIVATE IP>

Open SSH tunnel to Nomad:
  ssh -i ./keys/${local.project_name}.pem -L 4646:<PRIVATE IP>:4646 ubuntu@${aws_instance.bastion.public_ip}

In order to provision the cluster, you can run the following Ansible command:
  cd ../../ansible && ansible-playbook -i ./${local.project_name}_inventory.ini ./playbook_client.yaml

To run the Nomad Nodesim job, you can run the following command:
  nomad run -address=http://${aws_lb.alb.dns_name}:80 -var="server_addr=[\"<PRIVATE IP>:4647\"]" jobs/nomad-nodesim.nomad.hcl

Test clusters:
%{for cluster in local.test_clusters~}
  * ${cluster.name}
    Servers:
%{for serverIP in cluster.server_private_ips~}
      * ${serverIP}
%{endfor~}
%{if length(cluster.client_private_ips) > 0~}
    Clients:
%{for clientIP in cluster.client_private_ips~}
      * ${clientIP}
%{endfor~}
%{endif~}

%{endfor~}
EOM
}

resource "local_file" "ansible_inventory" {
  content  = <<EOT
[bastion]
${aws_instance.bastion.public_ip}

[bastion:vars]
ansible_user= "ubuntu"
ansible_ssh_private_key_file="${abspath(path.root)}/keys/${local.project_name}.pem"
ansible_ssh_common_args='-o StrictHostKeyChecking=no -o IdentitiesOnly=yes'

[control_server]
%{for serverIP in module.control_cluster.server_private_ips~}
${serverIP}
%{endfor~}

[control_client]
%{for clientIP in module.control_cluster.client_private_ips~}
${clientIP}
%{endfor~}

%{for cluster in local.test_clusters~}
[${replace(cluster.name, "-", "_")}_server]
%{for serverIP in cluster.server_private_ips~}
${serverIP}
%{endfor~}

[${replace(cluster.name, "-", "_")}_client]
%{for clientIP in cluster.client_private_ips~}
${clientIP}
%{endfor~}

%{endfor~}

[server:children]
control_server
%{for cluster in local.test_clusters~}
${replace(cluster.name, "-", "_")}_server
%{endfor~}

[server:vars]
ansible_ssh_common_args='-o StrictHostKeyChecking=no -o IdentitiesOnly=yes -o ProxyCommand="ssh -o StrictHostKeyChecking=no -o IdentitiesOnly=yes -i ${abspath(path.root)}/keys/${local.project_name}.pem -W %h:%p -q ubuntu@${aws_instance.bastion.public_ip}"'
ansible_ssh_user="ubuntu"
ansible_ssh_private_key_file="${abspath(path.root)}/keys/${local.project_name}.pem"

[client:children]
control_client
%{for cluster in local.test_clusters~}
${replace(cluster.name, "-", "_")}_client
%{endfor~}

[client:vars]
ansible_ssh_common_args='-o StrictHostKeyChecking=no -o IdentitiesOnly=yes -o ProxyCommand="ssh -o StrictHostKeyChecking=no -o IdentitiesOnly=yes -i ${abspath(path.root)}/keys/${local.project_name}.pem -W %h:%p -q ubuntu@${aws_instance.bastion.public_ip}"'
ansible_ssh_user="ubuntu"
ansible_ssh_private_key_file="${abspath(path.root)}/keys/${local.project_name}.pem"
EOT
  filename = "${path.module}/../../ansible/${local.project_name}_inventory.ini"
}
