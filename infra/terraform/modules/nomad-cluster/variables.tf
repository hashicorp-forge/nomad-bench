variable "project_name" {
  description = "Used to name various infrastructure components"
  type        = string
  default     = "nomad-bench"
}

variable "subnet_ids" {
  description = ""
  type        = list(string)
}

variable "key_name" {
  description = ""
  type        = string
}

variable "security_groups" {
  description = ""
  type        = list(string)
}

variable "ami" {
  description = "AMI to use for Ubuntu machines."
  type        = string
}

variable "server_count" {
  description = "The number of servers to provision."
  type        = number
  default     = "3"
}

variable "server_instance_type" {
  description = "The AWS instance type to use for servers."
  type        = string
  default     = "m5.xlarge"
}

variable "server_iops" {
  description = "iops for the root block device of the nomad servers"
  type        = string
  default     = "3600"
}

variable "client_count" {
  description = "The number of Ubuntu clients to provision."
  type        = number
  default     = 0
}

variable "client_instance_type" {
  description = "The AWS instance type to use for clients."
  type        = string
  default     = "m4.large"
}

variable "client_iops" {
  description = "iops for the root block device of the nomad clients"
  type        = string
  default     = "3600"
}

variable "bastion_host" {
  description = "The public IP of the bastion host"
  type        = string
  default     = ""
}

variable "bastion_host_key" {
  description = "The SSH key of the bastion host"
  type        = string
  default     = ""
}
