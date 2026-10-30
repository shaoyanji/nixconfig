resource "oci_load_balancer_load_balancer" "this" {
  compartment_id = local.compartment
  display_name   = "${local.prefix}-lb"
  shape          = "flexible"
  subnet_ids     = [oci_core_subnet.public.id]
  is_private     = false
  freeform_tags  = local.tags

  shape_details {
    minimum_bandwidth_in_mbps = var.lb_bandwidth_mbps
    maximum_bandwidth_in_mbps = var.lb_bandwidth_mbps
  }
}

resource "oci_load_balancer_backend_set" "app" {
  load_balancer_id = oci_load_balancer_load_balancer.this.id
  name             = "todo-backend"
  policy           = "ROUND_ROBIN"

  health_checker {
    protocol          = "HTTP"
    port              = local.app_port
    url_path          = "/healthz"
    return_code       = 200
    interval_ms       = 10000
    timeout_in_millis = 3000
    retries           = 3
  }
}

resource "oci_load_balancer_backend" "app" {
  load_balancer_id = oci_load_balancer_load_balancer.this.id
  backendset_name  = oci_load_balancer_backend_set.app.name
  ip_address       = oci_core_instance.app.private_ip
  port             = local.app_port
  weight           = 1
}

resource "oci_load_balancer_rule_set" "https_redirect" {
  count = var.force_https ? 1 : 0

  load_balancer_id = oci_load_balancer_load_balancer.this.id
  name             = "http-to-https"

  items {
    action        = "REDIRECT"
    response_code = 301

    conditions {
      attribute_name  = "PATH"
      attribute_value = "/"
      operator        = "FORCE_LONGEST_PREFIX_MATCH"
    }

    redirect_uri {
      protocol = "HTTPS"
      port     = 443
    }
  }
}

resource "oci_load_balancer_listener" "http" {
  load_balancer_id         = oci_load_balancer_load_balancer.this.id
  name                     = "http"
  default_backend_set_name = oci_load_balancer_backend_set.app.name
  port                     = 80
  protocol                 = "HTTP"

  rule_set_names = var.force_https ? [oci_load_balancer_rule_set.https_redirect[0].name] : []
}

resource "oci_load_balancer_listener" "https" {
  load_balancer_id         = oci_load_balancer_load_balancer.this.id
  name                     = "https"
  default_backend_set_name = oci_load_balancer_backend_set.app.name
  port                     = 443
  protocol                 = "HTTP"

  ssl_configuration {
    certificate_ids = [oci_certificates_management_certificate.lb.id]
  }
}
