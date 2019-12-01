data "aws_route53_zone" "root" {
  name = var.root_domain
}

resource "aws_route53_zone" "cluster" {
  name = local.cluster_domain
}

resource "aws_route53_record" "cluster-ns" {
  zone_id = data.aws_route53_zone.root.zone_id
  name    = aws_route53_zone.cluster.name
  type    = "NS"
  ttl     = "30"

  records = aws_route53_zone.cluster.name_servers
}

resource "aws_acm_certificate" "cluster" {
  domain_name       = "*.${local.cluster_domain}"
  validation_method = "DNS"
}

resource "aws_route53_record" "cert_validation" {
  name    = aws_acm_certificate.cluster.domain_validation_options[0].resource_record_name
  type    = aws_acm_certificate.cluster.domain_validation_options[0].resource_record_type
  zone_id = aws_route53_zone.cluster.id
  records = [aws_acm_certificate.cluster.domain_validation_options[0].resource_record_value]
  ttl     = 60
}

resource "aws_acm_certificate_validation" "cert" {
  certificate_arn         = aws_acm_certificate.cluster.arn
  validation_record_fqdns = [aws_route53_record.cert_validation.fqdn]
}

