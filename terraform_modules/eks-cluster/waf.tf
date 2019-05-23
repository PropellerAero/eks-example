resource "aws_wafregional_rate_based_rule" "rate_limit_all" {
  name        = "Rate Limit All"
  metric_name = "RateLimitAll"
  rate_key    = "IP"
  rate_limit  = 2000
}

resource "aws_wafregional_web_acl" "eks_ingress_waf_web_acl" {
  depends_on  = ["aws_wafregional_rate_based_rule.rate_limit_all"]
  name        = "ingress-waf.${local.cluster_domain}"
  metric_name = "KubernetesIngressWafWebAcl"

  default_action {
    type = "ALLOW"
  }

  rule {
    action {
      type = "BLOCK"
    }

    priority = 2
    rule_id  = "${aws_wafregional_rate_based_rule.rate_limit_all.id}"
    type     = "RATE_BASED"
  }
}
