provider "oci" {
  tenancy_ocid        = var.tenancy_ocid
  region              = var.region
  config_file_profile = var.config_file_profile
}

provider "acme" {
  server_url = var.acme_server_url
}

data "oci_objectstorage_namespace" "this" {
  compartment_id = local.compartment
}
