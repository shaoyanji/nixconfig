terraform {
  required_version = ">= 1.6.0"

  required_providers {
    oci = {
      source  = "oracle/oci"
      version = ">= 6.0.0, < 8.0.0"
    }
  }
}

provider "oci" {
  tenancy_ocid        = var.tenancy_ocid
  region              = var.region
  config_file_profile = var.config_file_profile
}

variable "tenancy_ocid" {
  type = string
}

variable "region" {
  type = string
}

variable "config_file_profile" {
  type    = string
  default = "DEFAULT"
}

variable "state_bucket_name" {
  description = "Bucket that holds the main configuration's remote state."
  type        = string
  default     = "oafdemo-tfstate"
}

data "oci_objectstorage_namespace" "this" {
  compartment_id = var.tenancy_ocid
}

resource "oci_objectstorage_bucket" "tfstate" {
  compartment_id = var.tenancy_ocid
  namespace      = data.oci_objectstorage_namespace.this.namespace
  name           = var.state_bucket_name

  storage_tier = "Standard"
  access_type  = "NoPublicAccess"

  # Versioning is what makes a bad apply recoverable: the previous state object
  # survives a write.
  versioning = "Enabled"
}

output "bucket" {
  value = oci_objectstorage_bucket.tfstate.name
}

output "namespace" {
  value = data.oci_objectstorage_namespace.this.namespace
}

output "region" {
  value = var.region
}
