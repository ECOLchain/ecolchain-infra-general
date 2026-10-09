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

variable "api_dev_hostname" {
  description = "Hostname público da API de gestão (dev) — combinado com o frontend"
  type        = string
  default     = "api-dev.ecolchain.com"
}

variable "api_prod_hostname" {
  description = "Hostname público da API de gestão (prod) — combinado com o frontend"
  type        = string
  default     = "api-prod.ecolchain.com"
}

variable "ocir_region_key" {
  description = "Chave de região do OCIR para sa-saopaulo-1"
  type        = string
  default     = "gru"
}

variable "ocir_repo_name" {
  description = "Nome do repositório no OCI Container Registry"
  type        = string
  default     = "management-api"
}

variable "vcn_cidr" {
  description = "CIDR da VCN do runtime da management-api"
  type        = string
  default     = "10.20.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR da subnet pública (VM + Load Balancer)"
  type        = string
  default     = "10.20.1.0/24"
}

variable "ssh_ingress_cidr" {
  description = "CIDR com acesso SSH à VM (Ansible do CD usa IP de runner do GitHub — 0.0.0.0/0 até restringirmos)"
  type        = string
  default     = "0.0.0.0/0"
}

variable "vm_ocpus" {
  description = "OCPUs do shape A1.Flex (free tier: até 4 no total da tenancy)"
  type        = number
  default     = 1
}

variable "vm_memory_gbs" {
  description = "RAM do shape A1.Flex em GB (free tier: até 24 no total da tenancy)"
  type        = number
  default     = 8
}

variable "app_dev_port" {
  description = "Porta do container api-dev na VM"
  type        = number
  default     = 8080
}

variable "app_prod_port" {
  description = "Porta do container api-prod na VM"
  type        = number
  default     = 8081
}

variable "api_data_state_key" {
  description = "Key do state do módulo de dados da management-api (ADB + buckets + S3 creds)"
  type        = string
  default     = "prod/management-api/terraform.tfstate"
}

variable "email_delivery_state_key" {
  description = "Key do state do email-delivery (credenciais SMTP)"
  type        = string
  default     = "prod/oci/email-delivery/terraform.tfstate"
}
