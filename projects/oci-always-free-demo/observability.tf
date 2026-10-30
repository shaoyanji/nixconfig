resource "oci_ons_notification_topic" "this" {
  compartment_id = local.compartment
  name           = "${local.prefix}-alarms"
  description    = "Alarm fan-out for the Always Free demo"
  freeform_tags  = local.tags
}

resource "oci_ons_subscription" "email" {
  compartment_id = local.compartment
  topic_id       = oci_ons_notification_topic.this.id
  protocol       = "EMAIL"
  endpoint       = var.notification_email
}

resource "oci_monitoring_alarm" "adb_cpu" {
  compartment_id        = local.compartment
  display_name          = "${local.prefix}-adb-cpu"
  metric_compartment_id = local.compartment
  namespace             = "oci_autonomous_database"

  query = "CpuUtilization[5m]{resourceId = \"${oci_database_autonomous_database.this.id}\"}.mean() > 80"

  severity                     = "WARNING"
  pending_duration             = "PT5M"
  repeat_notification_duration = "PT4H"
  is_enabled                   = true
  destinations                 = [oci_ons_notification_topic.this.id]
  message_format               = "ONS_OPTIMIZED"

  alarm_summary = "ADB CPU above 80% for 5 minutes"
  body          = "Always Free compute is fixed at 2 ECPU (1 OCPU), so sustained CPU pressure is a query problem, not a sizing problem. Look for a full-table scan or an unclosed transaction."

  freeform_tags = local.tags
}

resource "oci_monitoring_alarm" "lb_unhealthy" {
  compartment_id        = local.compartment
  display_name          = "${local.prefix}-lb-unhealthy-backends"
  metric_compartment_id = local.compartment
  namespace             = "oci_lbaas"

  # Compartment-scoped on purpose: no dimension name is guessed, and this
  # tenancy only runs one load balancer in this project.
  query = "UnHealthyBackendCount[1m].sum() > 0"

  severity                     = "CRITICAL"
  pending_duration             = "PT5M"
  repeat_notification_duration = "PT1H"
  is_enabled                   = true
  destinations                 = [oci_ons_notification_topic.this.id]
  message_format               = "ONS_OPTIMIZED"

  alarm_summary = "Load balancer has an unhealthy backend"
  body          = "The instance is up but /healthz is failing, which usually means the app cannot reach the database. Check the instance journal, then the ADB lifecycle state."

  freeform_tags = local.tags
}
