variable "tenancy_ocid" {
  description = "Tenancy OCID. Same value as tenancy in ~/.oci/config."
  type        = string
}

variable "compartment_ocid" {
  description = "Compartment that holds every resource. Defaults to the tenancy root."
  type        = string
  default     = null
}

variable "region" {
  description = "OCI region. Left null, the provider uses the region from ~/.oci/config."
  type        = string
  default     = null
}

variable "config_file_profile" {
  description = "Profile in ~/.oci/config used for API-key authentication."
  type        = string
  default     = "DEFAULT"
}

variable "name_prefix" {
  description = "Prefix for display names and the artifacts bucket name."
  type        = string
  default     = "oafdemo"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,14}$", var.name_prefix))
    error_message = "name_prefix must be 3-15 lowercase alphanumeric characters or hyphens, starting with a letter."
  }
}

variable "vcn_cidr" {
  description = "VCN CIDR block."
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "Public subnet CIDR block (load balancer only)."
  type        = string
  default     = "10.0.1.0/24"
}

variable "private_subnet_cidr" {
  description = "Private subnet CIDR block (application instance and bastion endpoint)."
  type        = string
  default     = "10.0.2.0/24"
}

variable "operator_cidr" {
  description = "Your public IP in CIDR form. The only source allowed to open bastion sessions; never 0.0.0.0/0."
  type        = string

  validation {
    condition     = can(cidrhost(var.operator_cidr, 0)) && var.operator_cidr != "0.0.0.0/0"
    error_message = "operator_cidr must be a valid CIDR and must not be 0.0.0.0/0."
  }
}

variable "ssh_public_key" {
  description = "SSH public key installed for the opc user on the application instance."
  type        = string
}

variable "notification_email" {
  description = "Address that receives alarm notifications. OCI sends a confirmation link you must click once."
  type        = string

  validation {
    condition     = can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", var.notification_email))
    error_message = "notification_email must be a valid email address."
  }
}

# --- Always Free shape of the Autonomous Database -----------------------------
# 1 OCPU == 2 ECPU. cpu_core_count and data_storage_size_in_tbs are both ignored
# by OCI for Always Free databases: the free shape is fixed at 1 OCPU / 20 GB.

variable "adb_db_name" {
  description = "Database name (also the prefix of the TNS service aliases)."
  type        = string
  default     = "TODODB"

  validation {
    condition     = can(regex("^[A-Za-z][A-Za-z0-9]{0,13}$", var.adb_db_name))
    error_message = "adb_db_name must start with a letter and be at most 14 alphanumeric characters."
  }
}

variable "adb_compute_count" {
  description = "ECPU count. Always Free is exactly 2 ECPU (1 OCPU)."
  type        = number
  default     = 2

  validation {
    condition     = var.adb_compute_count == 2
    error_message = "Always Free Autonomous Databases are fixed at 2 ECPU (1 OCPU)."
  }
}

variable "adb_storage_size_in_tbs" {
  description = "Requested storage in TB. Always Free is capped at 20 GB (0.02 TB) and OCI ignores larger requests."
  type        = number
  default     = 0.02

  validation {
    condition     = var.adb_storage_size_in_tbs <= 0.02
    error_message = "Always Free Autonomous Databases are capped at 0.02 TB (20 GB) of storage."
  }
}

variable "adb_workload" {
  description = "OLTP, or APEX for the APEX workload type. APEX is preinstalled either way; the workload type only changes the console experience."
  type        = string
  default     = "OLTP"

  validation {
    condition     = contains(["OLTP", "APEX"], var.adb_workload)
    error_message = "Only OLTP and APEX workloads are Always Free eligible."
  }
}

variable "adb_version" {
  description = "Database version. 19c is the most conservative Always Free choice."
  type        = string
  default     = "19c"

  validation {
    condition     = contains(["19c", "23ai", "26ai"], var.adb_version)
    error_message = "adb_version must be one of 19c, 23ai, 26ai."
  }
}

# --- Edge and compute --------------------------------------------------------

variable "lb_bandwidth_mbps" {
  description = "Flexible load balancer bandwidth in Mbps. Always Free is exactly 10."
  type        = number
  default     = 10

  validation {
    condition     = var.lb_bandwidth_mbps == 10
    error_message = "Always Free flexible load balancers are fixed at 10 Mbps minimum and maximum."
  }
}

variable "instance_shape" {
  description = "Always Free compute shape: VM.Standard.E2.1.Micro (x86, 1/8 OCPU, 1 GB) or VM.Standard.A1.Flex (1 OCPU, 6 GB ARM)."
  type        = string
  default     = "VM.Standard.E2.1.Micro"

  validation {
    condition     = contains(["VM.Standard.E2.1.Micro", "VM.Standard.A1.Flex"], var.instance_shape)
    error_message = "Only VM.Standard.E2.1.Micro and VM.Standard.A1.Flex are Always Free eligible."
  }
}

variable "boot_volume_gb" {
  description = "Boot volume size in GB. Always Free total block storage is 200 GB."
  type        = number
  default     = 50

  validation {
    condition     = var.boot_volume_gb >= 50 && var.boot_volume_gb <= 200
    error_message = "boot_volume_gb must be between 50 and 200 GB to stay inside Always Free block storage."
  }
}

variable "image_os_version" {
  description = "Oracle Linux major version used to pick the instance image."
  type        = string
  default     = "9"
}

variable "availability_domain" {
  description = "Availability domain for the instance. Defaults to the first AD in the tenancy."
  type        = string
  default     = null
}

variable "certificate_mode" {
  description = "Where the 443 listener's certificate comes from: self-signed, acme, or imported PEMs."
  type        = string
  default     = "self-signed"

  validation {
    condition     = contains(["self-signed", "acme", "imported"], var.certificate_mode)
    error_message = "certificate_mode must be self-signed, acme or imported."
  }
}

variable "acme_domain" {
  description = "certificate_mode = acme: the fully qualified name to issue for, e.g. todo.example.com or *.example.com."
  type        = string
  default     = null
}

variable "acme_email" {
  description = "certificate_mode = acme: account contact address used for expiry notices."
  type        = string
  default     = null
}

variable "acme_dns_zone" {
  description = "certificate_mode = acme: name of the OCI DNS zone that can hold the _acme-challenge TXT records (e.g. example.com)."
  type        = string
  default     = null
}

variable "manage_dns" {
  description = "Create the A record for acme_domain in acme_dns_zone and keep it on the load balancer's public IP. An existing RRSet at that name is replaced, so set this false if it is managed elsewhere."
  type        = bool
  default     = true
}

variable "acme_server_url" {
  description = "ACME directory URL. Use the Let's Encrypt staging endpoint while testing the DNS hook."
  type        = string
  default     = "https://acme-v02.api.letsencrypt.org/directory"
}

variable "tls_certificate_pem" {
  description = "certificate_mode = imported: leaf certificate in PEM form."
  type        = string
  default     = null
  sensitive   = true
}

variable "tls_private_key_pem" {
  description = "Private key for tls_certificate_pem, in PEM form. Required with the certificate."
  type        = string
  default     = null
  sensitive   = true
}

variable "tls_chain_pem" {
  description = "Intermediate chain in PEM form. Defaults to tls_certificate_pem, which is correct for a self-signed leaf."
  type        = string
  default     = null
  sensitive   = true
}

variable "tls_dns_name" {
  description = "certificate_mode = self-signed: DNS name for the subject and SAN. The load balancer IP is always included as an IP SAN."
  type        = string
  default     = null
}

variable "force_https" {
  description = "Redirect HTTP to HTTPS. Off by default because the default certificate is self-signed."
  type        = bool
  default     = false
}

variable "bastion_service_cidrs" {
  description = "Source ranges used by the OCI Bastion service. Confirm against the Bastion documentation for your region."
  type        = list(string)
  default     = ["130.35.0.0/16", "138.1.0.0/16"]
}
