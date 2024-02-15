resource "nomad_namespace" "nomad_bench" {
  name        = var.project_name
  description = "namespace created by Terraform for ${var.project_name}"
}
