locals {
  test_clusters = {
    "${var.project_name}-cluster-1" = {
      server_instance_type = "t2.micro"
      server_count         = 1
      server_iops          = 3000
    },

    "${var.project_name}-cluster-2" = {
      server_instance_type = "t2.micro"
      server_count         = 3
      ansible_server_group_vars = {
        custom_var = true
      }
    }
  }
}
