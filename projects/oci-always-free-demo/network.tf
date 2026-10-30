resource "oci_core_vcn" "this" {
  compartment_id = local.compartment
  cidr_blocks    = [var.vcn_cidr]
  display_name   = "${local.prefix}-vcn"
  dns_label      = replace(local.prefix, "-", "")
  freeform_tags  = local.tags
}

resource "oci_core_internet_gateway" "this" {
  compartment_id = local.compartment
  vcn_id         = oci_core_vcn.this.id
  display_name   = "${local.prefix}-igw"
  enabled        = true
  freeform_tags  = local.tags
}

resource "oci_core_nat_gateway" "this" {
  compartment_id = local.compartment
  vcn_id         = oci_core_vcn.this.id
  display_name   = "${local.prefix}-nat"
  freeform_tags  = local.tags
}

resource "oci_core_route_table" "public" {
  compartment_id = local.compartment
  vcn_id         = oci_core_vcn.this.id
  display_name   = "${local.prefix}-rt-public"
  freeform_tags  = local.tags

  route_rules {
    destination       = "0.0.0.0/0"
    network_entity_id = oci_core_internet_gateway.this.id
    description       = "Ingress for the public load balancer listener"
  }
}

resource "oci_core_route_table" "private" {
  compartment_id = local.compartment
  vcn_id         = oci_core_vcn.this.id
  display_name   = "${local.prefix}-rt-private"
  freeform_tags  = local.tags

  route_rules {
    destination       = "0.0.0.0/0"
    network_entity_id = oci_core_nat_gateway.this.id
    description       = "Egress only: package installs and OCI API calls, no inbound path"
  }
}

resource "oci_core_security_list" "lb" {
  compartment_id = local.compartment
  vcn_id         = oci_core_vcn.this.id
  display_name   = "${local.prefix}-sl-lb"
  freeform_tags  = local.tags

  ingress_security_rules {
    protocol    = "6"
    source      = "0.0.0.0/0"
    description = "HTTP"
    tcp_options {
      min = 80
      max = 80
    }
  }

  ingress_security_rules {
    protocol    = "6"
    source      = "0.0.0.0/0"
    description = "HTTPS, used once a certificate is attached to the listener"
    tcp_options {
      min = 443
      max = 443
    }
  }

  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
    description = "Backend health checks and traffic to the private subnet"
  }
}

resource "oci_core_security_list" "app" {
  compartment_id = local.compartment
  vcn_id         = oci_core_vcn.this.id
  display_name   = "${local.prefix}-sl-app"
  freeform_tags  = local.tags

  ingress_security_rules {
    protocol    = "6"
    source      = var.public_subnet_cidr
    description = "Application port, reachable only from the load balancer subnet"
    tcp_options {
      min = local.app_port
      max = local.app_port
    }
  }

  ingress_security_rules {
    protocol    = "6"
    source      = var.private_subnet_cidr
    description = "Autonomous Database SQL*Net over mTLS, from inside the app subnet only"
    tcp_options {
      min = 1522
      max = 1522
    }
  }

  ingress_security_rules {
    protocol    = "6"
    source      = var.private_subnet_cidr
    description = "SSH from the bastion private endpoint"
    tcp_options {
      min = 22
      max = 22
    }
  }

  dynamic "ingress_security_rules" {
    for_each = var.bastion_service_cidrs
    content {
      protocol    = "6"
      source      = ingress_security_rules.value
      description = "SSH from the OCI Bastion service"
      tcp_options {
        min = 22
        max = 22
      }
    }
  }

  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
    description = "Package installs, OCI API and Object Storage over the NAT gateway"
  }
}

resource "oci_core_subnet" "public" {
  compartment_id             = local.compartment
  vcn_id                     = oci_core_vcn.this.id
  cidr_block                 = var.public_subnet_cidr
  display_name               = "${local.prefix}-subnet-public"
  dns_label                  = "lb"
  route_table_id             = oci_core_route_table.public.id
  security_list_ids          = [oci_core_security_list.lb.id]
  prohibit_public_ip_on_vnic = false
  freeform_tags              = local.tags
}

resource "oci_core_subnet" "private" {
  compartment_id             = local.compartment
  vcn_id                     = oci_core_vcn.this.id
  cidr_block                 = var.private_subnet_cidr
  display_name               = "${local.prefix}-subnet-private"
  dns_label                  = "app"
  route_table_id             = oci_core_route_table.private.id
  security_list_ids          = [oci_core_security_list.app.id]
  prohibit_public_ip_on_vnic = true
  freeform_tags              = local.tags
}
