data "azurerm_resource_group" "rg-maalsi" {
  name     = "rg-${var.project_name}${var.environment_suffix}"
}

data "azurerm_key_vault" "kv" {
	name = "kv-${var.project_name}${var.environment_suffix}"
	resource_group_name = data.azurerm_resource_group.rg-maalsi.name
}
