output "influxdb_buckets" {
  value = { for k, v in influxdb-v2_bucket.suffixed : k => v.name }
}

output "nomad_namespace" {
  value = nomad_namespace.nomad_bench.name
}
