module "clusters" {
  for_each = local.test_clusters
  source   = "../../../shared/terraform/modules/nomad-cluster"

  project_name    = each.key
  ami             = data.terraform_remote_state.core.outputs.ami_id
  subnet_ids      = data.terraform_remote_state.core.outputs.private_subnet_ids
  key_name        = data.terraform_remote_state.core.outputs.ssh_key_name
  security_groups = [data.terraform_remote_state.core.outputs.security_group_id]
  client_count    = 0

  server_instance_type = try(each.value.server_instance_type, "")
  server_count         = try(each.value.server_count, 1)
  server_iops          = try(each.value.server_iops, 3600)

  ansible_server_group_vars = merge({
    nomad_server_bootstrap_expect   = each.value.server_count
    influxdb_telegraf_output_bucket = module.bootstrap.influxdb_buckets[each.key]
  }, try(each.value.ansible_server_group_vars, {}))
}

module "bootstrap" {
  source = "../../../shared/terraform/modules/test-bench-bootstrap"

  project_name             = var.project_name
  influxdb_org_name        = data.terraform_remote_state.core_nomad.outputs.influxdb_org_name
  influxdb_bucket_suffixes = keys(local.test_clusters)
}

resource "local_file" "nodesim_jobs" {
  for_each = local.test_clusters

  content = templatefile("../../../shared/nomad/jobs/nomad-nodesim.nomad.hcl.tpl", {
    terraform_nodesim_job_name      = each.key
    terraform_nodesim_job_namespace = module.bootstrap.nomad_namespace
    terraform_nodesim_job_servers   = module.clusters[each.key].server_private_ips
  })
  filename = "${path.root}/jobs/nomad-nodesim-${each.key}.nomad.hcl"
}

resource "local_sensitive_file" "ssh_key" {
  content         = data.terraform_remote_state.core.outputs.ssh_key
  filename        = "${path.root}/keys/bench-core.pem"
  file_permission = "0600"
}
