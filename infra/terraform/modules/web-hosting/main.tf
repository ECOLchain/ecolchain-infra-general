terraform {
  required_providers {
    oci = {
      source = "oracle/oci"
    }
    cloudflare = {
      source = "cloudflare/cloudflare"
    }
  }
}

data "oci_objectstorage_namespace" "ns" {}

# Bucket public-read que hospeda os artefatos estaticos do frontend (dist/)
resource "oci_objectstorage_bucket" "web" {
  compartment_id = var.compartment_id
  namespace      = data.oci_objectstorage_namespace.ns.namespace
  name           = var.bucket_name

  access_type  = "ObjectRead"
  storage_tier = "Standard"
  versioning   = "Disabled"

  freeform_tags = {
    "managed-by" = "terraform"
    "purpose"    = "web-hosting"
    "project"    = "ecolchain"
    "env"        = var.env
  }
}

locals {
  # URL publica de leitura de objetos: /n/<ns>/b/<bucket>/o/<objeto>
  bucket_base_url = "https://objectstorage.${var.region}.oraclecloud.com/n/${data.oci_objectstorage_namespace.ns.namespace}/b/${oci_objectstorage_bucket.web.name}/o"
}

# Worker que faz proxy para o bucket + SPA fallback (404 -> index.html)
# No ambiente dev: exige Basic Auth (binding secreto DEV_AUTH) e envia noindex
resource "cloudflare_workers_script" "front" {
  account_id         = var.cloudflare_account_id
  script_name        = "${var.worker_name_prefix}-${var.env}"
  content            = file("${path.module}/worker.js")
  main_module        = "worker.js"
  compatibility_date = "2025-06-01"

  bindings = concat(
    [{
      name = "BUCKET_BASE_URL"
      type = "plain_text"
      text = local.bucket_base_url
    }],
    var.basic_auth != "" ? [{
      name = "DEV_AUTH"
      type = "secret_text"
      text = var.basic_auth
    }] : []
  )
}

# Domínio custom do worker (cria o DNS do hostname implicitamente, proxied)
resource "cloudflare_workers_custom_domain" "front" {
  account_id = var.cloudflare_account_id
  zone_id    = var.cloudflare_zone_id
  hostname   = var.hostname
  service    = cloudflare_workers_script.front.script_name
}
