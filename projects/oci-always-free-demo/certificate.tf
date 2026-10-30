locals {
  # certifiate_mode picks exactly one source of key material for the load
  # balancer's 443 listener.
  self_signed_enabled = var.certificate_mode == "self-signed"
  acme_enabled        = var.certificate_mode == "acme"
  imported_enabled    = var.certificate_mode == "imported"

  tls_certificate_pem = (
    local.self_signed_enabled ? one(tls_self_signed_cert.lb[*].cert_pem) :
    local.acme_enabled ? one(acme_certificate.lb[*].certificate_pem) :
    var.tls_certificate_pem
  )

  tls_chain_pem = (
    local.self_signed_enabled ? one(tls_self_signed_cert.lb[*].cert_pem) :
    local.acme_enabled ? one(acme_certificate.lb[*].issuer_pem) :
    var.tls_chain_pem
  )

  tls_private_key_pem = (
    local.self_signed_enabled ? one(tls_self_signed_cert.lb[*].private_key_pem) :
    local.acme_enabled ? one(acme_certificate.lb[*].private_key_pem) :
    var.tls_private_key_pem
  )
}

resource "tls_private_key" "lb" {
  count = local.self_signed_enabled ? 1 : 0

  # RSA keeps the certificate on the load balancer's default cipher suite;
  # an ECDSA key would need a modern suite to be negotiated.
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "lb" {
  count = local.self_signed_enabled ? 1 : 0

  private_key_pem       = one(tls_private_key.lb[*].private_key_pem)
  validity_period_hours = 8760
  early_renewal_hours   = 720

  subject {
    common_name  = coalesce(var.tls_dns_name, "always-free-demo")
    organization = "Always Free demo"
  }

  dns_names    = var.tls_dns_name == null ? [] : [var.tls_dns_name]
  ip_addresses = local.lb_public_ip == null ? [] : [local.lb_public_ip]
  allowed_uses = ["key_encipherment", "digital_signature", "server_auth"]

  lifecycle {
    create_before_destroy = true
  }
}

resource "tls_private_key" "acme_account" {
  count = local.acme_enabled ? 1 : 0

  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "acme_registration" "this" {
  count = local.acme_enabled ? 1 : 0

  account_key_pem = one(tls_private_key.acme_account[*].private_key_pem)
  email_address   = var.acme_email
}

resource "acme_certificate" "lb" {
  count = local.acme_enabled ? 1 : 0

  account_key_pem           = one(acme_registration.this[*].account_key_pem)
  common_name               = var.acme_domain
  subject_alternative_names = [var.acme_domain]
  key_type                  = "2048"
  min_days_remaining        = 30

  # DNS-01, because the domain resolves to a load balancer: there is nowhere for
  # an HTTP-01 challenge to be served from. The exec provider shells out to the
  # hook below, which writes the TXT record into OCI DNS.
  dns_challenge {
    provider = "exec"

    config = {
      EXEC_PATH           = "${path.module}/scripts/acme-dns-oci.sh"
      OCI_DNS_ZONE        = var.acme_dns_zone
      OCI_DNS_TTL         = "60"
      OCI_DNS_PROPAGATION = "120"
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "oci_certificates_management_certificate" "lb" {
  compartment_id = local.compartment
  name           = "${local.prefix}-lb-cert"
  description    = "TLS certificate for the ${local.prefix} load balancer (${var.certificate_mode})"
  freeform_tags  = local.tags

  certificate_config {
    config_type = "IMPORTED"

    certificate_pem = local.tls_certificate_pem
    cert_chain_pem  = local.tls_chain_pem
    private_key_pem = local.tls_private_key_pem
  }

  lifecycle {
    precondition {
      condition     = !local.acme_enabled || (var.acme_domain != null && var.acme_email != null && var.acme_dns_zone != null)
      error_message = "certificate_mode = acme needs acme_domain, acme_email and acme_dns_zone (the OCI DNS zone that holds the challenge TXT records)."
    }

    precondition {
      condition     = !local.imported_enabled || (var.tls_certificate_pem != null && var.tls_private_key_pem != null && var.tls_chain_pem != null)
      error_message = "certificate_mode = imported needs tls_certificate_pem, tls_private_key_pem and tls_chain_pem."
    }
  }
}
