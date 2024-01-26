variable "cluster_name" {
  description = "Used to name various infrastructure components"
  default     = "nomad-bench-permanent"
}

variable "region" {
  description = "The AWS region to deploy to."
  default     = "eu-central-1"
}

variable "nomad_server_instance_type" {
  description = "The AWS instance type to use for servers."
  default     = "m5.xlarge"
}

variable "nomad_client_instance_type" {
  description = "The AWS instance type to use for clients."
  default     = "m4.large"
}

variable "nomad_server_iops" {
  description = "iops for the root block device of the nomad servers"
  default     = "3600"
}

variable "nomad_client_iops" {
  description = "iops for the root block device of the nomad clients"
  default     = "3600"
}

variable "server_count" {
  description = "The number of servers to provision."
  default     = "3"
}

variable "client_count" {
  description = "The number of Ubuntu clients to provision."
  default     = "1"
}

variable "ami" {
  description = "AMI to use for Ubuntu machines."
  default     = "ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-20240126"
}
