variable "project_name" {
  description = "The project name to use for creation of all bootstrap resources."
  type        = string
  default     = "nomad-bench"
}

variable "influxdb_org_name" {
  description = "The InfluxDB org name where the bucket will be created."
  type        = string
  default     = "nomad-eng"
}

variable "influxdb_url" {
  type = string
}

variable "clusters" {
  type = set(string)
}

variable "cluster_server_ips" {
  type = map(list(string))
}
