variable "cloudflare_email" {
  description = "Email de acesso à conta Cloudflare"
  type        = string
  default     = "ecolchain@gmail.com"
}

variable "cloudflare_api_key" {
  description = "Global API Key do Cloudflare"
  type        = string
  sensitive   = true
}

variable "cloudflare_zone_id" {
  description = "Zone ID do domínio ecolchain.com no Cloudflare"
  type        = string
  default     = "2447ab4ab1b1afe9ef211d067c51d18f"
}

variable "domain_name" {
  description = "Nome do domínio principal da Landing Page"
  type        = string
  default     = "ecolchain.com"
}

variable "vercel_api_token" {
  description = "Token de API de acesso à Vercel"
  type        = string
  sensitive   = true
}

variable "vercel_team_id" {
  description = "Team/Org ID da Vercel (opcional para contas pessoais)"
  type        = string
  default     = ""
}

variable "vercel_project_name" {
  description = "Nome do projeto a ser criado na Vercel"
  type        = string
  default     = "ecolchain-landing-page-web"
}

variable "github_repo" {
  description = "Repositório do GitHub no formato dono/nome"
  type        = string
  default     = "ECOLchain/ecolchain-landing-page-web"
}
