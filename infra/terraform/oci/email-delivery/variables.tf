variable "tenancy_ocid" {
  description = "OCID da tenancy OCI da ecolchain (usado como compartimento raiz)"
  type        = string
}

variable "user_ocid" {
  description = "OCID do usuário OCI que o Terraform usa para autenticar (dono da credencial SMTP)"
  type        = string
}

variable "fingerprint" {
  description = "Fingerprint da API key registrada no usuário OCI"
  type        = string
}

variable "private_key_path" {
  description = "Caminho local da private key PEM da API OCI (não commitar o conteúdo)"
  type        = string
  default     = "~/.oci/ecolchain_terraform.pem"
}

variable "region" {
  description = "Região home da tenancy ecolchain (o Email Delivery é regional: sender e endpoint SMTP ficam nesta região)"
  type        = string
  default     = "sa-saopaulo-1"
}

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

variable "email_domain" {
  description = "Domínio de envio (Email Domain na OCI; precisa ser a zona do Cloudflare acima)"
  type        = string
  default     = "ecolchain.com"
}

variable "sender_email" {
  description = "Endereço From aprovado (Approved Sender) -> quarkus.mailer.from. O From das mensagens precisa ser exatamente este"
  type        = string
  default     = "ecolchain@ecolchain.com"
}

variable "dkim_selector" {
  description = "Selector DKIM (minúsculas, números e hífen; até 63 chars). Convenção: <dominio>-<regiao>-<aaaammdd>. Não é atualizável: trocar o valor recria o DKIM"
  type        = string
  default     = "ecolchain-gru-20261008"
}

variable "smtp_credential_description" {
  description = "Descrição da credencial SMTP gerada para o app"
  type        = string
  default     = "management-api-smtp"
}
