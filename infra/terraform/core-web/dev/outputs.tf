output "hostname" {
  value = module.web_hosting.hostname
}

output "bucket_name" {
  value = module.web_hosting.bucket_name
}

output "bucket_base_url" {
  value = module.web_hosting.bucket_base_url
}

output "worker_name" {
  value = module.web_hosting.worker_name
}
