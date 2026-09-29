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
}

# 2. Domínio Apex da Landing Page na Vercel (ecolchain.com)
resource "vercel_project_domain" "apex" {
  project_id = vercel_project.landing_page.id
  domain     = var.domain_name
}

# 3. Domínio WWW da Landing Page na Vercel (www.ecolchain.com) com redirecionamento
resource "vercel_project_domain" "www" {
  project_id           = vercel_project.landing_page.id
  domain               = "www.${var.domain_name}"
  redirect             = vercel_project_domain.apex.domain
  redirect_status_code = 308
}

# 4. Apontamento A no Cloudflare para @ (ecolchain.com) -> Vercel
resource "cloudflare_dns_record" "vercel_apex" {
  zone_id = var.cloudflare_zone_id
  name    = "@"
  type    = "A"
  content = "76.76.21.21"
  proxied = false
  ttl     = 1
  comment = "Apontamento Vercel Landing Page Apex Domain"
}

# 5. Apontamento CNAME no Cloudflare para www -> Vercel
resource "cloudflare_dns_record" "vercel_cname_www" {
  zone_id = var.cloudflare_zone_id
  name    = "www"
  type    = "CNAME"
  content = "cname.vercel-dns.com"
  proxied = false
  ttl     = 1
  comment = "Apontamento Vercel Landing Page WWW Subdomain"
}
