data "aws_route53_zone" "main" {
  name = var.my_domain
}

resource "aws_route53_record" "applications" {
  count   = length(var.applications)
  zone_id = data.aws_route53_zone.main.zone_id
  name    = var.applications[count.index]
  type    = "A"
  ttl     = "300"
  records = [var.lb_ip]
}
