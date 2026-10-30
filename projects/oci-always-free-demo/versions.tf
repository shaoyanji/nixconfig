terraform {
  required_version = ">= 1.6.0"

  required_providers {
    oci = {
      source = "oracle/oci"
      # 9.x is the first line that can import certificate content
      # (certificate_config.certificate_pem) for the 443 listener.
      version = ">= 9.0.0, < 10.0.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.6.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = ">= 4.0.0"
    }
    acme = {
      source  = "vancluever/acme"
      version = "~> 2.0"
    }
  }
}
