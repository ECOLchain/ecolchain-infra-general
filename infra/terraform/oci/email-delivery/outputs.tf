output "smtp_endpoint" {
  description = "Endpoint SMTP do Email Delivery na região -> quarkus.mailer.host"
  value       = data.oci_email_configuration.this.smtp_submit_endpoint
}

output "smtp_port" {
  description = "Porta SMTP com TLS implícito -> quarkus.mailer.port (com quarkus.mailer.tls=true)"
  value       = 465
}

output "smtp_username" {
  description = "Usuário SMTP gerado pela OCI -> QUARKUS_MAILER_USERNAME"
  value       = oci_identity_smtp_credential.app.username
}

output "smtp_password" {
  description = "Senha SMTP gerada pela OCI -> QUARKUS_MAILER_PASSWORD"
  value       = oci_identity_smtp_credential.app.password
  sensitive   = true
}

output "sender_email" {
  description = "Endereço From aprovado -> quarkus.mailer.from"
  value       = oci_email_sender.ecolchain.email_address
}

output "email_domain_id" {
  description = "OCID do Email Domain"
  value       = oci_email_email_domain.ecolchain.id
}

output "dkim_state" {
  description = "Estado do DKIM (NEEDS_ATTENTION até a OCI validar o CNAME; ACTIVE quando pronto)"
  value       = oci_email_dkim.ecolchain.state
}

output "dkim_cname" {
  description = "Registro CNAME do DKIM criado no Cloudflare"
  value = {
    name  = cloudflare_dns_record.dkim.name
    value = cloudflare_dns_record.dkim.content
  }
}
