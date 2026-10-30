locals {
  compartment = coalesce(var.compartment_ocid, var.tenancy_ocid)
  prefix      = var.name_prefix

  # db_name also names the wallet TNS aliases: <db>_high, <db>_medium, <db>_low.
  adb_tns_alias = "${lower(var.adb_db_name)}_low"

  # DNS-safe, because it becomes the private endpoint hostname.
  adb_endpoint_label = "${replace(lower(var.name_prefix), "-", "")}adb"

  db_workload_name            = "TODO_APP"
  db_workload_password_secret = "todo-app-password"

  app_object    = "app/app.py"
  wallet_object = "wallet/adb-wallet.zip.b64"

  app_port = 8080

  # ip_addresses is deprecated; the public address is the entry flagged is_public.
  lb_public_ip = try([
    for detail in oci_load_balancer_load_balancer.this.ip_address_details : detail.ip_address
    if detail.is_public
  ][0], null)

  tags = {
    project   = "oci-always-free-demo"
    managedBy = "terraform"
    tier      = "always-free"
  }
}
