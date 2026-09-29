output "vercel_project_id" {
  description = "ID do projeto criado na Vercel"
  value       = vercel_project.landing_page.id
}

output "landing_page_apex_domain" {
  description = "Domínio Apex oficial da Landing Page (ecolchain.com)"
  value       = vercel_project_domain.apex.domain
}

output "landing_page_www_domain" {
  description = "Domínio WWW oficial da Landing Page (www.ecolchain.com)"
  value       = vercel_project_domain.www.domain
}
