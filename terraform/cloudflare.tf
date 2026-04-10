data "cloudflare_zone" "main" {
  filter = {
    name   = local.cloudflare_zone_name
    match  = "all"
    status = "active"
  }
}

resource "cloudflare_dns_record" "web" {
  zone_id = data.cloudflare_zone.main.zone_id
  name    = var.web_hostname
  type    = "A"
  content = aws_eip.web.public_ip
  proxied = true
  ttl     = 1
}

resource "cloudflare_dns_record" "cdn" {
  count   = trimspace(var.cdn_hostname) != "" ? 1 : 0
  zone_id = data.cloudflare_zone.main.zone_id
  name    = var.cdn_hostname
  type    = "CNAME"
  content = module.foundation.bucket_website_endpoint
  proxied = true
  ttl     = 1
}

resource "cloudflare_ruleset" "cdn_ssl_flexible" {
  count   = trimspace(var.cdn_hostname) != "" ? 1 : 0
  zone_id = data.cloudflare_zone.main.zone_id
  name    = "Zone-level configuration rules"
  kind    = "zone"
  phase   = "http_config_settings"

  rules = [{
    ref         = "openbase_cdn_ssl_flexible"
    description = "Use flexible SSL for the CDN hostname backed by the S3 website endpoint"
    expression  = "(http.host eq \"${var.cdn_hostname}\")"
    action      = "set_config"
    enabled     = true
    action_parameters = {
      ssl = "flexible"
    }
  }]
}
