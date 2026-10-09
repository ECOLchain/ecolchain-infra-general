terraform {
  required_version = ">= 1.5.0"

  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 9.7"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.0"
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

provider "cloudflare" {
  email   = var.cloudflare_email
  api_key = var.cloudflare_api_key
}

# Endpoints de submissao (SMTP/HTTPS) do Email Delivery na regiao do provider
data "oci_email_configuration" "this" {
  compartment_id = var.tenancy_ocid
}

locals {
  freeform_tags = {
    "managed-by" = "terraform"
    "purpose"    = "email-delivery"
    "project"    = "ecolchain"
  }
}

# Email Domain: dominio de envio. O DKIM abaixo assina todos os senders desse dominio
resource "oci_email_email_domain" "ecolchain" {
  compartment_id = var.tenancy_ocid
  name           = var.email_domain
  description    = "Dominio de envio transacional da ecolchain"
  freeform_tags  = local.freeform_tags
}

# DKIM (metodo CNAME): a OCI gera o registro e valida o DNS de forma assincrona
# (nasce NEEDS_ATTENTION e vira ACTIVE quando o CNAME abaixo for detectado)
resource "oci_email_dkim" "ecolchain" {
  email_domain_id = oci_email_email_domain.ecolchain.id
  name            = var.dkim_selector
  description     = "DKIM ${var.email_domain}"
  freeform_tags   = local.freeform_tags
}

# CNAME do DKIM no Cloudflare (DNS only - nao pode ser proxied)
# SPF/DMARC do apex ficam fora daqui: o Email Delivery usa Return-Path proprio
# por padrao, entao o DMARC passa pelo DKIM alinhado
resource "cloudflare_dns_record" "dkim" {
  zone_id = var.cloudflare_zone_id
  name    = oci_email_dkim.ecolchain.dns_subdomain_name
  type    = "CNAME"
  content = trimsuffix(oci_email_dkim.ecolchain.cname_record_value, ".")
  proxied = false
  ttl     = 1
  comment = "DKIM OCI Email Delivery (${var.email_domain})"
}

# Approved Sender: endereco From autorizado a enviar pelo Email Delivery
resource "oci_email_sender" "ecolchain" {
  compartment_id = var.tenancy_ocid
  email_address  = var.sender_email
  freeform_tags  = local.freeform_tags

  depends_on = [
    oci_email_email_domain.ecolchain,
    cloudflare_dns_record.dkim,
  ]
}

# Credencial SMTP do app, gerada no usuario do Terraform (grupo Administrators,
# que ja tem `use email-family`). A senha so e retornada na criacao e fica no
# state (bucket OCI privado e versionado)
resource "oci_identity_smtp_credential" "app" {
  user_id     = var.user_ocid
  description = var.smtp_credential_description
}
