terraform {
  backend "s3" {
    bucket = "nomad-bench"
    key    = "tf-state/eu-west-2/bench-jrasell-b20b731"
    region = "eu-west-2"
  }
  required_providers {
    influxdb-v2 = {
      source  = "slcp/influxdb-v2"
      version = "0.5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

provider "nomad" {
  address = "CHANGE_ME"
}

provider "influxdb-v2" {
  url   = "CHANGE_ME"
  token = "CHANGE_ME_OR_USE_`INFLUXDB_V2_TOKEN`_ENV_VAR"
}
