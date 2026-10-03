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

variable "bucket_name" {
  description = "Nome do bucket de state do Terraform (compartilhado entre repos, segregado por env/app no path)"
  type        = string
  default     = "ecolchain-tfstate"
}

variable "customer_secret_key_name" {
  description = "Display name da Customer Secret Key usada como credencial S3 do backend"
  type        = string
  default     = "terraform-s3-ecolchain"
}
