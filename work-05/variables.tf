variable "prefix" {
  description = "Префикс имён ресурсов: фамилия и номер варианта"
  type        = string
}

variable "zone" {
  description = "Зона доступности"
  type        = string
}

variable "subnet_cidr" {
  description = "Диапазон адресов подсети"
  type        = string
}

variable "app_port" {
  description = "Порт, на котором отвечает приложение"
  type        = number

  validation {
    condition     = var.app_port > 1023 && var.app_port < 65536
    error_message = "Порт должен быть в диапазоне 1024–65535."
  }
}

variable "disk_size" {
  description = "Размер загрузочного диска, ГБ"
  type        = number
  default     = 15
}

variable "vm_count" {
  description = "Количество машин в группе"
  type        = number
  default     = 1
}

variable "image_family" {
  description = "Семейство образа"
  type        = string
}

variable "greeting" {
  description = "Слово на странице"
  type        = string
}

variable "env" {
  description = "Имя окружения, ставится меткой"
  type        = string
}

variable "web_password" {
  description = "Пароль к странице приложения"
  type        = string
  sensitive   = true
}

variable "open_ports" {
  description = "Allowed incoming TCP ports"
  type        = list(number)
  default     = [22, 8003]
}
