resource "aws_route53_zone" "primary" {
  name = "mahjong-yaritai.com"
}

resource "aws_route53_record" "mahjong-yaritai" {
  zone_id = aws_route53_zone.primary.zone_id # 既存のホストゾーンID
  name    = "mahjong-yaritai.com"            # 作成するドメイン名
  type    = "A"                              # Aレコードタイプ

  alias {
    name                   = aws_lb.web_alb.dns_name # ALBのDNS名
    zone_id                = aws_lb.web_alb.zone_id  # ALBのDNS名に対応するRoute53のホストゾーンID（規定値）
    evaluate_target_health = true                    # 健康チェックを有効にする
  }
}
