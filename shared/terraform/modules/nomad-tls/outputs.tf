# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

output "ca_key" {
  value     = tls_private_key.ca.private_key_pem
  sensitive = true
}

output "ca_cert" {
  value     = tls_self_signed_cert.ca.cert_pem
  sensitive = true
}

output "certs" {
  value     = { for k, v in tls_locally_signed_cert.certs : k => v.cert_pem }
  sensitive = true
}

output "keys" {
  value     = { for k, v in tls_private_key.keys : k => v.private_key_pem }
  sensitive = true
}
