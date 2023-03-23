terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "3.48.0"
    }
  }

  backend "azurerm" {
    
  }
}

provider "azurerm" {
  features {
	
  }
}

#########################
#  Database
#########################

resource "azurerm_postgresql_server" "pgsql-srv" {
  name                = "pgsql-srv-${var.project_name}${var.environment_suffix}"
  location            = data.azurerm_resource_group.rg-maalsi.location
  resource_group_name = data.azurerm_resource_group.rg-maalsi.name

  administrator_login          = data.azurerm_key_vault_secret.database-login.value 
  administrator_login_password = data.azurerm_key_vault_secret.database-password.value
  
  sku_name   = "GP_Gen5_4"
  version    = "11"
  storage_mb = 640000

  backup_retention_days        = 7
  auto_grow_enabled            = true

  ssl_enforcement_enabled          = false
  ssl_minimal_tls_version_enforced = "TLSEnforcementDisabled"

  
}

resource "azurerm_postgresql_firewall_rule" "example" {
  name                = "fw-${var.project_name}${var.environment_suffix}"
  resource_group_name = data.azurerm_resource_group.rg-maalsi.name
  server_name         = azurerm_postgresql_server.pgsql-srv.name
  start_ip_address    = "0.0.0.0"
  end_ip_address      = "0.0.0.0"
}

#########################
#  API Web App
#########################
resource "azurerm_service_plan" "app-plan" {
    name="plan-${var.project_name}${var.environment_suffix}"
    resource_group_name = data.azurerm_resource_group.rg-maalsi.name
    location = data.azurerm_resource_group.rg-maalsi.location
	sku_name            = "P1v2"
    os_type             = "Linux"  
}

resource "azurerm_linux_web_app" "web-app" {
  name = "web-${var.project_name}${var.environment_suffix}"
  resource_group_name = data.azurerm_resource_group.rg-maalsi.name
  location = data.azurerm_resource_group.rg-maalsi.location
  service_plan_id = azurerm_service_plan.app-plan.id

  site_config {
	 always_on = true
	 application_stack {
	   node_version = "16-lts"
	 }
  }

  app_settings = {
	// "DB_USERNAME" = "${data.azurerm_key_vault_secret.db-username.value}@${azurerm_postgresql_server.pgsql-srv.name}"
    PORT=3000
    DB_HOST=azurerm_postgresql_server.pgsql-srv.fqdn
    DB_USERNAME="${data.azurerm_key_vault_secret.database-login.value}@${azurerm_postgresql_server.pgsql-srv.name}"
    DB_PASSWORD=data.azurerm_key_vault_secret.database-password.value
    DB_DATABASE="postgres"
    DB_DAILECT="postgres"
    DB_PORT=5432
    ACCESS_TOKEN_SECRET = "YOUR_SECRET_KEY"
    REFRESH_TOKEN_SECRET = "YOUR_SECRET_KEY"
    ACCESS_TOKEN_EXPIRY = "15m"
    REFRESH_TOKEN_EXPIRY = "7d"
    REFRESH_TOKEN_COOKIE_NAME = "jid"
  }
}

#################################
#  PGAdmin : Container instance
#################################

resource "azurerm_container_group" "pgadmin" {
  name                = "aci-pgadmin-${var.project_name}${var.environment_suffix}"
  resource_group_name = data.azurerm_resource_group.rg-maalsi.name
  location            = data.azurerm_resource_group.rg-maalsi.location
  ip_address_type     = "Public"
  dns_name_label      = "aci-pgadmin-${var.project_name}${var.environment_suffix}"
  os_type             = "Linux"
  exposed_port        = []

  container {
    name   = "pgadmin"
    image  = "dpage/pgadmin4:latest"
    cpu    = "0.5"
    memory = "1.5"

ports {
  port = 80
  protocol = "TCP"

}

    environment_variables = {
	  "PGADMIN_DEFAULT_EMAIL" = data.azurerm_key_vault_secret.pgadminDefaultEmail.value
	  "PGADMIN_DEFAULT_PASSWORD" = data.azurerm_key_vault_secret.pgadminDefaultPwd.value
    }
  }
}