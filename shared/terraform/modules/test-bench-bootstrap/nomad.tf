locals {
  nomad_nodesim_jobs = { for name, cluster in var.clusters : name => templatefile(
    "${path.module}/nomad-nodesim.nomad.hcl.tpl",
    {
      terraform_job_name      = "nomad-nodesim-${name}"
      terraform_job_namespace = nomad_namespace.nomad_bench.name
      terraform_job_servers   = cluster.server_private_ips
    },
  ) }

  nomad_load_jobs = { for name, cluster in var.clusters : name => templatefile(
    "${path.module}/nomad-load.nomad.hcl.tpl",
    {
      terraform_job_name        = "nomad-load-${name}"
      terraform_job_namespace   = nomad_namespace.nomad_bench.name
      terraform_nomad_addr      = "http://${cluster.server_private_ips[0]}:4646"
      terraform_influxdb_url    = var.influxdb_url
      terraform_influxdb_org    = data.influxdb-v2_organization.influx_org.name
      terraform_influxdb_bucket = influxdb-v2_bucket.clusters[name].name
    },
  ) }
}

resource "nomad_namespace" "nomad_bench" {
  name        = var.project_name
  description = "namespace created by Terraform for ${var.project_name}"
}

resource "terraform_data" "nomad_jobs_nodesim" {
  for_each = var.clusters

  provisioner "local-exec" {
    command = <<EOF
mkdir -p ${path.root}/jobs/
cat <<JOB > ${path.root}/jobs/nomad-nodesim-${each.key}.nomad.hcl
# This file is created by Terraform, but not managed to allow for local edits.
# It will not be recreated if deleted.
#
# Replace the resource to recreate this file.
# WARNING: ALL CHANGES WILL BE LOST.
#   terraform apply -replace 'module.bootstrap.terraform_data.nomad_jobs_nodesim["${each.key}"]'

${local.nomad_nodesim_jobs[each.key]}
JOB

# Hack to get around how Terraform handles ther dollar sign.
sed -i.bkp 's|#{|$${|g' ${path.root}/jobs/nomad-nodesim-${each.key}.nomad.hcl
rm -f ${path.root}/jobs/nomad-nodesim-${each.key}.nomad.hcl.bkp
EOF
  }

  provisioner "local-exec" {
    command = <<EOF
 rm -f ${path.root}/jobs/nomad-nodesim-${each.key}.nomad.hcl
 EOF
    when    = destroy
  }
}

resource "terraform_data" "nomad_jobs_load" {
  for_each = var.clusters

  provisioner "local-exec" {
    command = <<EOF
mkdir -p ${path.root}/jobs/
cat <<JOB > ${path.root}/jobs/nomad-load-${each.key}.nomad.hcl
# This file is created by Terraform, but not managed to allow for local edits.
# It will not be recreated if deleted.
#
# Replace the resource to recreate this file.
# WARNING: ALL CHANGES WILL BE LOST.
#   terraform apply -replace 'module.bootstrap.terraform_data.nomad_jobs_load["${each.key}"]'

${local.nomad_load_jobs[each.key]}
JOB

# Hack to get around how Terraform handles ther dollar sign.
sed -i.bkp 's|#{|$${|g' ${path.root}/jobs/nomad-load-${each.key}.nomad.hcl
rm -f ${path.root}/jobs/nomad-load-${each.key}.nomad.hcl.bkp
EOF
  }

  provisioner "local-exec" {
    command = <<EOF
 rm -f ${path.root}/jobs/nomad-load-${each.key}.nomad.hcl
 EOF
    when    = destroy
  }
}

resource "nomad_variable" "nomad_load_influxdb_token" {
  for_each = var.clusters

  namespace = nomad_namespace.nomad_bench.name
  path      = "nomad/jobs/nomad-load-${each.key}"
  items = {
    influxdb_token = influxdb-v2_authorization.cluster_tokens[each.key].token
  }
}
