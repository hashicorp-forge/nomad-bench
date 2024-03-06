locals {
  certs = {
    server = {
      ip_addresses = concat(
        ["127.0.0.1"],
        var.server_ips,
      ),
      dns_names = concat(
        [
          "server.global.nomad",
          "localhost",
        ],
        var.dns_names,
      )
    }

    client = {
      ip_addresses = concat(
        ["127.0.0.1"],
        var.lb_ips,
        var.client_ips,
      ),
      dns_names = concat(
        [
          "client.global.nomad",
          "localhost",
        ],
        var.dns_names,
      )
    }

    cli = {
      ip_addresses = []
      dns_names = concat(
        [
          "cli.global.nomad",
          "localhost",
        ],
        var.dns_names,
      )
    }
  }
}

resource "tls_private_key" "ca" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P256"
}

resource "tls_self_signed_cert" "ca" {
  private_key_pem = tls_private_key.ca.private_key_pem

  validity_period_hours = 5 * 365 * 24
  is_ca_certificate     = true
  set_authority_key_id  = true

  subject {
    country             = "US"
    province            = "CA"
    locality            = "San Francisco"
    street_address      = ["101 Second Street"]
    postal_code         = "94105"
    organization        = "HashiCorp Inc."
    organizational_unit = "Nomad"
    common_name         = "Nomad Agent CA"
  }

  allowed_uses = [
    "digital_signature",
    "cert_signing",
    "crl_signing",
  ]
}

resource "tls_private_key" "keys" {
  for_each = local.certs

  algorithm   = "ECDSA"
  ecdsa_curve = "P256"
}

resource "tls_cert_request" "csr" {
  for_each = local.certs

  private_key_pem = tls_private_key.keys[each.key].private_key_pem
  dns_names       = each.value.dns_names
  ip_addresses    = each.value.ip_addresses

  subject {
    common_name = "${each.key}.${var.region}.nomad"
  }
}

resource "tls_locally_signed_cert" "certs" {
  for_each = local.certs

  cert_request_pem   = tls_cert_request.csr[each.key].cert_request_pem
  ca_private_key_pem = tls_private_key.ca.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.ca.cert_pem

  validity_period_hours = 365 * 24
  set_subject_key_id    = true

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "client_auth",
    "server_auth",
  ]
}
