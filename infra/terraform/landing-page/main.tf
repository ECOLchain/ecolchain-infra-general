terraform {
  required_version = ">= 1.5.0"

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.0"
    }
    vercel = {
      source  = "vercel/vercel"
      version = "~> 2.0"
    }
  }
}

provider "cloudflare" {
  email   = var.cloudflare_email
  api_key = var.cloudflare_api_key
}

provider "vercel" {
  api_token = var.vercel_api_token
  team      = var.vercel_team_id != "" ? var.vercel_team_id : null
}

# 1. Projeto Vercel para a Landing Page
resource "vercel_project" "landing_page" {
  name      = var.vercel_project_name
  framework = "nextjs"
  
  root_directory = "app"
}

# 2. Domínio da Landing Page na Vercel (lp.ecolchain.com)
resource "vercel_project_domain" "lp" {
  project_id = vercel_project.landing_page.id
  domain     = var.domain_name
}

# 3. Apontamento CNAME no Cloudflare para lp -> Vercel
resource "cloudflare_dns_record" "vercel_cname_lp" {
  zone_id = var.cloudflare_zone_id
  name    = "lp"
  type    = "CNAME"
  content = "cname.vercel-dns.com"
  proxied = false
  ttl     = 1
  comment = "Apontamento Vercel Landing Page LP Subdomain"
}
