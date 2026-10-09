terraform {
  required_version = ">= 1.5.0"

  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 9.7"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "oci" {
  tenancy_ocid     = var.tenancy_ocid
  user_ocid        = var.user_ocid
  fingerprint      = var.fingerprint
  private_key_path = var.private_key_path
  region           = var.region
}

provider "cloudflare" {
  email   = var.cloudflare_email
  api_key = var.cloudflare_api_key
}

locals {
  compartment_id = var.tenancy_ocid
}

# ------------------------------------------------------------------
# Remote state: credenciais que outros módulos já geraram.
# S3 do app e SMTP do Email Delivery chegam na VM só via Ansible
# (extra-vars do job de apply) — nunca em cloud-init/user_data.
# ------------------------------------------------------------------
data "terraform_remote_state" "api_data" {
  backend = "s3"
  config = {
    bucket   = "ecolchain-tfstate"
    key      = var.api_data_state_key
    region   = var.region
    endpoint = "https://grmykw8bmw9d.compat.objectstorage.sa-saopaulo-1.oraclecloud.com"

    use_path_style              = true
    skip_s3_checksum            = true
    skip_region_validation      = true
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_requesting_account_id  = true
  }
}

data "terraform_remote_state" "email" {
  backend = "s3"
  config = {
    bucket   = "ecolchain-tfstate"
    key      = var.email_delivery_state_key
    region   = var.region
    endpoint = "https://grmykw8bmw9d.compat.objectstorage.sa-saopaulo-1.oraclecloud.com"

    use_path_style              = true
    skip_s3_checksum            = true
    skip_region_validation      = true
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_requesting_account_id  = true
  }
}

# ------------------------------------------------------------------
# Rede — VM em subnet pública com IP próprio (egress grátis via IGW e
# alcançável por SSH do runner do GitHub para o Ansible do CD).
# A opção privada exigiria NAT Gateway, que não entra no Always Free.
# ------------------------------------------------------------------
resource "oci_core_vcn" "mgmt" {
  compartment_id = local.compartment_id
  cidr_blocks    = [var.vcn_cidr]
  display_name   = "mgmt-api-vcn"
  dns_label      = "mgmtapi"
}

resource "oci_core_internet_gateway" "mgmt" {
  compartment_id = local.compartment_id
  vcn_id         = oci_core_vcn.mgmt.id
  display_name   = "mgmt-api-igw"
}

resource "oci_core_default_route_table" "mgmt" {
  manage_default_resource_id = oci_core_vcn.mgmt.default_route_table_id
  display_name               = "mgmt-api-default-rt"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.mgmt.id
  }
}

resource "oci_core_security_list" "public" {
  compartment_id = local.compartment_id
  vcn_id         = oci_core_vcn.mgmt.id
  display_name   = "mgmt-api-public-sl"

  # O que o mundo precisa falar direto nesta subnet é só o LB :443.
  # SSH (:22) e portas de app (:8080/:8081) ficam no NSG da VM.
  ingress_security_rules {
    protocol = "6" # TCP
    source   = "0.0.0.0/0"
    tcp_options {
      min = 443
      max = 443
    }
  }

  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
  }
}

resource "oci_core_subnet" "public" {
  compartment_id             = local.compartment_id
  vcn_id                     = oci_core_vcn.mgmt.id
  cidr_block                 = var.public_subnet_cidr
  display_name               = "mgmt-api-public"
  dns_label                  = "public"
  prohibit_public_ip_on_vnic = false
  route_table_id             = oci_core_vcn.mgmt.default_route_table_id
  security_list_ids          = [oci_core_security_list.public.id]
}

# NSG da VM: SSH de ops/Ansible + portas dos containers vindas do LB (VCN).
resource "oci_core_network_security_group" "vm" {
  compartment_id = local.compartment_id
  vcn_id         = oci_core_vcn.mgmt.id
  display_name   = "mgmt-api-vm-nsg"
}

resource "oci_core_network_security_group_security_rule" "vm_ssh" {
  network_security_group_id = oci_core_network_security_group.vm.id
  direction                 = "INGRESS"
  protocol                  = "6" # TCP
  source                    = var.ssh_ingress_cidr
  source_type               = "CIDR_BLOCK"

  tcp_options {
    destination_port_range {
      min = 22
      max = 22
    }
  }
}

resource "oci_core_network_security_group_security_rule" "vm_app" {
  network_security_group_id = oci_core_network_security_group.vm.id
  direction                 = "INGRESS"
  protocol                  = "6" # TCP
  source                    = var.vcn_cidr
  source_type               = "CIDR_BLOCK"

  tcp_options {
    destination_port_range {
      min = var.app_dev_port
      max = var.app_prod_port
    }
  }
}

resource "oci_core_network_security_group_security_rule" "vm_egress" {
  network_security_group_id = oci_core_network_security_group.vm.id
  direction                 = "EGRESS"
  protocol                  = "all"
  destination               = "0.0.0.0/0"
  destination_type          = "CIDR_BLOCK"
}

# ------------------------------------------------------------------
# Compute — 1 VM A1.Flex serve os dois ambientes (free tier).
# SSH: par gerado pelo Terraform; a private key fica só no state e
# sai via `terraform output -raw ssh_private_key` (usada pelo CD/Ansible).
# ------------------------------------------------------------------
resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

data "oci_core_images" "ol9_arm" {
  compartment_id           = local.compartment_id
  operating_system         = "Oracle Linux"
  operating_system_version = "9"
  shape                    = "VM.Standard.A1.Flex"
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

data "oci_identity_availability_domains" "this" {
  compartment_id = local.compartment_id
}

resource "oci_core_instance" "api" {
  compartment_id = local.compartment_id
  # AD parametrizado: A1.Flex esgota capacidade por AD; troque via -var vm_ad_index=N.
  availability_domain = data.oci_identity_availability_domains.this.availability_domains[var.vm_ad_index].name
  display_name        = "mgmt-api-vm"
  shape               = "VM.Standard.A1.Flex"

  shape_config {
    ocpus         = var.vm_ocpus
    memory_in_gbs = var.vm_memory_gbs
  }

  source_details {
    source_type = "image"
    source_id   = data.oci_core_images.ol9_arm.images[0].id
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.public.id
    assign_public_ip = true
    hostname_label   = "mgmt-api-vm"
    nsg_ids          = [oci_core_network_security_group.vm.id]
  }

  metadata = {
    ssh_authorized_keys = tls_private_key.ssh.public_key_openssh
    user_data = base64encode(<<-EOT
      #cloud-config
      hostname: mgmt-api-vm
      prefer_fqdn_over_hostname: false
      # Provisionamento real fica com o Ansible (infra/ansible), disparado
      # pelo job de apply do CD via SSH. Cloud-init propositalmente mínimo.
    EOT
    )
  }
}

# Pepper do HMAC dos OTPs — gerado por apply, fica só no state e chega
# na VM via Ansible (env files), nunca commitado.
resource "random_password" "otp_pepper" {
  length  = 32
  special = false
}
