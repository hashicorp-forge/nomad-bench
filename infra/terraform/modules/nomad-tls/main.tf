resource "null_resource" "provision_tls_certs" {
  triggers = {
    output_path = var.tls_output_path // terraform destroy-time provisioners can't access vars
  }

  provisioner "local-exec" {
    command = "cd ${abspath(path.module)} && ./provision-tls.sh \"${var.tls_output_path}\" \"${var.server_ips}\" \"${var.client_ips}\" \"${var.lb_ip}\""
  }

  provisioner "local-exec" {
    when    = destroy
    command = "rm -rf ${self.triggers.output_path}"
  }
}
