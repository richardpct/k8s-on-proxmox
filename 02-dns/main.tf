data "aws_route53_zone" "main" {
  name = var.my_domain
}

resource "aws_route53_record" "vault" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "vault"
  type    = "A"
  ttl     = "300"
  records = [var.lb_ip]
}

resource "aws_route53_record" "argocd" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "argocd"
  type    = "A"
  ttl     = "300"
  records = [var.lb_ip]
}

resource "aws_route53_record" "jenkins" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "jenkins"
  type    = "A"
  ttl     = "300"
  records = [var.lb_ip]
}
