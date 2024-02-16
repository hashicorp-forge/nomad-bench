terraform {
  backend "s3" {
    bucket         = "nomad-bench"
    key            = "tf-state/eu-west-2/bench-core"
    region         = "eu-west-2"
    dynamodb_table = "nomad-bench-terraform-state-lock"
  }

  required_providers {
    ansible = {
      version = "~> 1.1.0"
      source  = "ansible/ansible"
    }
  }
}

provider "aws" {
  region = var.region
}
