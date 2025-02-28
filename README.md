# Déploiement d'Infrastructure Azure avec Terraform et GitHub Actions

Ce projet permet de déployer automatiquement une infrastructure Azure comprenant un Data Lake (Storage Account) et une base de données SQL à l'aide de Terraform et GitHub Actions. Le déploiement est entièrement automatisé grâce à un pipeline CI/CD.

## Table des matières

1. [Prérequis](#prérequis)
2. [Structure du projet](#structure-du-projet)
3. [Configuration initiale](#configuration-initiale)
4. [Création des ressources nécessaires](#création-des-ressources-nécessaires)
5. [Ressources Terraform](#ressources-terraform)
6. [Configuration de GitHub Actions](#configuration-de-github-actions)
7. [Exécution du projet](#exécution-du-projet)

## Prérequis

- Un abonnement Azure
- PowerShell
- Azure CLI
- Un compte GitHub
- Git
- Terraform (pour les tests locaux)

## Structure du projet

```
C:.
│   .gitignore
│   README.md
│   setup-azure-sp.ps1
│
├───.github
│   └───workflows
│           terraform.yml
│
└───terraform
        backend.tf
        init-db.sql
        main.tf
        variables.tf
```

## Configuration initiale

### Étape 1 : Création du Service Principal Azure

1. Exécutez le script PowerShell `setup-azure-sp.ps1` pour créer un Service Principal Azure qui permettra à Terraform de déployer des ressources.

```powershell
# Template du fichier setup-azure-sp.ps1
# Remplacez les valeurs ci-dessous par les vôtres

# Variables
$SUBSCRIPTION_ID = 'votre-subscription-id' # Remplacez par votre ID d'abonnement Azure
$SP_NAME = 'votre-nom-sp'                  # Remplacez par le nom souhaité pour votre Service Principal

# Vérifier si on est déjà connecté
if (-not (az account show --query id -o tsv)) {
    Write-Host "Connexion à Azure..."
    az login | Out-Null
}

# Sélectionner la bonne souscription
Write-Host "Sélection de la souscription: $SUBSCRIPTION_ID"
az account set --subscription $SUBSCRIPTION_ID

# Vérifier si le Service Principal existe déjà
$SP_EXIST = az ad sp list --display-name $SP_NAME --query "[].appId" -o tsv

if ($SP_EXIST) {
    Write-Host "Le Service Principal $SP_NAME existe déjà. Récupération des informations..."
    $SP_INFO = az ad sp show --id $SP_EXIST | ConvertFrom-Json
} else {
    Write-Host 'Création du Service Principal avec rôle Contributor...'
    $SP_INFO = az ad sp create-for-rbac `
      --name $SP_NAME `
      --role 'Contributor' `
      --scopes "/subscriptions/$SUBSCRIPTION_ID" | ConvertFrom-Json
}

# Extraction des informations
$CLIENT_ID = $SP_INFO.appId
$CLIENT_SECRET = $SP_INFO.password
$TENANT_ID = $SP_INFO.tenant

# Vérifier si le rôle Storage Blob Data Contributor est déjà attribué
$ROLE_EXISTS = az role assignment list `
  --assignee $CLIENT_ID `
  --role "Storage Blob Data Contributor" `
  --scope "/subscriptions/$SUBSCRIPTION_ID" `
  --query "[].roleDefinitionName" -o tsv

if (-not $ROLE_EXISTS) {
    Write-Host 'Ajout du rôle Storage Blob Data Contributor...'
    az role assignment create `
      --assignee $CLIENT_ID `
      --role 'Storage Blob Data Contributor' `
      --scope "/subscriptions/$SUBSCRIPTION_ID"
} else {
    Write-Host "Le rôle Storage Blob Data Contributor est déjà assigné."
}

# Affichage des informations
Write-Host ('-' * 32)
Write-Host 'Informations pour GitHub Secrets :'
Write-Host ('-' * 32)
Write-Host "AZURE_CLIENT_ID: $CLIENT_ID"
Write-Host "AZURE_CLIENT_SECRET: $CLIENT_SECRET"
Write-Host "AZURE_TENANT_ID: $TENANT_ID"
Write-Host "AZURE_SUBSCRIPTION_ID: $SUBSCRIPTION_ID"
Write-Host ('-' * 32)
Write-Host 'Sauvegardez ces informations immédiatement dans vos GitHub Secrets'
```

2. Pour exécuter le script, utilisez la commande suivante dans PowerShell :

```powershell
# Définir la politique d'exécution pour la session actuelle uniquement
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force

# Puis exécuter votre script
.\setup-azure-sp.ps1
```

3. Notez les 4 informations affichées par le script. Vous devrez les ajouter comme secrets dans votre dépôt GitHub :
   - `AZURE_CLIENT_ID`
   - `AZURE_CLIENT_SECRET`
   - `AZURE_TENANT_ID`
   - `AZURE_SUBSCRIPTION_ID`


   ###  Configurer les secrets GitHub

1. Dans votre dépôt GitHub, accédez à "Settings" > "Secrets and variables" > "Actions"
2. Ajoutez les secrets suivants :
   - `AZURE_CLIENT_ID` : L'ID client de votre Service Principal
   - `AZURE_CLIENT_SECRET` : Le secret client de votre Service Principal
   - `AZURE_SUBSCRIPTION_ID` : L'ID de votre abonnement Azure
   - `AZURE_TENANT_ID` : L'ID du locataire Azure

   ce `LOGIN_BDD_AZURE` est a mettre manuellement pour votre BDD avant de lancer le push 
   - `LOGIN_BDD_AZURE` : Le mot de passe administrateur pour la base de données SQL


## Création des ressources nécessaires

### Étape 2 : Création des ressources pour stocker l'état Terraform

Exécutez les commandes CLI suivantes pour créer les ressources nécessaires au stockage de l'état Terraform :

```bash
# Connexion à Azure
az login

# Création du groupe de ressources pour stocker l'état Terraform
# Remplacez "nom-groupe-ressources" par le nom souhaité pour votre groupe de ressources
az group create --name nom-groupe-ressources --location francecentral

# Création du compte de stockage pour l'état Terraform
# Remplacez "nom-compte-stockage" par un nom unique pour votre compte de stockage
az storage account create --name nom-compte-stockage --resource-group nom-groupe-ressources --location francecentral --sku Standard_LRS

# Création du conteneur pour l'état Terraform
az storage container create --name tfstate --account-name nom-compte-stockage --auth-mode login
```

## Ressources Terraform

### Étape 3 : Comprendre les fichiers Terraform

#### backend.tf
Ce fichier configure le stockage du fichier d'état Terraform dans Azure Storage.

```terraform
terraform {
  backend "azurerm" {
    # Groupe de ressources contenant le compte de stockage pour l'état Terraform
    # Remplacez "nom-groupe-ressources" par le nom de votre groupe de ressources
    resource_group_name  = "nom-groupe-ressources"
    
    # Nom du compte de stockage pour l'état Terraform
    # Remplacez "nom-compte-stockage" par le nom de votre compte de stockage
    storage_account_name = "nom-compte-stockage"
    
    # Nom du conteneur dans le compte de stockage
    container_name       = "tfstate"
    
    # Chemin du fichier d'état
    key                  = "prod.terraform.tfstate"
  }
}
```

**Objectif** : Ce fichier définit où et comment l'état de Terraform sera stocké. Dans ce cas, l'état sera stocké dans un compte de stockage Azure, ce qui permet de collaborer en équipe sur le même projet Terraform et de conserver un historique des déploiements.

#### variables.tf
Ce fichier définit les variables utilisées dans le déploiement.

```terraform
variable "resource_group_name" {
  description = "Nom du Resource Group"
  type        = string
  # Remplacez "nom-groupe-ressources-projet" par le nom souhaité pour votre groupe de ressources
  default     = "nom-groupe-ressources-projet"
}

variable "location" {
  description = "Région Azure"
  type        = string
  default     = "francecentral"
}

variable "storage_account_name" {
  description = "Nom du Storage Account"
  type        = string
  # Remplacez "nom-data-lake" par un nom unique pour votre Data Lake
  default     = "nom-data-lake"
}

variable "sql_server_name" {
  description = "Nom du serveur SQL"
  type        = string
  # Remplacez "nom-serveur-sql" par un nom unique pour votre serveur SQL
  default     = "nom-serveur-sql"
}

variable "sql_admin_login" {
  description = "Nom d'utilisateur admin pour le serveur SQL"
  type        = string
  # Remplacez "admin-sql" par le nom d'utilisateur souhaité
  default     = "admin-sql"
}

variable "sql_admin_password" {
  description = "Mot de passe admin pour le serveur SQL"
  type        = string
  sensitive   = true
  # Pas de valeur par défaut pour des raisons de sécurité
  # Ce mot de passe sera fourni via les secrets GitHub
}

variable "sql_database_name" {
  description = "Nom de la base de données SQL"
  type        = string
  # Remplacez "nom-base-donnees" par le nom souhaité pour votre base de données
  default     = "nom-base-donnees"
}
```

**Objectif** : Ce fichier définit toutes les variables qui seront utilisées dans les fichiers Terraform. Cela permet de centraliser la configuration et de faciliter la réutilisation et la modification des paramètres sans avoir à modifier le code principal.

#### main.tf
Ce fichier est le script principal qui définit les ressources à déployer sur Azure.

```terraform
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
# Container pour les données brutes non transformées
resource "azurerm_storage_container" "bronze_container" {
  name                  = "bronze-container"
  storage_account_id    = azurerm_storage_account.datalake.id
  container_access_type = "private"
}

# Container pour les données externes
resource "azurerm_storage_container" "external_data" {
  name                  = "external-data"
  storage_account_id    = azurerm_storage_account.datalake.id
  container_access_type = "private"
}

# Container pour les données transformées et prêtes à l'utilisation
resource "azurerm_storage_container" "processed_data" {
  name                  = "processed-data"
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
  # Configuration pour Serverless
  sku_name                    = "GP_S_Gen5_1"
  
  # Paramètres pour Serverless (auto-pause après 6 jours d'inactivité)
  auto_pause_delay_in_minutes = 8640
  min_capacity                = 0.5
}

# Règle de pare-feu pour permettre l'accès depuis Azure
resource "azurerm_mssql_firewall_rule" "allow_azure_services" {
  name                = "AllowAzureServices"
  server_id           = azurerm_mssql_server.sql_server.id
  start_ip_address    = "0.0.0.0"
  end_ip_address      = "255.255.255.255"
}

# Exécution du script SQL pour créer les tables
resource "null_resource" "sql_tables" {
  depends_on = [azurerm_mssql_database.sql_database]
  provisioner "local-exec" {
    command = "sqlcmd -S ${azurerm_mssql_server.sql_server.fully_qualified_domain_name} -d ${azurerm_mssql_database.sql_database.name} -U ${var.sql_admin_login} -P ${var.sql_admin_password} -i ${path.module}/init-db.sql"
  }
}
```

**Objectif** : Le fichier `main.tf` est le cœur du projet Terraform. Il définit toutes les ressources Azure qui seront créées :
1. Un groupe de ressources pour contenir toutes les ressources du projet
2. Un compte de stockage configuré comme Data Lake Gen2
3. Trois conteneurs de stockage pour différentes étapes du traitement des données
4. Un serveur SQL Azure
5. Une base de données SQL Serverless (avec pause automatique)
6. Une règle de pare-feu pour permettre l'accès aux services Azure
7. Une ressource pour exécuter le script SQL qui crée les tables dans la base de données

#### init-db.sql
Ce fichier contient les commandes SQL pour créer les tables dans la base de données Azure SQL.

```sql
-- Table des produits
CREATE TABLE Produit (
    ID_Produit INT PRIMARY KEY IDENTITY,
    URL_Produit VARCHAR(200),
    Prix INT,
    Info_generale VARCHAR(200),
    Descriptif VARCHAR(200),
    Note VARCHAR(50),
    Date_scrap DATE,
    Marque VARCHAR(200)
);

-- Table des caractéristiques techniques
CREATE TABLE Caracteristiques (
    ID_Caracteristique INT PRIMARY KEY IDENTITY,
    Consommation CHAR(1),
    Indice_Pluie CHAR(1),
    Bruit INT,
    Saisonalite VARCHAR(50),
    Type_Vehicule VARCHAR(50),
    Runflat VARCHAR(50),
    ID_Produit INT FOREIGN KEY REFERENCES Produit(ID_Produit)
);

-- Table des dimensions
CREATE TABLE Dimensions (
    ID_Dimension INT PRIMARY KEY IDENTITY,
    Largeur INT,
    Hauteur INT,
    Diametre INT,
    Charge INT,
    Vitesse CHAR(1),
    ID_Produit INT FOREIGN KEY REFERENCES Produit(ID_Produit)
);

-- Table des utilisateurs API
CREATE TABLE USER_API (
    ID_USER_API INT PRIMARY KEY IDENTITY,
    username VARCHAR(50),
    email VARCHAR(150),
    full_name VARCHAR(50),
    hashed_password VARCHAR(200),
    Date_Création DATE,
    Date_Derniere_Connexion DATE
);

-- Table des dimensions par modèle de véhicule
CREATE TABLE DimensionsParModel (
    ID_DimensionModel INT PRIMARY KEY IDENTITY,
    Marque VARCHAR(50),
    Modele VARCHAR(50),
    Annee INT,
    Finition VARCHAR(250),
    Largeur INT,
    Hauteur INT,
    Diametre INT
);
```

**Objectif** : Ce fichier SQL crée la structure de la base de données avec toutes les tables nécessaires pour le projet. Il est exécuté automatiquement par Terraform après la création de la base de données, ce qui garantit que la structure de données est mise en place correctement.

## Configuration de GitHub Actions

### Étape 4 : Configurer le workflow GitHub Actions

Créez le fichier `.github/workflows/terraform.yml` :

```yaml
name: "Terraform Deploy to Azure"

on:
  push:
    branches:
      - main  # Déclenchement sur push dans main
  pull_request:
    branches:
      - main

jobs:
  terraform:
    name: "Terraform Deployment"
    runs-on: ubuntu-latest
    env:
      ARM_CLIENT_ID: ${{ secrets.AZURE_CLIENT_ID }}
      ARM_CLIENT_SECRET: ${{ secrets.AZURE_CLIENT_SECRET }}
      ARM_SUBSCRIPTION_ID: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
      ARM_TENANT_ID: ${{ secrets.AZURE_TENANT_ID }}
      TF_VAR_sql_admin_password: ${{ secrets.LOGIN_BDD_AZURE }}
    defaults:
      run:
        working-directory: ./terraform

    steps:
      - name: 🛎 Checkout Repository
        uses: actions/checkout@v3

      - name: 🧰 Install SQLCMD
        run: |
          curl https://packages.microsoft.com/keys/microsoft.asc | sudo tee /etc/apt/trusted.gpg.d/microsoft.asc
          curl https://packages.microsoft.com/config/ubuntu/22.04/prod.list | sudo tee /etc/apt/sources.list.d/mssql-release.list
          sudo apt-get update
          sudo ACCEPT_EULA=Y apt-get install -y mssql-tools unixodbc-dev
          echo "$PATH:/opt/mssql-tools/bin" >> $GITHUB_PATH
        shell: bash

      - name: 🏗 Setup Terraform
        uses: hashicorp/setup-terraform@v2
        with:
          terraform_version: latest
        
      - name: 🧹 Terraform Format
        run: terraform fmt
        
      - name: 🔍 Terraform Format Check
        run: terraform fmt -check

      - name: 🚀 Terraform Init
        run: terraform init
        
      - name: 🔎 Terraform Validate
        run: terraform validate

      - name: 📖 Terraform Plan
        run: terraform plan -out=tfplan

      - name: ✅ Terraform Apply
        if: github.ref == 'refs/heads/main' && github.event_name == 'push'
        run: terraform apply -auto-approve tfplan 
```

**Objectif** : Ce fichier configure un workflow GitHub Actions qui s'exécute automatiquement lorsque du code est poussé vers la branche principale ou lorsqu'une pull request est créée. Le workflow :
1. Installe SQLCMD pour permettre l'exécution du script SQL
2. Configure Terraform
3. Initialise, vérifie le format, valide et planifie les changements Terraform
4. Applique les changements (uniquement sur la branche principale)

### Étape 5 : Configurer les secrets GitHub

1. Dans votre dépôt GitHub, accédez à "Settings" > "Secrets and variables" > "Actions"
2. Ajoutez les secrets suivants `(normalement cette étape a déjà été faite au début)` :

   - `AZURE_CLIENT_ID` : L'ID client de votre Service Principal
   - `AZURE_CLIENT_SECRET` : Le secret client de votre Service Principal
   - `AZURE_SUBSCRIPTION_ID` : L'ID de votre abonnement Azure
   - `AZURE_TENANT_ID` : L'ID du locataire Azure
   - `LOGIN_BDD_AZURE` : Le mot de passe administrateur pour la base de données SQL

## Exécution du projet

1. Poussez le code vers votre dépôt GitHub.
2. GitHub Actions déclenchera automatiquement le workflow sur la branche principale.
3. Le workflow exécutera les étapes suivantes :
   - Initialisation de Terraform
   - Validation de la configuration
   - Planification des modifications
   - Application des modifications (uniquement sur la branche principale)

Après l'exécution réussie, vous aurez :
- Un Resource Group Azure
- Un Data Lake Gen2 avec trois containers pour différentes étapes du traitement des données
- Un serveur SQL avec une base de données
- Toutes les tables définies dans init-db.sql créées dans votre base de données

## Résultat final

L'infrastructure déployée est prête à être utilisée pour un projet de data engineering, avec une architecture en couches pour la gestion des données, et une base de données SQL contenant les tables nécessaires pour le stockage et l'analyse. Cette infrastructure peut être facilement modifiée en ajustant les fichiers Terraform et en poussant les modifications vers le dépôt GitHub. 