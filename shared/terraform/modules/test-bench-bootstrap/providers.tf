terraform {
  required_providers {
    ansible = {
      source  = "ansible/ansible"
      version = "1.3.0"
    }
    influxdb-v2 = {
      source  = "slcp/influxdb-v2"
      version = "0.5.0"
    }
  }
}
