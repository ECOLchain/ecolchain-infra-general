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

data "oci_objectstorage_namespace" "ns" {}

resource "oci_objectstorage_bucket" "tfstate" {
  compartment_id = var.tenancy_ocid
  namespace      = data.oci_objectstorage_namespace.ns.namespace
  name           = var.bucket_name

  access_type  = "NoPublicAccess"
  storage_tier = "Standard"
  versioning   = "Enabled"

  freeform_tags = {
    "managed-by" = "terraform"
    "purpose"    = "terraform-state"
    "project"    = "ecolchain"
  }
}

resource "oci_identity_customer_secret_key" "tfstate" {
  user_id      = var.user_ocid
  display_name = var.customer_secret_key_name
}
