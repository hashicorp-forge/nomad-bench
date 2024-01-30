output "message" {
  value = <<-EOM
Your cluster has been provisioned!

Load balancer address: ${aws_lb.nomad_lb.dns_name}

SSH into the bastion host:
ssh -i keys/${local.random_name}.pem ubuntu@${aws_instance.bastion.public_ip}

In order to provision the cluster, you can run the following Ansible command:
ansible-playbook -i ./ansible/${local.random_name}_inventory.ini ./ansible/playbook_client.yaml

To run the Nomad Nodesim job, you can run the following command:
nomad run -address=http://${aws_lb.nomad_lb.dns_name}:80 -var="server_addr=[\"${aws_instance.nomad_server.0.private_ip}:4647\"]" jobs/nomad-nodesim.nomad.hcl
EOM
}

resource "local_file" "ansible_inventory" {
  content  = <<EOT
[bastion]
${aws_instance.bastion.public_ip}

[bastion:vars]
ansible_user= "ubuntu"
ansible_ssh_private_key_file="${path.root}/keys/${local.random_name}.pem"

[server]
%{for serverIP in aws_instance.nomad_server.*.private_ip~}
${serverIP}
%{endfor~}

[server:vars]
ansible_ssh_common_args='-o StrictHostKeyChecking=no -o ProxyCommand="ssh -i ${path.root}/keys/${local.random_name}.pem -W %h:%p -q ubuntu@${aws_instance.bastion.public_ip}"'
ansible_ssh_user="ubuntu"
ansible_ssh_private_key_file="${path.root}/keys/${local.random_name}.pem"

[client]
%{for clientIP in aws_instance.nomad_client.*.private_ip~}
${clientIP}
%{endfor~}

[client:vars]
ansible_ssh_common_args='-o StrictHostKeyChecking=no -o ProxyCommand="ssh -i ${path.root}/keys/${local.random_name}.pem -W %h:%p -q ubuntu@${aws_instance.bastion.public_ip}"'
ansible_ssh_user="ubuntu"
ansible_ssh_private_key_file="${path.root}/keys/${local.random_name}.pem"
EOT
  filename = "${path.module}/ansible/${local.random_name}_inventory.ini"
}
