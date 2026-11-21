resource "yandex_vpc_security_group" "app" {
  name       = "${local.stand}-sg"
  network_id = yandex_vpc_network.net.id
  labels     = local.common_labels

  dynamic "ingress" {
    for_each = var.open_ports

    content {
      protocol       = "TCP"
      description    = "Allow TCP ${ingress.value}"
      v4_cidr_blocks = ["0.0.0.0/0"]
      port           = ingress.value
    }
  }

  egress {
    protocol       = "ANY"
    description    = "Allow outgoing traffic"
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = 0
    to_port        = 65535
  }
}
