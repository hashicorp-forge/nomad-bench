variable "project_name" {
  description = "The name that will be associated with all AWS resources."
  type        = string
  default     = "nomad-bench"
}

variable "ami_id" {
  description = "The AMI ID to use for the bastion instance."
  type        = string
}

variable "instance_type" {
  description = "The AWS EC2 instance type to use for the bastion host."
  type        = string
  default     = "t3.micro"
}

variable "subnet_id" {
  description = "The AWS VPC subnet to place the bastion instance into."
  type        = string
}

variable "security_group_ids" {
  description = "The AWS VPC security group IDs that will be associated with the bastion instance."
  type        = list(string)
}

variable "ssh_private_key_name" {
  description = "The name of the SSH keypair in AWS."
  type        = string
}
