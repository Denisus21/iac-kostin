output "app_ips" {
  description = "Public IP addresses of application VMs"

  value = {
    for key, vm in yandex_compute_instance.app :
    key => vm.network_interface[0].nat_ip_address
  }
}

output "app_urls" {
  description = "Application URLs"

  value = {
    for key, vm in yandex_compute_instance.app :
    key => "http://${vm.network_interface[0].nat_ip_address}:${var.app_port}"
  }
}
