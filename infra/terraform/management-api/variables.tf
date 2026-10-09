variable "tenancy_ocid" {
  description = "OCID da tenancy OCI da ecolchain (usado como compartimento raiz)"
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
  description = "Caminho local da private key PEM da API OCI (não commitar o conteúdo)"
  type        = string
  default     = "~/.oci/ecolchain_terraform.pem"
}

variable "region" {
  description = "Região home da tenancy ecolchain"
  type        = string
  default     = "sa-saopaulo-1"
}

variable "db_name" {
  description = "Nome do Autonomous Database Always Free (compartilhado dev/prod, separado por schema)"
  type        = string
  default     = "ecolmgmt"
}

variable "adb_allowed_ips" {
  description = "ACL de IPs/CIDRs permitidos no ADB. 0.0.0.0/0 libera geral — restringir quando o app tiver IP fixo"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# TODO: credenciais em plaintext por decisão do time. Quando quiserem virar
# secret: gh secret set + TF_VAR_<name> nos dois workflows em .github/workflows/
variable "db_admin_password" {
  description = "Senha do ADMIN do ADB (12-30 chars, maiúscula + minúscula + dígito)"
  type        = string
  sensitive   = true
  default     = "EcolchainMgmt#2026a"
}

variable "schema_username_dev" {
  description = "Usuário Oracle (schema) de dev no ADB compartilhado"
  type        = string
  default     = "MGMT_DEV"
}

variable "schema_username_prod" {
  description = "Usuário Oracle (schema) de prod no ADB compartilhado"
  type        = string
  default     = "MGMT_PROD"
}

variable "schema_password_dev" {
  description = "Senha do schema MGMT_DEV"
  type        = string
  sensitive   = true
  default     = "EcolchainDev#2026x"
}

variable "schema_password_prod" {
  description = "Senha do schema MGMT_PROD"
  type        = string
  sensitive   = true
  default     = "EcolchainProd#2026x"
}

variable "documents_buckets" {
  description = "Buckets do Object Storage para documentos, por ambiente"
  type        = map(string)
  default = {
    dev  = "ecolchain-api-docs-dev"
    prod = "ecolchain-api-docs-prod"
  }
}

variable "customer_secret_key_name" {
  description = "Display name da Customer Secret Key S3 do app"
  type        = string
  default     = "management-api-s3"
}
