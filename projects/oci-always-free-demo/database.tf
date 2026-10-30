resource "oci_database_autonomous_database" "this" {
  compartment_id = local.compartment
  db_name        = var.adb_db_name
  display_name   = "${local.prefix}-atp"

  admin_password = random_password.adb_admin.result

  db_workload   = var.adb_workload
  db_version    = var.adb_version
  license_model = "LICENSE_INCLUDED"

  # The single lever that makes this an Always Free resource. OCI ignores
  # cpu_core_count and data_storage_size_in_tbs here and fixes the shape at
  # 1 OCPU (2 ECPU) and 20 GB, which is why they are expressed in ECPU terms.
  is_free_tier             = true
  compute_model            = "ECPU"
  compute_count            = var.adb_compute_count
  data_storage_size_in_tbs = var.adb_storage_size_in_tbs
  is_auto_scaling_enabled  = false

  # Private endpoint: the database gets a VNIC in the app subnet and loses its
  # public SQL*Net and ORDS listeners. Only hosts in that subnet can reach it,
  # which here means the application instance and the bastion endpoint.
  subnet_id              = oci_core_subnet.private.id
  private_endpoint_label = local.adb_endpoint_label

  # mTLS: every client must present the wallet generated below.
  is_mtls_connection_required = true

  freeform_tags = local.tags
}

resource "oci_database_autonomous_database_wallet" "this" {
  autonomous_database_id = oci_database_autonomous_database.this.id
  password               = random_password.wallet.result
  generate_type          = "SINGLE"

  # Keeps the zip intact in state; the artifacts bucket stores the base64 form.
  base64_encode_content = true
}
