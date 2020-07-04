// --- ホストゾーン ---
// ホストゾーンの参照
data "aws_route53_zone" "ryokky59" {
  name = "ryokky59.com"
}

// --- DNSレコード ---
resource "aws_route53_record" "ryokky59" {
  zone_id = data.aws_route53_zone.ryokky59.zone_id
  name    = data.aws_route53_zone.ryokky59.name
  type    = "A"

  alias {
    name                   = aws_lb.ecs_sample.dns_name
    zone_id                = aws_lb.ecs_sample.zone_id
    evaluate_target_health = true
  }
}

output "domain_name" {
  value = aws_route53_record.ryokky59.name
}

// --- ACM ---
resource "aws_acm_certificate" "ryokky59" {
  domain_name               = aws_route53_record.ryokky59.name
  subject_alternative_names = [] // ドメイン名を追加したい場合
  validation_method         = "DNS"

  // lifecycleはリソースを作成してから削除するようになる
  lifecycle {
    create_before_destroy = true
  }
}

// DNS検証用のDNSレコード
resource "aws_route53_record" "ryokky59_certificate" {
  name    = aws_acm_certificate.ryokky59.domain_validation_options[0].resource_record_name
  type    = aws_acm_certificate.ryokky59.domain_validation_options[0].resource_record_type
  records = [aws_acm_certificate.ryokky59.domain_validation_options[0].resource_record_value]
  zone_id = data.aws_route53_zone.ryokky59.id
  ttl     = 60
}

// DNS検証が完了するまで待機
resource "aws_acm_certificate_validation" "ryokky59" {
  certificate_arn         = aws_acm_certificate.ryokky59.arn
  validation_record_fqdns = [aws_route53_record.ryokky59_certificate.fqdn]
}
