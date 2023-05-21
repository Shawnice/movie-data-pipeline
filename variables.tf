variable "region" {
  type    = string
  default = "us-east-1"
}

variable "db_host" {
  type = string
  default = "docker.for.mac.localhost"
}

variable "db_user" {
  type = string
  default = "root"
}

variable "db_password" {
  type = string
  default = "12345678"
}

variable "is_production" {
  type = bool
  default = true
}

variable "db_name" {
  type = string
  default = "mysql"
}