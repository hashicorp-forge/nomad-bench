output "message" {
  value = <<EOF
Your test clusters have been provisioned!

Run the Ansible playbook to configure them.
  cd ./ansible && ansible-playbook ./playbook.yaml && cd ..

Use the variables file in the nodesim-vars directory to run nodesim jobs.
%{for cluster_name, cluster in module.clusters~}
  nomad run -var-file=./nodesim-vars/${cluster_name}.hcl ../../../shared/nomad/jobs/nomad-nodesim.nomad.hcl
%{endfor~}
EOF
}
