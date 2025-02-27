provider "azurerm" {
  features {}
}

# Création du Resource Group
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

# Création du Storage Account (Data Lake Gen2)
resource "azurerm_storage_account" "datalake" {
  name                     = var.storage_account_name
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  is_hns_enabled           = true # Data Lake Gen2 activé
}

# Création des Containers (Blobs) pour le Data Lake
resource "azurerm_storage_container" "bronze-data" {
  name                  = "bronze-data"
  storage_account_id    = azurerm_storage_account.datalake.id
  container_access_type = "private"
}

resource "azurerm_storage_container" "data-gouv" {
  name                  = "data-gouv"
  storage_account_id    = azurerm_storage_account.datalake.id
  container_access_type = "private"
}

resource "azurerm_storage_container" "gold-data" {
  name                  = "gold-data"
  storage_account_id    = azurerm_storage_account.datalake.id
  container_access_type = "private"
}


# Création du serveur SQL
resource "azurerm_mssql_server" "sql_server" {
  name                         = var.sql_server_name
  resource_group_name          = azurerm_resource_group.rg.name
  location                     = azurerm_resource_group.rg.location
  version                      = "12.0"
  administrator_login          = var.sql_admin_login
  administrator_login_password = var.sql_admin_password
}

# Création de la base de données SQL
resource "azurerm_mssql_database" "sql_database" {
  name                        = var.sql_database_name
  server_id                   = azurerm_mssql_server.sql_server.id
  collation                   = "SQL_Latin1_General_CP1_CI_AS"
  max_size_gb                 = 32
  read_scale                  = false
  zone_redundant              = false

  # Configuration pour Serverless (environnement de développement)
  sku_name                    = "GP_S_Gen5_1"
  
  # Auto-pause après 6 jours d'inactivité (8640 minutes)
  auto_pause_delay_in_minutes = 8640
  min_capacity                = 0.5
  
  # Tags pour documenter l'environnement
  tags = {
    Environment = "Development"
  }
}


# Règle de pare-feu pour permettre l'accès depuis Azure
resource "azurerm_mssql_firewall_rule" "allow_azure_services" {
  name                = "AllowAzureServices"
  server_id           = azurerm_mssql_server.sql_server.id
  start_ip_address    = "0.0.0.0"
  end_ip_address      = "255.255.255.255"
}
