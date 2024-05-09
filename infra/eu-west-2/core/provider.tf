terraform {
  backend "local" {
    path = "terraform.tfstate"
  }

  required_providers {
    ansible = {
      source  = "ansible/ansible"
      version = "1.3.0"
    }
  }
}

provider "aws" {
  region = var.region
}
