resource "aws_security_group" "this" {
  name        = coalesce(var.security_group_name, format("%.255s", "tf-sg-ec-${local.name}"))
  description = "Redis ElastiCache security group for ${local.name}"
  vpc_id      = data.aws_vpc.vpc.id

  tags = merge(
    { "Name" = coalesce(var.security_group_name, "tf-sg-ec-${local.name}") },
    var.security_group_tags,
  )
}

resource "aws_security_group_rule" "source_sg" {
  count                    = length(var.allowed_security_groups)
  type                     = "ingress"
  from_port                = var.redis_port
  to_port                  = var.redis_port
  protocol                 = "tcp"
  source_security_group_id = element(var.allowed_security_groups, count.index)
  security_group_id        = aws_security_group.this.id
}

resource "aws_security_group_rule" "cidr" {
  type              = "ingress"
  from_port         = var.redis_port
  to_port           = var.redis_port
  protocol          = "tcp"
  cidr_blocks       = concat(["127.0.0.1/32"], var.allowed_cidr)
  security_group_id = aws_security_group.this.id
}