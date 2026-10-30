resource "oci_dns_rrset" "app" {
  count = var.manage_dns && var.acme_domain != null ? 1 : 0

  # Public zones only: compartment_id is for private zones, and passing this
  # compartment would fail for a zone that lives in another one.
  zone_name_or_id = var.acme_dns_zone
  domain          = var.acme_domain
  rtype           = "A"

  items {
    domain = var.acme_domain
    rtype  = "A"
    rdata  = local.lb_public_ip
    ttl    = 300
  }

  lifecycle {
    precondition {
      condition     = var.acme_dns_zone != null
      error_message = "manage_dns needs acme_dns_zone, the public zone that holds the record."
    }

    precondition {
      condition = (
        coalesce(var.acme_domain, "") == coalesce(var.acme_dns_zone, "") ||
        endswith(trimprefix(coalesce(var.acme_domain, ""), "*."), ".${coalesce(var.acme_dns_zone, "")}")
      )
      error_message = "acme_domain must sit inside acme_dns_zone, e.g. todo.example.com inside example.com."
    }
  }
}
