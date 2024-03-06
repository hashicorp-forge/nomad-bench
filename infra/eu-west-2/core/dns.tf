resource "aws_route53_zone" "nomad_bench" {
  name = "nomad-bench.nomad-team-dev.hashicorp.sevices"

  lifecycle {
    # This zone is referenced in https://github.com/hashicorp/hc-centralized-dns
    # and should not be deleted to avoid unnecessary changes to that repo.
    prevent_destroy = true
  }
}

resource "aws_route53_record" "nomad_bench" {
  zone_id = aws_route53_zone.nomad_bench.zone_id
  name    = "nomad-bench.nomad-team-dev.hashicorp.sevices"
  type    = "A"
  ttl     = "30"
  records = [module.core_cluster_lb.lb_public_ip]
}
