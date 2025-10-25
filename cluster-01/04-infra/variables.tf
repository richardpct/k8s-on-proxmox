variable "bucket" {
  type        = string
  description = "bucket"
}

variable "key_dns" {
  type        = string
  description = "dns key"
}

variable "nameserver" {
  type        = string
  description = "nameserver"
}

variable "gateway" {
  type        = string
  description = "gateway"
}

variable "public_ssh_key" {
  type        = string
  description = "public ssh key"
}

variable "pm_user" {
  type        = string
  description = "pm user"
}

variable "pm_password" {
  type        = string
  description = "pm password"
}
