output "lb_url" {
  description = "HTTP-адрес балансировщика"

  value = "http://${one(flatten([
    for l in yandex_lb_network_load_balancer.lb.listener : [
      for spec in l.external_address_spec : spec.address
    ]
  ]))}"
}

output "web_public_ips" {
  description = "Публичные IP-адреса веб-серверов"

  value = yandex_compute_instance.web[*].network_interface[0].nat_ip_address
}

output "web_internal_ips" {
  description = "Внутренние IP-адреса веб-серверов"

  value = yandex_compute_instance.web[*].network_interface[0].ip_address
}

