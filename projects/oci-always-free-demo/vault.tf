resource "random_password" "adb_admin" {
  length           = 24
  special          = true
  override_special = "_-"
  min_upper        = 2
  min_lower        = 2
  min_numeric      = 2
  min_special      = 2
}

resource "random_password" "wallet" {
  length           = 24
  special          = true
  override_special = "_-"
  min_upper        = 2
  min_lower        = 2
  min_numeric      = 2
  min_special      = 2
}

resource "random_password" "app" {
  length           = 24
  special          = true
  override_special = "_-"
  min_upper        = 2
  min_lower        = 2
  min_numeric      = 2
  min_special      = 2
}

resource "oci_kms_vault" "this" {
  compartment_id = local.compartment
  display_name   = "${local.prefix}-vault"
  vault_type     = "DEFAULT"
  freeform_tags  = local.tags
}

resource "oci_kms_key" "this" {
  compartment_id      = local.compartment
  display_name        = "${local.prefix}-master-key"
  management_endpoint = oci_kms_vault.this.management_endpoint

  key_shape {
    algorithm = "AES"
    length    = 32
  }

  # SOFTWARE keys are part of the Always Free allowance; HSM keys are billed.
  protection_mode = "SOFTWARE"
  freeform_tags   = local.tags
}

resource "oci_vault_secret" "adb_admin" {
  compartment_id = local.compartment
  vault_id       = oci_kms_vault.this.id
  key_id         = oci_kms_key.this.id
  secret_name    = "adb-admin-password"
  description    = "ADMIN password for ${oci_database_autonomous_database.this.display_name}"

  secret_content {
    content_type = "BASE64"
    content      = base64encode(random_password.adb_admin.result)
    stage        = "CURRENT"
  }

  freeform_tags = local.tags
}

resource "oci_vault_secret" "app" {
  compartment_id = local.compartment
  vault_id       = oci_kms_vault.this.id
  key_id         = oci_kms_key.this.id
  secret_name    = local.db_workload_password_secret
  description    = "Password for the ${local.db_workload_name} schema, read by the demo app at runtime"

  secret_content {
    content_type = "BASE64"
    content      = base64encode(random_password.app.result)
    stage        = "CURRENT"
  }

  freeform_tags = local.tags
}
