terraform {
  backend "s3" {
    bucket = "nomad-bench"
    key    = "tf-state/eu-west-2/bench-core"
    region = "eu-west-2"
  }
}

provider "aws" {
  region = var.region
}
