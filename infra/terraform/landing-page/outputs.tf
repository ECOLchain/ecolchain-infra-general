output "vercel_project_id" {
  description = "ID do projeto criado na Vercel"
  value       = vercel_project.landing_page.id
}

output "lp_domain" {
  description = "Domínio oficial da Landing Page (lp.ecolchain.com)"
  value       = vercel_project_domain.lp.domain
}
