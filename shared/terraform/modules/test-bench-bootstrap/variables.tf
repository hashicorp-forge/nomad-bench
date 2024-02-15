variable "project_name" {
  description = "The project name to use for creation of all bootstrap resources."
  type        = string
  default     = "nomad-bench"
}

variable "influxdb_bucket_suffixes" {
  description = "The suffix is append to the `project_name` and the number of buckets is represented by the list length."
  type        = list(string)
  default     = [ ]
}

variable "influxdb_org_name" {
  description = "The InfluxDB org name where the bucket will be created."
  type        = string
  default     = "nomad-eng"
}
