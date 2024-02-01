terraform {
  backend "s3" {
    bucket = "nomad-bench"
    key    = "tf-state/eu-west-2/bench-jrasell-b20b731"
    region = "eu-west-2"
  }
}

provider "aws" {
  region = var.region
}
