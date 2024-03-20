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

variable "influxdb_token" {
  type      = string
  sensitive = true
}

# Use separate variable for the cluster names to avoid circular dependency.
# The cluster dependes on the InfluxDB buckets created by this module.
variable "cluster_names" {
  type = set(string)
}

variable "clusters" {
  type = map(object({
    server_private_ips : list(string)
    server_ansible_group : string
    server_ansible_hosts : list(string)
  }))
}

variable "ssh_key_path" {
  type = string
}

variable "bastion_ip" {
  type = string
}
