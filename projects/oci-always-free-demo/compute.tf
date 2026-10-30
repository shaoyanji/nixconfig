data "oci_identity_availability_domains" "ads" {
  compartment_id = var.tenancy_ocid
}

data "oci_core_images" "ol" {
  compartment_id           = local.compartment
  operating_system         = "Oracle Linux"
  operating_system_version = var.image_os_version
  shape                    = var.instance_shape
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

resource "oci_core_instance" "app" {
  compartment_id      = local.compartment
  availability_domain = coalesce(var.availability_domain, data.oci_identity_availability_domains.ads.availability_domains[0].name)
  display_name        = "${local.prefix}-app"
  shape               = var.instance_shape

  dynamic "shape_config" {
    for_each = startswith(var.instance_shape, "VM.Standard.A1") ? [1] : []
    content {
      ocpus         = 1
      memory_in_gbs = 6
    }
  }

  source_details {
    source_type             = "image"
    source_id               = data.oci_core_images.ol.images[0].id
    boot_volume_size_in_gbs = var.boot_volume_gb
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.private.id
    assign_public_ip = false
    hostname_label   = "todo"
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key

    user_data = base64encode(templatefile("${path.module}/cloud-init.yaml.tftpl", {
      bucket_namespace = data.oci_objectstorage_namespace.this.namespace
      bucket_name      = oci_objectstorage_bucket.artifacts.name
      app_object       = local.app_object
      wallet_object    = local.wallet_object
      db_user          = local.db_workload_name
      db_alias         = local.adb_tns_alias
      secret_ocid      = oci_vault_secret.app.id
      app_port         = local.app_port
    }))
  }

  agent_config {
    are_all_plugins_disabled = false
    is_management_disabled   = false
    is_monitoring_disabled   = false

    plugins_config {
      name          = "Bastion"
      desired_state = "ENABLED"
    }
  }

  freeform_tags = local.tags

  depends_on = [
    oci_objectstorage_object.app,
    oci_objectstorage_object.wallet,
  ]
}
