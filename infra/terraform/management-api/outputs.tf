output "adb_id" {
  description = "OCID do Autonomous Database"
  value       = module.data.adb_id
}

output "jdbc_url_tls" {
  description = "JDBC thin URL one-way TLS — mesmo host para dev/prod; o usuário (schema) define o ambiente"
  value       = module.data.jdbc_url_tls
}

output "connection_strings" {
  description = "Connection strings do ADB (perfis TP/LOW/HIGH e variantes *_TLS)"
  value       = module.data.connection_strings
}

output "schema_usernames" {
  description = "Schemas Oracle por ambiente"
  value       = module.data.schema_usernames
}

output "schema_bootstrap_sql" {
  description = "DDL dos schemas dev/prod — executar uma vez como ADMIN no Database Actions > SQL worksheet"
  value       = module.data.schema_bootstrap_sql
  sensitive   = true
}

output "documents_buckets" {
  description = "Buckets de documentos por ambiente"
  value       = module.data.documents_buckets
}

output "s3_endpoint" {
  description = "Endpoint S3-compat do Object Storage"
  value       = module.data.s3_endpoint
}

output "s3_access_key" {
  description = "Access key S3 do app -> usar em quarkus.s3.aws.credentials.static-provider.access-key-id"
  value       = module.data.s3_access_key
}

output "s3_secret_key" {
  description = "Secret key S3 do app -> usar em quarkus.s3.aws.credentials.static-provider.secret-access-key"
  value       = module.data.s3_secret_key
  sensitive   = true
}
