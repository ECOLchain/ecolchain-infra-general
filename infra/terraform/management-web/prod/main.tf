terraform {
  required_version = ">= 1.5.0"

  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 9.7"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.0"
    }
  }
}

provider "oci" {
  tenancy_ocid     = var.tenancy_ocid
  user_ocid        = var.user_ocid
  fingerprint      = var.fingerprint
  private_key_path = var.private_key_path
  region           = var.region
}

provider "cloudflare" {
  email   = var.cloudflare_email
  api_key = var.cloudflare_api_key
}

module "web_hosting" {
  source = "../../modules/web-hosting"

  env                   = "prod"
  hostname              = var.hostname
  bucket_name           = var.bucket_name
  region                = var.region
  compartment_id        = var.tenancy_ocid
  cloudflare_account_id = var.cloudflare_account_id
  cloudflare_zone_id    = var.cloudflare_zone_id
  basic_auth            = ""
  worker_name_prefix    = "ecolchain-web-mgmt"
  html_routes           = true
}
