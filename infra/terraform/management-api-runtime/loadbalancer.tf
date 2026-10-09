# ------------------------------------------------------------------
# Load Balancer flexível 10 Mbps (free tier) + roteamento por hostname.
# TLS na borda: Cloudflare proxied -> origin :443 com certificado da
# Cloudflare Origin CA (modo Full/strict) — ver dns.tf.
# ------------------------------------------------------------------
resource "oci_load_balancer_load_balancer" "api" {
  compartment_id = local.compartment_id
  display_name   = "mgmt-api-lb"
  shape          = "flexible"
  subnet_ids     = [oci_core_subnet.public.id]
  is_private     = false

  shape_details {
    minimum_bandwidth_in_mbps = 10
    maximum_bandwidth_in_mbps = 10
  }
}

locals {
  lb_public_ip = one([for d in oci_load_balancer_load_balancer.api.ip_address_details : d.ip_address if d.is_public])
}

resource "oci_load_balancer_backend_set" "api_dev" {
  load_balancer_id = oci_load_balancer_load_balancer.api.id
  name             = "api_dev"
  policy           = "ROUND_ROBIN"

  health_checker {
    protocol            = "HTTP"
    port                = var.app_dev_port
    url_path            = "/q/health"
    return_code         = 200
    interval_ms         = 10000
    timeout_in_millis   = 3000
    retries             = 3
    response_body_regex = ".*"
  }
}

resource "oci_load_balancer_backend_set" "api_prod" {
  load_balancer_id = oci_load_balancer_load_balancer.api.id
  name             = "api_prod"
  policy           = "ROUND_ROBIN"

  health_checker {
    protocol            = "HTTP"
    port                = var.app_prod_port
    url_path            = "/q/health"
    return_code         = 200
    interval_ms         = 10000
    timeout_in_millis   = 3000
    retries             = 3
    response_body_regex = ".*"
  }
}

resource "oci_load_balancer_backend" "api_dev" {
  load_balancer_id = oci_load_balancer_load_balancer.api.id
  backendset_name  = oci_load_balancer_backend_set.api_dev.name
  ip_address       = oci_core_instance.api.private_ip
  port             = var.app_dev_port
}

resource "oci_load_balancer_backend" "api_prod" {
  load_balancer_id = oci_load_balancer_load_balancer.api.id
  backendset_name  = oci_load_balancer_backend_set.api_prod.name
  ip_address       = oci_core_instance.api.private_ip
  port             = var.app_prod_port
}

resource "oci_load_balancer_certificate" "origin" {
  load_balancer_id = oci_load_balancer_load_balancer.api.id
  certificate_name = "ecolchain-api-origin"

  # Leaf emitido pela Cloudflare Origin CA (dns.tf); a chain é o root público da Origin CA.
  public_certificate = cloudflare_origin_ca_certificate.api.certificate
  private_key        = tls_private_key.origin.private_key_pem
  ca_certificate     = local.origin_ca_root_pem

  lifecycle {
    create_before_destroy = true
  }
}

resource "oci_load_balancer_load_balancer_routing_policy" "hostnames" {
  load_balancer_id           = oci_load_balancer_load_balancer.api.id
  name                       = "api-hostname-routing"
  condition_language_version = "V1"

  rules {
    name      = "dev"
    condition = "HMN:${var.api_dev_hostname}"

    actions {
      name             = "FORWARD_TO_BACKENDSET"
      backend_set_name = oci_load_balancer_backend_set.api_dev.name
    }
  }

  rules {
    name      = "prod"
    condition = "HMN:${var.api_prod_hostname}"

    actions {
      name             = "FORWARD_TO_BACKENDSET"
      backend_set_name = oci_load_balancer_backend_set.api_prod.name
    }
  }
}

resource "oci_load_balancer_listener" "https" {
  load_balancer_id         = oci_load_balancer_load_balancer.api.id
  name                     = "https-443"
  default_backend_set_name = oci_load_balancer_backend_set.api_dev.name
  port                     = 443
  protocol                 = "HTTP"
  routing_policy_name      = oci_load_balancer_load_balancer_routing_policy.hostnames.name

  ssl_configuration {
    certificate_name        = oci_load_balancer_certificate.origin.certificate_name
    verify_peer_certificate = false
    verify_depth            = 1
    server_order_preference = "ENABLED"
    protocols               = ["TLSv1.2", "TLSv1.3"]
  }
}
