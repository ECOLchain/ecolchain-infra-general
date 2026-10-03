output "bucket_name" {
  description = "Nome do bucket de state criado"
  value       = oci_objectstorage_bucket.tfstate.name
}

output "namespace" {
  description = "Namespace do Object Storage da tenancy"
  value       = data.oci_objectstorage_namespace.ns.namespace
}

output "s3_endpoint" {
  description = "Endpoint S3-compatible do Object Storage (usar no backend s3)"
  value       = "https://${data.oci_objectstorage_namespace.ns.namespace}.compat.objectstorage.${var.region}.oraclecloud.com"
}

output "s3_access_key" {
  description = "Access key S3 (id da Customer Secret Key) -> secret OCI_S3_ACCESS_KEY"
  value       = oci_identity_customer_secret_key.tfstate.id
}

output "s3_secret_key" {
  description = "Secret key S3 -> secret OCI_S3_SECRET_KEY"
  value       = oci_identity_customer_secret_key.tfstate.key
  sensitive   = true
}
