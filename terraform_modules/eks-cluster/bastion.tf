data "aws_iam_instance_profile" "eks-bastion" {
  name = "eks-bastion"
}

resource "aws_security_group" "eks-bastion" {
  name        = "bastion.${local.cluster_domain}"
  vpc_id      = aws_vpc.eks-vpc.id
  description = "Security group for EKS bastion"

  tags = {
    KubernetesCluster   = var.cluster_name
    KubernetesClusterId = var.cluster_name
    Name                = "bastion.${local.cluster_domain}"
  }
}

# Allow the bastion to communicate out to anything
resource "aws_security_group_rule" "eks-bastion-egress" {
  type              = "egress"
  security_group_id = aws_security_group.eks-bastion.id

  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]
}

resource "aws_security_group" "eks-bastion-elb" {
  name        = "bastion-elb.${local.cluster_domain}"
  vpc_id      = aws_vpc.eks-vpc.id
  description = "Security group for bastion ELB"

  tags = {
    "Name"                                      = "bastion-elb.${local.cluster_domain}"
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
    "KubernetesCluster"                         = var.cluster_name
    "KubernetesClusterId"                       = var.cluster_name
  }
}

# Allow the bastion ELB to communicate out to anything
resource "aws_security_group_rule" "bastion-elb-egress" {
  type              = "egress"
  security_group_id = aws_security_group.eks-bastion-elb.id
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}

# Allow the bastion to SSH to the nodes
resource "aws_security_group_rule" "bastion-to-node-ssh" {
  type                     = "ingress"
  security_group_id        = aws_security_group.node-security-group.id
  source_security_group_id = aws_security_group.eks-bastion.id
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
}

# Allow the bastion to receive SSH from its ELB
resource "aws_security_group_rule" "ssh-elb-to-bastion" {
  type                     = "ingress"
  security_group_id        = aws_security_group.eks-bastion.id
  source_security_group_id = aws_security_group.eks-bastion-elb.id
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
}

# Allow anyone to SSH to the ELB
resource "aws_security_group_rule" "ssh-external-to-bastion-elb-0-0-0-0--0" {
  type              = "ingress"
  security_group_id = aws_security_group.eks-bastion-elb.id
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

data "aws_ami" "latest-ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-xenial-16.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_launch_configuration" "eks-bastion" {
  name_prefix   = "bastion.${local.cluster_domain}-"
  image_id      = data.aws_ami.latest-ubuntu.image_id
  instance_type = "t3.micro"

  key_name                    = "eks-keypair"
  iam_instance_profile        = data.aws_iam_instance_profile.eks-bastion.name
  security_groups             = [aws_security_group.eks-bastion.id]
  associate_public_ip_address = true

  root_block_device {
    volume_type           = "gp2"
    volume_size           = 32
    delete_on_termination = true
  }

  lifecycle {
    create_before_destroy = true
  }

  enable_monitoring = false
}

resource "aws_autoscaling_group" "eks-bastion" {
  name                 = "bastion.${local.cluster_domain}"
  launch_configuration = aws_launch_configuration.eks-bastion.id
  max_size             = 1
  min_size             = 1
  vpc_zone_identifier  = aws_subnet.public-subnet.*.id

  tag {
    key                 = "KubernetesCluster"
    value               = var.cluster_name
    propagate_at_launch = true
  }

  tag {
    key                 = "KubernetesClusterId"
    value               = var.cluster_name
    propagate_at_launch = true
  }

  tag {
    key                 = "Name"
    value               = "bastion.${local.cluster_domain}"
    propagate_at_launch = true
  }

  tag {
    key                 = "k8s.io/role/bastion"
    value               = "1"
    propagate_at_launch = true
  }

  metrics_granularity = "1Minute"

  enabled_metrics = [
    "GroupDesiredCapacity",
    "GroupInServiceInstances",
    "GroupMaxSize",
    "GroupMinSize",
    "GroupPendingInstances",
    "GroupStandbyInstances",
    "GroupTerminatingInstances",
    "GroupTotalInstances",
  ]
}

resource "aws_elb" "eks-bastion" {
  name = "eks-bastion"

  listener {
    instance_port     = 22
    instance_protocol = "TCP"
    lb_port           = 22
    lb_protocol       = "TCP"
  }

  security_groups = [aws_security_group.eks-bastion-elb.id]
  subnets         = aws_subnet.public-subnet.*.id

  health_check {
    target              = "TCP:22"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 10
    timeout             = 5
  }

  idle_timeout = 3600

  tags = {
    KubernetesCluster   = var.cluster_name
    KubernetesClusterId = var.cluster_name
    Name                = "bastion.${local.cluster_domain}"
  }
}

resource "aws_autoscaling_attachment" "eks-bastion" {
  elb                    = aws_elb.eks-bastion.id
  autoscaling_group_name = aws_autoscaling_group.eks-bastion.id
}

resource "aws_route53_record" "bastion-domain" {
  name    = "bastion.${aws_route53_zone.cluster.name}"
  type    = "A"
  zone_id = aws_route53_zone.cluster.id

  alias {
    name                   = aws_elb.eks-bastion.dns_name
    zone_id                = aws_elb.eks-bastion.zone_id
    evaluate_target_health = false
  }
}

