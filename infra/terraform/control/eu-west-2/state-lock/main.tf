provider "aws" {
  region = "eu-west-2"
}

resource "aws_dynamodb_table" "nomad-bench-terraform-state-lock" {
  name         = "nomad-bench-terraform-state-lock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"
  attribute {
    name = "LockID"
    type = "S"
  }
}
