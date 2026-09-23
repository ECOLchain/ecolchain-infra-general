variable "cloudflare_email" {
  description = "Email da conta Cloudflare"
  type        = string
  sensitive   = false
}

variable "cloudflare_api_key" {
  description = "Global API Key da conta Cloudflare"
  type        = string
  sensitive   = true
}

variable "cloudflare_zone_id" {
  description = "Zone ID do domínio ecolchain.com no Cloudflare"
  type        = string
}

variable "cloudflare_account_id" {
  description = "Account ID da conta Cloudflare"
  type        = string
}

variable "destination_email" {
  description = "Endereço Gmail para redirecionamento catch-all"
  type        = string
  default     = "ecolchain@gmail.com"
}
