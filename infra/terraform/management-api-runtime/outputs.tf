output "vm_dev_public_ip" {
  description = "IP público da VM dev (Ansible/SSH)"
  value       = oci_core_instance.dev.public_ip
}

output "vm_prod_public_ip" {
  description = "IP público da VM prod (Ansible/SSH)"
  value       = oci_core_instance.prod.public_ip
}

output "vm_private_ips" {
  description = "IPs privados das VMs (backends do LB)"
  value = {
    dev  = oci_core_instance.dev.private_ip
    prod = oci_core_instance.prod.private_ip
  }
}

output "lb_public_ip" {
  description = "IP público do Load Balancer (destino dos registros A api-dev/api-prod)"
  value       = local.lb_public_ip
}

output "api_urls" {
  description = "URLs públicas da API por ambiente"
  value = {
    dev  = "https://${var.api_dev_hostname}"
    prod = "https://${var.api_prod_hostname}"
  }
}

output "ssh_private_key" {
  description = "Private key SSH da VM (só no state) — `terraform output -raw ssh_private_key`"
  value       = tls_private_key.ssh.private_key_pem
  sensitive   = true
}

output "ocir_image_repo" {
  description = "Repositório de imagem OCIR (docker pull/push)"
  value       = local.ocir_image_repo
}

output "ocir_registry" {
  description = "Host do OCIR da região"
  value       = local.ocir_registry
}

output "ocir_push_user" {
  description = "Usuário do docker login no CI da API -> secret OCIR_USERNAME no repo ecolchain-management-api"
  value       = local.ocir_push_user
}

output "ocir_push_token" {
  description = "Auth token do docker login no CI da API -> secret OCIR_AUTH_TOKEN no repo ecolchain-management-api"
  value       = oci_identity_auth_token.ocir_push.token
  sensitive   = true
}

# Variáveis consumidas pelo job de apply (Ansible) — contém credenciais.
output "ansible_vars" {
  description = "Extra-vars do playbook de provisionamento da VM"
  sensitive   = true
  value = {
    ssh_user      = "opc"
    ocir_registry = local.ocir_registry
    image_repo    = local.ocir_image_repo
    vcn_cidr      = var.vcn_cidr
    app_dir       = "/opt/mgmt-api"

    app_dev = {
      service_name = "api-dev"
      port         = var.app_dev_port
      image        = "${local.ocir_image_repo}:dev"
      env = {
        QUARKUS_PROFILE                                              = "dev"
        QUARKUS_MAILER_MOCK                                          = "true"
        QUARKUS_S3_AWS_CREDENTIALS_STATIC_PROVIDER_ACCESS_KEY_ID     = data.terraform_remote_state.api_data.outputs.s3_access_key
        QUARKUS_S3_AWS_CREDENTIALS_STATIC_PROVIDER_SECRET_ACCESS_KEY = data.terraform_remote_state.api_data.outputs.s3_secret_key
        OTP_PEPPER                                                   = random_password.otp_pepper.result
        # Tuning p/ VM de 1 GB (E2.1.Micro): heap ~70% e SerialGC (menos overhead)
        JAVA_MAX_MEM_RATIO   = "70"
        GC_CONTAINER_OPTIONS = "-XX:+UseSerialGC"
      }
    }

    app_prod = {
      service_name = "api-prod"
      port         = var.app_prod_port
      image        = "${local.ocir_image_repo}:prod"
      env = {
        QUARKUS_PROFILE                                              = "prod"
        QUARKUS_MAILER_USERNAME                                      = data.terraform_remote_state.email.outputs.smtp_username
        QUARKUS_MAILER_PASSWORD                                      = data.terraform_remote_state.email.outputs.smtp_password
        QUARKUS_S3_AWS_CREDENTIALS_STATIC_PROVIDER_ACCESS_KEY_ID     = data.terraform_remote_state.api_data.outputs.s3_access_key
        QUARKUS_S3_AWS_CREDENTIALS_STATIC_PROVIDER_SECRET_ACCESS_KEY = data.terraform_remote_state.api_data.outputs.s3_secret_key
        OTP_PEPPER                                                   = random_password.otp_pepper.result
        JAVA_MAX_MEM_RATIO                                           = "70"
        GC_CONTAINER_OPTIONS                                         = "-XX:+UseSerialGC"
      }
    }

    # Fallback de login no registry caso o token de instance principal falhe
    ocir_static_user  = local.ocir_push_user
    ocir_static_token = oci_identity_auth_token.ocir_push.token
  }
}
