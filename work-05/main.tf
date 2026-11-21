resource "yandex_vpc_network" "net" {
  name = "${local.stand}-net"
}

resource "yandex_vpc_subnet" "subnet" {
  name           = "${local.stand}-subnet"
  zone           = var.zone
  network_id     = yandex_vpc_network.net.id
  v4_cidr_blocks = [var.subnet_cidr]
}

data "yandex_compute_image" "base" {
  family = var.image_family
}

resource "yandex_compute_instance" "app" {
  for_each = toset([for i in range(var.vm_count) : tostring(i + 1)])

  name                      = "${local.stand}-app-${each.key}"
  hostname                  = "${local.stand}-app-${each.key}"
  allow_stopping_for_update = true
  zone                      = var.zone
  platform_id               = "standard-v3"

  resources {
    cores         = 2
    core_fraction = 20
    memory        = 2
  }

  scheduling_policy {
    preemptible = true
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.base.id
      size     = var.disk_size
      type     = "network-hdd"
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.subnet.id
    security_group_ids = [yandex_vpc_security_group.app.id]
    nat                = true
  }

  metadata = {
    user-data = templatefile(
      "${path.module}/cloud-init.tpl.yaml",
      {
        ssh_key      = trimspace(file(pathexpand("~/.ssh/id_ed25519.pub")))
        app_port     = var.app_port
        greeting     = var.greeting
        web_password = var.web_password
      }
    )
  }
  labels = local.common_labels
}

moved {
  from = yandex_compute_instance.app
  to   = yandex_compute_instance.app["1"]
}

