terraform {
  backend "s3" {
    bucket = "ecolchain-tfstate"
    key    = "prod/management-api-runtime/terraform.tfstate"
    region = "sa-saopaulo-1"

    endpoints = {
      s3 = "https://grmykw8bmw9d.compat.objectstorage.sa-saopaulo-1.oraclecloud.com"
    }

    skip_region_validation      = true
    skip_credentials_validation = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    skip_s3_checksum            = true
    use_path_style              = true
    use_lockfile                = true
  }
}

# (comentario de retry - ver docs/DUVIDAS.md: apply re-tenta via merge)
