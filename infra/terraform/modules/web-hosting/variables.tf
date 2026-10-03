variable "env" {
  description = "Ambiente do site (ex.: prod, dev) - usado em nomes e tags"
  type        = string
}

variable "hostname" {
  description = "Hostname publico servido pelo worker (ex.: app.ecolchain.com)"
  type        = string
}

variable "bucket_name" {
  description = "Nome do bucket OCI Object Storage que recebe os artefatos estaticos"
  type        = string
}

variable "region" {
  description = "Regiao OCI do bucket"
  type        = string
  default     = "sa-saopaulo-1"
}

variable "compartment_id" {
  description = "OCID do compartimento OCI onde o bucket sera criado (raiz = tenancy_ocid)"
  type        = string
}

variable "cloudflare_account_id" {
  description = "Account ID da conta Cloudflare"
  type        = string
}

variable "cloudflare_zone_id" {
  description = "Zone ID do dominio ecolchain.com no Cloudflare"
  type        = string
}

variable "basic_auth" {
  description = "Credencial 'user:senha' para Basic Auth no worker (dev). Vazio = sem gate"
  type        = string
  default     = ""
  sensitive   = true
}

variable "worker_name_prefix" {
  description = "Prefixo do nome do worker (nome final: <prefixo>-<env>)"
  type        = string
  default     = "ecolchain-web"
}
