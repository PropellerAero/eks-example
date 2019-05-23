resource "aws_security_group" "alb-ingress-security-group" {
  name        = "ingress.${local.cluster_domain}"
  description = "Security group for ingress ALB"
  vpc_id      = "${aws_vpc.eks-vpc.id}"

  # Allow HTTP in
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow HTTPS in
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow out to nodes
  egress {
    from_port       = 30000
    to_port         = 32767
    protocol        = "tcp"
    security_groups = ["${aws_security_group.node-security-group.id}"]
  }

  tags = "${
    map(
     "Name", "ingress.${local.cluster_domain}",
     "kubernetes.io/cluster/${var.cluster_name}", "owned",
     "KubernetesCluster", "${var.cluster_name}",
     "KubernetesClusterId", "${var.cluster_name}"
    )
  }"
}

data "template_file" "http_routes" {
  template = "${file("${path.module}/templates/ingress-route.tpl")}"
  count    = "${length(var.http_routes)}"

  vars {
    host         = "${lookup(var.http_routes[count.index], "subdomain")}.${local.cluster_domain}"
    service_name = "${lookup(var.http_routes[count.index], "kube_service")}"
    service_port = "${lookup(var.http_routes[count.index], "kube_service_port", 80)}"
  }
}

data "template_file" "https_routes" {
  template = "${file("${path.module}/templates/ingress-route.tpl")}"
  count    = "${length(var.https_routes)}"

  vars {
    host         = "${lookup(var.https_routes[count.index], "subdomain")}.${local.cluster_domain}"
    service_name = "${lookup(var.https_routes[count.index], "kube_service")}"
    service_port = "${lookup(var.https_routes[count.index], "kube_service_port", 80)}"
  }
}
