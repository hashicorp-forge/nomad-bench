# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

output "message" {
  value = <<EOF
Your test clusters have been provisioned!

Run the Ansible playbook to configure them.
  cd ./ansible && ansible-playbook ./playbook.yaml && cd ..

Customize and run the nodesim job for each test cluster.
%{for cluster_name, cluster in module.clusters~}
  nomad run ./jobs/nomad-nodesim-${cluster_name}.nomad.hcl
%{endfor~}

Customize and run the GC job for each test cluster.
%{for cluster_name, cluster in module.clusters~}
  nomad run ./jobs/nomad-gc-${cluster_name}.nomad.hcl
%{endfor~}

Customize and run the load job for each test cluster.
%{for cluster_name, cluster in module.clusters~}
  nomad run ./jobs/nomad-load-${cluster_name}.nomad.hcl
%{endfor~}

Use the following commands to SSH into servers.
%{for cluster in keys(module.clusters)~}
  ${cluster}:
%{for server in module.clusters[cluster].server_private_ips~}
    ssh -i ${local_sensitive_file.ssh_key.filename} -J ubuntu@${data.terraform_remote_state.core.outputs.bastion_ip} ubuntu@${server}
%{endfor~}
%{endfor~}

Or open an SSH tunnel to Nomad.
%{for cluster in keys(module.clusters)~}
  ${cluster}:
%{for server in module.clusters[cluster].server_private_ips~}
    ssh -i ${local_sensitive_file.ssh_key.filename} -NL 4646:${server}:4646 ubuntu@${data.terraform_remote_state.core.outputs.bastion_ip}
%{endfor~}
%{endfor~}

Run the Ansible playbook with the following arguments to build and deploy a
custom binary.
  ansible-playbook --tags custom_build --extra-vars build_nomad_local_code_path=<PATH TO NOMAD SOURCE> playbook.yaml
EOF
}
