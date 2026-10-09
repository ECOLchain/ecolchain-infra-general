variable "compartment_id" {
  description = "OCID do compartimento OCI (tenancy raiz)"
  type        = string
}

variable "user_ocid" {
  description = "OCID do usuário OCI dono da Customer Secret Key S3"
  type        = string
}

variable "region" {
  description = "Região OCI onde os recursos são criados"
  type        = string
}

variable "db_name" {
  description = "Nome do Autonomous Database (alfanumérico, até 14 chars)"
  type        = string
}

variable "adb_allowed_ips" {
  description = "ACL de IPs/CIDRs do ADB — obrigatória para one-way TLS (sem wallet). 0.0.0.0/0 libera geral"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "db_admin_password" {
  description = "Senha do usuário ADMIN do ADB (12-30 chars, maiúscula + minúscula + dígito)"
  type        = string
  sensitive   = true
}

variable "schema_username_dev" {
  description = "Usuário Oracle (schema) do ambiente de dev"
  type        = string
  default     = "MGMT_DEV"
}

variable "schema_username_prod" {
  description = "Usuário Oracle (schema) do ambiente de prod"
  type        = string
  default     = "MGMT_PROD"
}

variable "schema_password_dev" {
  description = "Senha do schema de dev (plaintext por decisão do time)"
  type        = string
  sensitive   = true
}

variable "schema_password_prod" {
  description = "Senha do schema de prod (plaintext por decisão do time)"
  type        = string
  sensitive   = true
}

variable "documents_buckets" {
  description = "Mapa env -> nome do bucket de documentos do Object Storage"
  type        = map(string)
}

variable "customer_secret_key_name" {
  description = "Display name da Customer Secret Key usada pelo app no endpoint S3-compat"
  type        = string
  default     = "management-api-s3"
}
