output "bucket_name" {
  description = "Nome do bucket de artefatos"
  value       = oci_objectstorage_bucket.web.name
}

output "bucket_base_url" {
  description = "URL base publica dos objetos (endpoint que o worker consome)"
  value       = local.bucket_base_url
}

output "hostname" {
  description = "Hostname publico servido pelo worker"
  value       = cloudflare_workers_custom_domain.front.hostname
}

output "worker_name" {
  description = "Nome do script worker na Cloudflare"
  value       = cloudflare_workers_script.front.script_name
}
