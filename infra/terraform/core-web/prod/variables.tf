variable "tenancy_ocid" {
  description = "OCID da tenancy OCI da ecolchain"
  type        = string
}

variable "user_ocid" {
  description = "OCID do usuário OCI que o Terraform usa para autenticar"
  type        = string
}

variable "fingerprint" {
  description = "Fingerprint da API key registrada no usuário OCI"
  type        = string
}

variable "private_key_path" {
  description = "Caminho local da private key PEM da API OCI"
  type        = string
  default     = "~/.oci/ecolchain_terraform.pem"
}

variable "region" {
  description = "Região home da tenancy ecolchain"
  type        = string
  default     = "sa-saopaulo-1"
}

variable "cloudflare_email" {
  description = "Email de acesso à conta Cloudflare"
  type        = string
}

variable "cloudflare_api_key" {
  description = "Global API Key do Cloudflare"
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

variable "hostname" {
  description = "Hostname público do frontend de produção"
  type        = string
  default     = "app.ecolchain.com"
}

variable "bucket_name" {
  description = "Bucket OCI que hospeda os artefatos estáticos de produção"
  type        = string
  default     = "ecolchain-web-prod"
}
