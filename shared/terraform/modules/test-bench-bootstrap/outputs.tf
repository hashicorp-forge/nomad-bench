output "influxdb_buckets" {
  value = { for k, v in influxdb-v2_bucket.clusters : k => v.name }
}

output "nomad_namespace" {
  value = nomad_namespace.nomad_bench.name
}
