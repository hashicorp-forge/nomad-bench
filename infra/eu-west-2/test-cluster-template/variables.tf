variable "project_name" {
  type = string
}

variable "ssh_key_path" {
  default = "../core/keys/bench-core.pem"
}

variable "influxdb_org" {
  default = "nomad-eng"
}
