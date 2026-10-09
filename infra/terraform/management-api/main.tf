terraform {
  required_version = ">= 1.5.0"

  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 9.7"
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

module "data" {
  source = "../modules/management-api-data"

  compartment_id           = var.tenancy_ocid
  user_ocid                = var.user_ocid
  region                   = var.region
  db_name                  = var.db_name
  adb_allowed_ips          = var.adb_allowed_ips
  db_admin_password        = var.db_admin_password
  schema_username_dev      = var.schema_username_dev
  schema_username_prod     = var.schema_username_prod
  schema_password_dev      = var.schema_password_dev
  schema_password_prod     = var.schema_password_prod
  documents_buckets        = var.documents_buckets
  customer_secret_key_name = var.customer_secret_key_name
}
