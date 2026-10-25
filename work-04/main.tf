
resource "yandex_vpc_network" "net" {
  name = "kostin-01-tf-net"
}

resource "yandex_vpc_subnet" "subnet" {
  name           = "kostin-01-tf-subnet"
  zone           = "ru-central1-e"
  network_id     = yandex_vpc_network.net.id
  v4_cidr_blocks = ["10.11.1.0/24"]
}

data "yandex_compute_image" "base" {
  family = "debian-12"
}

resource "yandex_compute_instance" "app" {
  name                      = "kostin-01-tf-app"
  hostname                  = "kostin-01-tf-app"
  allow_stopping_for_update = true
  zone                      = "ru-central1-e"
  platform_id               = "standard-v3"

  resources {
    cores         = 2
    core_fraction = 20
    memory        = 4
  }

  scheduling_policy {
    preemptible = true
  }

  secondary_disk {
    disk_id = yandex_compute_disk.extra.id
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.base.id
      size     = 15
      type     = "network-hdd"
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet.id
    nat       = true
  }

  metadata = {
    user-data = templatefile(
      "${path.module}/cloud-init.tpl.yaml",
      {
        ssh_key = trimspace(file(pathexpand("~/.ssh/id_ed25519.pub")))
      }
    )
  }

  labels = {
    env   = "lab"
    owner = "kostin-01"
  }
}

output "app_ip" {
  description = "Публичный IP-адрес виртуальной машины"
  value       = yandex_compute_instance.app.network_interface[0].nat_ip_address
}

resource "yandex_compute_disk" "extra" {
  name = "kostin-01-tf-extra"
  type = "network-hdd"
  zone = "ru-central1-e"
  size = 5
}
