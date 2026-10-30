resource "oci_objectstorage_bucket" "artifacts" {
  compartment_id = local.compartment
  namespace      = data.oci_objectstorage_namespace.this.namespace
  name           = "${local.prefix}-artifacts"

  # Standard tier is Always Free eligible; Archive is not part of the allowance.
  storage_tier  = "Standard"
  access_type   = "NoPublicAccess"
  versioning    = "Enabled"
  freeform_tags = local.tags
}

resource "oci_objectstorage_object" "app" {
  bucket    = oci_objectstorage_bucket.artifacts.name
  namespace = data.oci_objectstorage_namespace.this.namespace
  object    = local.app_object
  source    = "${path.module}/app/app.py"

  content_type = "text/x-python"
}

resource "oci_objectstorage_object" "wallet" {
  bucket    = oci_objectstorage_bucket.artifacts.name
  namespace = data.oci_objectstorage_namespace.this.namespace
  object    = local.wallet_object
  content   = oci_database_autonomous_database_wallet.this.content

  content_type = "text/plain"
}
