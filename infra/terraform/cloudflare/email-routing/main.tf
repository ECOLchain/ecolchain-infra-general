terraform {
  required_version = ">= 1.0"

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "5.22.0"
    }
  }
}

provider "cloudflare" {
  email   = var.cloudflare_email
  api_key = var.cloudflare_api_key
}

resource "cloudflare_email_routing_settings" "ecolchain" {
  zone_id = var.cloudflare_zone_id
}

resource "cloudflare_email_routing_address" "gmail" {
  account_id = var.cloudflare_account_id
  email      = var.destination_email
}

resource "cloudflare_email_routing_catch_all" "catch_all" {
  zone_id = var.cloudflare_zone_id
  enabled = true
  name    = "Catch-all to Gmail"
  source  = "api"

  matchers = [{
    type = "all"
  }]

  actions = [{
    type  = "forward"
    value = [cloudflare_email_routing_address.gmail.email]
  }]
}
