data "terraform_remote_state" "core" {
  backend = "remote"

  config = {
    organization = "nomad-eng"
    workspaces = {
      name = "nomad-bench-core"
    }
  }
}
