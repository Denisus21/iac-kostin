# Домашняя работа № 2. Вариант 01.

resource "yandex_vpc_network" "net" {
  name = "kostin-01-hw2-net"
}

resource "yandex_vpc_subnet" "a" {
  name           = "kostin-01-hw2-subnet-a"
  zone           = "ru-central1-e"
  network_id     = yandex_vpc_network.net.id
  v4_cidr_blocks = ["10.11.1.0/24"]
}

resource "yandex_vpc_subnet" "b" {
  name           = "kostin-01-hw2-subnet-b"
  zone           = "ru-central1-d"
  network_id     = yandex_vpc_network.net.id
  v4_cidr_blocks = ["10.11.2.0/24"]
}

data "yandex_compute_image" "os" {
  family = "debian-12"
}

resource "yandex_compute_instance" "web" {
  # Один блок с count создаёт все веб-серверы.
  # Уменьшение count удаляет машины с последних индексов.
  count = 2

  name     = "kostin-01-hw2-web-${count.index + 1}"
  hostname = "kostin-01-hw2-web-${count.index + 1}"

  # Исходные зоны варианта 01: ru-central1-a и ru-central1-b.
  # В практиках 4 и 5 возникали ограничения доступности зон.
  # При подтверждённом отказе размещения зоны корректируются
  # с сохранением распределения ВМ между двумя зонами.
  # Зоны e и d используются из-за ограничений доступности
  # исходных зон варианта 01 в Yandex Cloud.
  zone        = count.index % 2 == 0 ? "ru-central1-e" : "ru-central1-d"
  platform_id = "standard-v3"
  resources {
    cores         = 2
    core_fraction = 20
    memory        = 2
  }

  # Системный диск 15 ГБ.
  # Дополнительный диск из практики 4 здесь не требуется.
  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.os.id
      size     = 15
      type     = "network-hdd"
    }
  }

  network_interface {
    subnet_id = count.index % 2 == 0 ? yandex_vpc_subnet.a.id : yandex_vpc_subnet.b.id
    nat       = true
  }

  metadata = {
    user-data = templatefile(
      "${path.module}/cloud-init.tpl.yaml",
      {
        ssh_key  = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINhy6+GkAnxgZKIYIUNGw952w+MU5Vs3OLOvpXPBP+1h kostindenis@Noutbookich"
        app_port = 8003
        greeting = "labwork"
      }
    )
  }

  labels = {
    owner = "kostin-01"
    task  = "hw-02"
  }
}

resource "yandex_lb_target_group" "web" {
  name = "kostin-01-hw2-target-group"

  # dynamic включает все машины с их внутренними IP-адресами.
  dynamic "target" {
    for_each = yandex_compute_instance.web

    content {
      subnet_id = target.value.network_interface[0].subnet_id
      address   = target.value.network_interface[0].ip_address
    }
  }
}

resource "yandex_lb_network_load_balancer" "lb" {
  name = "kostin-01-hw2-lb"

  listener {
    name        = "http"
    port        = 80
    target_port = 8003

    external_address_spec {
      ip_version = "ipv4"
    }
  }

  attached_target_group {
    target_group_id = yandex_lb_target_group.web.id

    healthcheck {
      name = "http-healthcheck"

      interval            = 2
      timeout             = 1
      healthy_threshold   = 2
      unhealthy_threshold = 2

      http_options {
        port = 8003
        path = "/"
      }
    }
  }
}
