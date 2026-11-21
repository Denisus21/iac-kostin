
terraform {
  required_version = ">= 1.8"

  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = "~> 0.220.0"
    }
  }
}

provider "yandex" {
  service_account_key_file = pathexpand("~/.yc-keys/kostin-01-key.json")

  cloud_id  = "b1go3ev4poakpervjkol"
  folder_id = "b1go3lojhbtmfk19mroo"
  zone      = "ru-central1-e"
}
