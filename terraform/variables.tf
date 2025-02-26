variable "resource_group_name" {
  description = "Nom du Resource Group"
  type        = string
  default     = "RG-JIMPE-Certif"
}

variable "location" {
  description = "Région Azure"
  type        = string
  default     = "francecentral"
}

variable "storage_account_name" {
  description = "Nom du Storage Account"
  type        = string
  default     = "dlcertifimpe"
}


variable "sql_server_name" {
  description = "Nom du serveur SQL"
  type        = string
  default     = "BDD-impe-jonathan-serveur"
}

variable "sql_admin_login" {
  description = "Nom d'utilisateur admin pour le serveur SQL"
  type        = string
  default     = "BDD-impe-jonathan-serveur"
}

variable "sql_admin_password" {
  description = "Mot de passe admin pour le serveur SQL"
  type        = string
  sensitive   = true
}

variable "sql_database_name" {
  description = "Nom de la base de données SQL"
  type        = string
  default     = "auto_certif"
}
