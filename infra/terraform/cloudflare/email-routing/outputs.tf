output "email_routing_status" {
  description = "Status do Email Routing no domínio"
  value       = cloudflare_email_routing_settings.ecolchain.status
}

output "destination_address_status" {
  description = "Data/hora em que o endereço de destino foi verificado (vazio = ainda não verificado)"
  value       = cloudflare_email_routing_address.gmail.verified
}
