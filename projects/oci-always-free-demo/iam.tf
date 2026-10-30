resource "oci_identity_dynamic_group" "app" {
  compartment_id = var.tenancy_ocid
  name           = "${local.prefix}-app-instance"
  description    = "The demo instance, so the app can read its own wallet and schema password without any key on disk"
  matching_rule  = "instance.id = '${oci_core_instance.app.id}'"
  freeform_tags  = local.tags
}

resource "oci_identity_policy" "app" {
  compartment_id = local.compartment
  name           = "${local.prefix}-app-instance"
  description    = "Instance-principal access to the demo's wallet object and schema password only"
  freeform_tags  = local.tags

  statements = [
    "Allow dynamic-group ${oci_identity_dynamic_group.app.name} to read secret-bundles in compartment id ${local.compartment}",
    "Allow dynamic-group ${oci_identity_dynamic_group.app.name} to read objects in compartment id ${local.compartment}",
  ]
}
