terraform {
  required_providers {
    oci = {
      source = "oracle/oci"
    }
  }
}

data "oci_objectstorage_namespace" "ns" {}

# Autonomous Database Always Free: um unico banco, ambientes separados
# por schema (usuarios Oracle). Rodar o SQL de outputs.schema_bootstrap_sql
# uma vez como ADMIN (Database Actions > SQL worksheet ou sqlcl).
resource "oci_database_autonomous_database" "this" {
  compartment_id = var.compartment_id
  db_name        = var.db_name
  display_name   = var.db_name
  db_workload    = "OLTP"
  db_version     = "23ai"

  is_free_tier                = true
  is_mtls_connection_required = false
  admin_password              = var.db_admin_password

  freeform_tags = {
    "managed-by" = "terraform"
    "purpose"    = "management-api"
    "project"    = "ecolchain"
  }
}

locals {
  # One-way TLS (sem wallet): entradas *_TLS do mapa de connection strings
  connection_strings = try(oci_database_autonomous_database.this.connection_strings[0].all_connection_strings, {})
  jdbc_url_tls       = try("jdbc:oracle:thin:@${local.connection_strings["TP_TLS"]}", "")

  schema_bootstrap_sql = templatefile("${path.module}/schema.sql.tpl", {
    dev_user  = var.schema_username_dev
    dev_pass  = var.schema_password_dev
    prod_user = var.schema_username_prod
    prod_pass = var.schema_password_prod
  })
}

resource "oci_objectstorage_bucket" "docs" {
  for_each       = var.documents_buckets
  compartment_id = var.compartment_id
  namespace      = data.oci_objectstorage_namespace.ns.namespace
  name           = each.value

  access_type  = "NoPublicAccess"
  storage_tier = "Standard"
  versioning   = "Disabled"

  freeform_tags = {
    "managed-by" = "terraform"
    "purpose"    = "management-api-documents"
    "project"    = "ecolchain"
    "env"        = each.key
  }
}

# Credencial S3-compat para o app (presign de URLs via SDK AWS)
resource "oci_identity_customer_secret_key" "app" {
  user_id      = var.user_ocid
  display_name = var.customer_secret_key_name
}
