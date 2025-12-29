variable "region" {
  type        = string
  description = "region"
}

variable "bucket" {
  type        = string
  description = "bucket"
}

variable "my_domain" {
  type        = string
  description = "domain name"
}

variable "applications" {
  type        = list(string)
  description = "applications list"
}

variable "lb_ip" {
  type        = string
  description = "load balancer ip"
}
