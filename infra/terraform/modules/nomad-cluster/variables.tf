variable "subnet_ids" {
  type = list(string)
}

variable "key_name" {
  type = string
}

variable "security_groups" {
  type = list(string)
}

variable "iam_instance_profile" {
  type = string
}

variable "ami" {
  description = "AMI to use for Ubuntu machines."
}

variable "name" {
  description = "Used to name various infrastructure components"
  default     = ""
}

variable "server_count" {
  description = "The number of servers to provision."
  default     = "3"
}

variable "server_instance_type" {
  description = "The AWS instance type to use for servers."
  default     = "m5.xlarge"
}

variable "server_iops" {
  description = "iops for the root block device of the nomad servers"
  default     = "3600"
}

variable "client_count" {
  description = "The number of Ubuntu clients to provision."
  default     = "0"
}

variable "client_instance_type" {
  description = "The AWS instance type to use for clients."
  default     = "m4.large"
}

variable "client_iops" {
  description = "iops for the root block device of the nomad clients"
  default     = "3600"
}
