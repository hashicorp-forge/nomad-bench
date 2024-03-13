output "message" {
  value = <<EOF
Your test clusters have been provisioned!

Run the Ansible playbook to configure them.
  cd ./ansible && ansible-playbook ./playbook.yaml && cd ..

Customize and run the nodesim job for each test cluster.
%{for cluster_name, cluster in module.clusters~}
  nomad run ./jobs/nomad-nodesim-${cluster_name}.nomad.hcl
%{endfor~}
EOF
}
