output "notification_email" {
  value = var.notification_email
}

output "load_balancer_id" {
  value = oci_load_balancer_load_balancer.this.id
}

output "instance_id" {
  value = oci_core_instance.app.id
}

output "adb_cpu_alarm_id" {
  value = oci_monitoring_alarm.adb_cpu.id
}

output "lb_unhealthy_alarm_id" {
  value = oci_monitoring_alarm.lb_unhealthy.id
}

output "load_balancer_public_ip" {
  description = "Public entry point. Serves the to-do app on port 80."
  value       = local.lb_public_ip
}

output "app_url" {
  description = "Direct link to the demo app through the load balancer."
  value       = "http://${local.lb_public_ip}/"
}

output "app_url_https" {
  description = "Same application over TLS. The generated certificate is self-signed, so expect a browser warning until you supply real PEMs."
  value       = "https://${local.lb_public_ip}/"
}

output "load_balancer_certificate_id" {
  value = oci_certificates_management_certificate.lb.id
}

output "app_dns_name" {
  description = "Public name tracked by the A record, when one is managed."
  value       = var.manage_dns ? var.acme_domain : null
}

output "app_url_dns" {
  description = "Entry point by name instead of IP, once the A record has propagated."
  value       = var.manage_dns && var.acme_domain != null ? "https://${var.acme_domain}/" : null
}

output "apex_url" {
  description = "ORDS/APEX entry point. It lives on the database's private endpoint, so it only answers through a bastion tunnel."
  value       = try(oci_database_autonomous_database.this.connection_urls[0].apex_url, null)
}

output "adb_private_ip" {
  description = "Private endpoint address of the Autonomous Database, inside the app subnet."
  value       = oci_database_autonomous_database.this.private_endpoint_ip
}

output "adb_private_endpoint_label" {
  value = oci_database_autonomous_database.this.private_endpoint_label
}

output "adb_connection_string_low" {
  description = "Full LOW descriptor. scripts/adb-sql.sh rewrites its host and port when it connects through the bastion tunnel."
  value       = try(oci_database_autonomous_database.this.connection_strings[0].low, null)
}

output "autonomous_database_id" {
  value = oci_database_autonomous_database.this.id
}

output "autonomous_database_name" {
  value = oci_database_autonomous_database.this.db_name
}

output "adb_tns_alias" {
  description = "Service alias inside the wallet used by the app and by SQLcl."
  value       = local.adb_tns_alias
}

output "compartment_ocid" {
  value = local.compartment
}

output "artifacts_bucket_name" {
  value = oci_objectstorage_bucket.artifacts.name
}

output "artifacts_bucket_namespace" {
  value = data.oci_objectstorage_namespace.this.namespace
}

output "wallet_object" {
  description = "Object holding the base64-encoded mTLS wallet."
  value       = oci_objectstorage_object.wallet.object
}

output "adb_admin_password_secret_ocid" {
  description = "Vault secret holding the ADMIN password. Read it with scripts/adb-sql.sh, never by hand."
  value       = oci_vault_secret.adb_admin.id
}

output "app_password_secret_ocid" {
  description = "Vault secret holding the TODO_APP password."
  value       = oci_vault_secret.app.id
}

output "adb_wallet_password" {
  description = "Password protecting the wallet keystore (not needed by the app, which uses ewallet.pem)."
  value       = random_password.wallet.result
  sensitive   = true
}

output "instance_private_ip" {
  value = oci_core_instance.app.private_ip
}

output "bastion_id" {
  value = oci_bastion_bastion.this.id
}

output "bastion_session_command" {
  description = "Creates a 60-minute managed SSH session. Then connect with the ProxyCommand printed by the CLI."
  value       = <<-EOT
    oci bastion session create-managed-ssh \
      --bastion-id ${oci_bastion_bastion.this.id} \
      --target-resource-id ${oci_core_instance.app.id} \
      --target-os-username opc \
      --ssh-public-key-file ~/.ssh/id_ed25519.pub \
      --session-ttl 3600 \
      --wait-for-state SUCCEEDED
  EOT
}

output "adb_sql_tunnel_command" {
  description = "Creates a port-forwarding session to the database's private listener. Run the ssh command it returns, then ADB_LOCAL_PORT=<port> scripts/adb-sql.sh ..."
  value       = <<-EOT
    oci bastion session create-port-forwarding \
      --bastion-id ${oci_bastion_bastion.this.id} \
      --target-private-ip ${oci_database_autonomous_database.this.private_endpoint_ip} \
      --target-port 1522 \
      --ssh-public-key-file ~/.ssh/id_ed25519.pub \
      --session-ttl 3600 \
      --wait-for-state SUCCEEDED
  EOT
}

output "vault_id" {
  value = oci_kms_vault.this.id
}
