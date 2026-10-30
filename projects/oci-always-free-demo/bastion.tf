resource "oci_bastion_bastion" "this" {
  compartment_id             = local.compartment
  bastion_type               = "STANDARD"
  target_subnet_id           = oci_core_subnet.private.id
  name                       = "${local.prefix}-bastion"
  max_session_ttl_in_seconds = 3600

  # Needed for SOCKS5 sessions against the private endpoint, which the database
  # (private DNS) and the browser (remote DNS) both require.
  dns_proxy_status = "ENABLED"

  # Only the operator's own address may request a session. Never 0.0.0.0/0.
  client_cidr_block_allow_list = [var.operator_cidr]

  freeform_tags = local.tags
}
