output "adb_id" {
  description = "OCID do Autonomous Database"
  value       = oci_database_autonomous_database.this.id
}

output "jdbc_url_tls" {
  description = "JDBC thin URL one-way TLS (sem wallet) — mesmo host para dev/prod, o schema define o ambiente"
  value       = local.jdbc_url_tls
}

output "connection_strings" {
  description = "Mapa completo de connection strings do ADB (perfis TP/LOW/HIGH e variantes *_TLS)"
  value       = local.connection_strings
}

output "schema_usernames" {
  description = "Schemas Oracle por ambiente (criar via schema_bootstrap_sql)"
  value = {
    dev  = var.schema_username_dev
    prod = var.schema_username_prod
  }
}

output "schema_bootstrap_sql" {
  description = "DDL dos schemas dev/prod — executar uma vez como ADMIN no Database Actions > SQL worksheet"
  value       = local.schema_bootstrap_sql
  sensitive   = true
}

output "documents_buckets" {
  description = "Mapa env -> nome do bucket de documentos"
  value       = { for env, b in oci_objectstorage_bucket.docs : env => b.name }
}

output "s3_endpoint" {
  description = "Endpoint S3-compatible do Object Storage (path-style obrigatório)"
  value       = "https://${data.oci_objectstorage_namespace.ns.namespace}.compat.objectstorage.${var.region}.oraclecloud.com"
}

output "s3_access_key" {
  description = "Access key S3 do app (id da Customer Secret Key)"
  value       = oci_identity_customer_secret_key.app.id
}

output "s3_secret_key" {
  description = "Secret key S3 do app"
  value       = oci_identity_customer_secret_key.app.key
  sensitive   = true
}
