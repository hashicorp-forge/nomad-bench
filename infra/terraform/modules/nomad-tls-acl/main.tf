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

resource "null_resource" "setup_acl" {
  provisioner "file" {
    source      = "${path.module}/acl.hcl"
    destination = "/etc/nomad.d/acl.hcl"
  }

  connection {
    type         = "ssh"
    user         = "ubuntu"
    private_key  = file(var.private_key_path)
    bastion_host = var.bastion_host
    host         = var.server_ips
  }
}

resource "null_resource" "apply_anonymous_policy" {
  depends_on = [null_resource.provision_tls_certs, null_resource.setup_acl]

  provisioner "local-exec" {
    command = "nomad acl bootstrap -json | jq -r '.SecretID' > ${path.module}/nomad-root-token"
  }

  provisioner "local-exec" {
    command = "nomad acl policy -address ${var.lb_ip} -token $(cat ${path.module}/nomad-root-token) apply -description \"Anonymous policy (full-access)\" anonymous ${path.module}/anonymous.policy.hcl"
  }
}

resource "null_resource" "cleanup" {
  provisioner "local-exec" {
    when    = destroy
    command = "rm -f ${path.module}/nomad-root-token"
  }
}
